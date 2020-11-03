import AVFoundation
import UIKit
import Vision

enum BoxAnchorLocation {
    case bottomLeft
    case topLeft
    case topRight
    case bottomRight
    case none
}

//// TODO-jc: remove if not needed / not working
//extension AVCaptureDevice {
//    func set(frameRate: Double) {
//        guard let range = activeFormat.videoSupportedFrameRateRanges.first,
//            range.minFrameRate...range.maxFrameRate ~= frameRate
//            else {
//                print("Requested FPS is not supported by the device's activeFormat !")
//                return
//        }
//
//        do {
//            try lockForConfiguration()
//            activeVideoMinFrameDuration = CMTimeMake(value: 1, timescale: Int32(frameRate))
//            activeVideoMaxFrameDuration = CMTimeMake(value: 1, timescale: Int32(frameRate))
//            unlockForConfiguration()
//        } catch {
//            print("LockForConfiguration failed with error: \(error.localizedDescription)")
//        }
//    }
//}

final class BarcodeScannerViewController: UIViewController {
    @IBOutlet private weak var videoOutputImageView: UIImageView!
    private var previewLayer: AVCaptureVideoPreviewLayer?

    private let textBoxSize: CGSize = CGSize(width: 200.0, height: 200.0)
    private let contentFormatting: [NSAttributedString.Key: Any] = [
        .foregroundColor: UIColor.black,
        .font: UIFont.systemFont(ofSize: 18.0, weight: .medium)
    ]

    private var session = AVCaptureSession()
    private var requests = [VNRequest]()

    private var totalNumberOfTextBoxes: Int = 0

    private lazy var throttler: Throttler = Throttler(seconds: 0.1)
    private let thresholdFilter = PresenceThresholdFilter<[String]>(threshold: 0.05, outOf: 10)

    private var lastBufferOrientation: CGImagePropertyOrientation?
    private var bufferSize: CGSize?

    private let onBarcodeScanned: (Result<[String], Error>) -> Void

    // TODO-jc: maybe let the user to pick a Barcode if multiple are available
    init(onBarcodeScanned: @escaping (Result<[String], Error>) -> Void) {
        self.onBarcodeScanned = onBarcodeScanned
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .basicBackground
        configureVideoOutputImageView()
        startLiveVideo()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        startBarcodeDetection()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        if let connection = previewLayer?.connection {
            let orientation = UIApplication.shared.statusBarOrientation
            let previewLayerConnection: AVCaptureConnection = connection
            if previewLayerConnection.isVideoOrientationSupported {
                switch orientation {
                case .portrait:
                    updatePreviewLayer(layer: previewLayerConnection, orientation: .portrait)
                    break
                case .landscapeRight:
                    updatePreviewLayer(layer: previewLayerConnection, orientation: .landscapeRight)
                    break
                case .landscapeLeft:
                    updatePreviewLayer(layer: previewLayerConnection, orientation: .landscapeLeft)
                    break
                case .portraitUpsideDown:
                    updatePreviewLayer(layer: previewLayerConnection, orientation: .portraitUpsideDown)
                    break
                default:
                    updatePreviewLayer(layer: previewLayerConnection, orientation: .portrait)
                    break
                }
            }
        }

        previewLayer?.frame = videoOutputImageView.bounds
    }

    func startLiveVideo() {
        // Enable live stream video
        session.sessionPreset = AVCaptureSession.Preset.photo

        guard let captureDevice = AVCaptureDevice.default(for: .video),
            let deviceInput = try? AVCaptureDeviceInput(device: captureDevice) else {
                return
        }

//        captureDevice.set(frameRate: 2)

        let deviceOutput = AVCaptureVideoDataOutput()
        deviceOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
        // Set the quality of the video
        deviceOutput.setSampleBufferDelegate(self, queue: DispatchQueue.global(qos: DispatchQoS.QoSClass.default))
        // What the camera is seeing
        session.addInput(deviceInput)
        // What we will display on the screen
        session.addOutput(deviceOutput)

        // TODO-jc: update orientation; support rotation
        // Show the video as it's being captured
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        self.previewLayer = previewLayer
        let deviceOrientation: UIDeviceOrientation = UIDevice.current.orientation
        // Orientation is reversed
        switch deviceOrientation {
        case .landscapeLeft:
            previewLayer.connection?.videoOrientation = .landscapeRight
        case .landscapeRight:
            previewLayer.connection?.videoOrientation = .landscapeLeft
        case .portrait:
            previewLayer.connection?.videoOrientation = .portrait
        case .portraitUpsideDown:
            previewLayer.connection?.videoOrientation = .portraitUpsideDown
        default:
            previewLayer.connection?.videoOrientation = .landscapeRight
        }
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = videoOutputImageView.bounds
        videoOutputImageView.layer.addSublayer(previewLayer)

        session.startRunning()
    }

    func startBarcodeDetection() {
        let barcodeRequest = VNDetectBarcodesRequest(completionHandler: detectBarcodeHandler)
        print("!! \(VNDetectBarcodesRequest.supportedSymbologies)")
        self.requests = [barcodeRequest]
    }

    // Handles barcode detection requests
    func detectBarcodeHandler(request: VNRequest, error: Error?) {
        guard let barcodeObservations = request.results?.compactMap({ $0 as? VNBarcodeObservation }) else {
            return
        }

        let barcodes = barcodeObservations.compactMap({ $0.payloadStringValue }).uniqued()

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            guard self.session.isRunning else {
                return
            }

            guard let filteredBarcodes = self.thresholdFilter.append(value: barcodes) else {
                print(".... same: \(barcodes)")
                if barcodes.isEmpty {
                    self.videoOutputImageView.layer.sublayers?.removeSubrange(1...)
                }
                return
            }

            guard filteredBarcodes.isNotEmpty else {
                print(".... nothing")

                if let error = error {
                    print(error)
                    self.onBarcodeScanned(.failure(error))
                }

                return
            }

            self.videoOutputImageView.layer.sublayers?.removeSubrange(1...)
            self.totalNumberOfTextBoxes = 0

            // This will be used to eliminate duplicate findings
            var filteredBarcodeObservations: [String: VNBarcodeObservation] = [:]
            for barcode in barcodeObservations {
                guard let barcodeString = barcode.payloadStringValue, filteredBarcodes.contains(barcodeString) else {
                    continue
                }

                if let existingObservation = filteredBarcodeObservations[barcodeString], existingObservation.confidence > barcode.confidence {
                    continue
                }

                filteredBarcodeObservations[barcodeString] = barcode
            }

            print("~~~ \(barcodeObservations)")

            for (_, barcodeObservation) in filteredBarcodeObservations {
                self.highlightQRCode(barcode: barcodeObservation)
            }
            for (barcodeContent, barcodeObservation) in filteredBarcodeObservations {
//                self.drawTextBox(barcodeObservation: barcodeObservation, content: barcodeContent)
            }

            self.onBarcodeScanned(.success(barcodes))
        }
    }

    // Draw a box around each QRCode
    func highlightQRCode(barcode: VNBarcodeObservation) {
        let barcodeBounds = self.adjustBoundsToScreen(barcode: barcode)

        let borderWidth: CGFloat = 4.0
        let outline = CALayer()
        outline.frame = barcodeBounds.insetBy(dx: -borderWidth, dy: -borderWidth)
        outline.borderWidth = borderWidth

        let colorAnimation = CABasicAnimation(keyPath: "borderColor")
        colorAnimation.fromValue = UIColor.green.cgColor
        colorAnimation.toValue = UIColor.white.cgColor
        colorAnimation.duration = 0.5
        colorAnimation.repeatCount = .infinity

        outline.add(colorAnimation, forKey: "borderColor")

        // We are inserting the highlights at the beginning of the sublayer queue
        // To avoid overlapping with the textboxes
        videoOutputImageView.layer.addSublayer(outline)
    }

    func drawTextBox(barcodeObservation: VNBarcodeObservation, content: String) {
        let barcodeBounds = self.adjustBoundsToScreen(barcode: barcodeObservation)

        let textLayerFrame: CGRect = CGRect(x: barcodeBounds.origin.x + barcodeBounds.size.width, y: barcodeBounds.origin.y - textBoxSize.height,
                                            width: textBoxSize.width, height: textBoxSize.height)
        if videoOutputImageView.bounds.contains(textLayerFrame) {
            // Readjust box locations so that there aren't any overlapping ones...
            guard let readjustedFrame = self.readjustBoxLocationBasedOnExistingLayers(originalBox: textLayerFrame, barcodeSize: barcodeBounds.size) else {
                return
            }

            let textBox = self.createTextLayer(content: content, frame: readjustedFrame)
            textBox.name = content

            videoOutputImageView.layer.addSublayer(textBox)
            totalNumberOfTextBoxes += 1
        }
    }

    func createTextLayer(content: String, frame: CGRect) -> CATextLayer {
        let textBox = CATextLayer()
        textBox.frame = frame
        textBox.backgroundColor = UIColor.white.cgColor
        textBox.cornerRadius = 6.0

        textBox.shadowRadius = 3.0
        textBox.shadowOffset = CGSize(width: 0, height: 0)
        textBox.shadowColor = UIColor.black.cgColor
        textBox.shadowOpacity = 0.9

        let textBoxString = NSAttributedString(string: content, attributes: self.contentFormatting)
        textBox.string = textBoxString

        textBox.contentsScale = UIScreen.main.scale
        textBox.isWrapped = true

        return textBox
    }

    func adjustBoundsToScreen(barcode: VNBarcodeObservation) -> CGRect {
        // Current origin is on the bottom-left corner
        let xCord = barcode.boundingBox.origin.x * videoOutputImageView.frame.size.width
        var yCord = (1 - barcode.boundingBox.origin.y) * videoOutputImageView.frame.size.height
        let width = barcode.boundingBox.size.width * videoOutputImageView.frame.size.width
        var height = -1 * barcode.boundingBox.size.height * videoOutputImageView.frame.size.height

        // Re-adjust origin to be on the top-left corner, so that calculations can be standardized
        yCord += height
        height *= -1

        let updatedFrame = CGRect(x: xCord, y: yCord, width: width, height: height)
        print("barcode bounds: \(barcode.boundingBox) --> \(updatedFrame)")

        return updatedFrame
    }

    // Re-adjusts the given box's location based on other boxes that exist on other layers, so that boxes don't overlap
    // Returns nil if there is nowhere to place the box on
    func readjustBoxLocationBasedOnExistingLayers(originalBox: CGRect, barcodeSize: CGSize) -> CGRect? {
        guard let videoOutputLayers: [CALayer] = videoOutputImageView.layer.sublayers else {
            return nil
        }

        // Skip the first layer (i.e. the video layer) and outline layers
        let textBoxLayers: [CALayer] = Array(videoOutputLayers[(videoOutputLayers.count - totalNumberOfTextBoxes)...])

        let bottomLeftAnchorBox = originalBox
        let topLeftAnchorBox = CGRect(x: originalBox.origin.x, y: originalBox.origin.y + originalBox.size.height + barcodeSize.height,
                                      width: originalBox.size.width, height: originalBox.size.height)
        let topRightAnchorBox = CGRect(x: originalBox.origin.x - barcodeSize.width - originalBox.size.width, y: originalBox.origin.y + barcodeSize.height + originalBox.size.height,
                                       width: originalBox.size.width, height: originalBox.size.height)
        let bottomRightAnchorBox = CGRect(x: originalBox.origin.x - barcodeSize.width - originalBox.size.width, y: originalBox.origin.y,
                                          width: originalBox.size.width, height: originalBox.size.height)
        var potentialBoxes: [BoxAnchorLocation : CGRect] = [
            .bottomLeft: bottomLeftAnchorBox,
            .topLeft: topLeftAnchorBox,
            .topRight: topRightAnchorBox,
            .bottomRight: bottomRightAnchorBox
        ]

        var potentialBoxToUse: (CGRect?, BoxAnchorLocation) = (nil, .none)
        for layer in textBoxLayers {
            for (type, potentialBox) in potentialBoxes {
                if videoOutputImageView.bounds.contains(potentialBox) && !potentialBox.intersects(layer.frame) {
                    potentialBoxToUse = (potentialBox, type)
                } else {
                    if potentialBoxToUse.1 == type {
                        potentialBoxToUse = (nil, .none)
                    }
                    potentialBoxes.removeValue(forKey: type)
                }
            }
        }

        if textBoxLayers.count < 1 {
            potentialBoxToUse = (originalBox, .bottomLeft)
        }

        return potentialBoxToUse.0
    }
}


// MARK: Configurations
//
private extension BarcodeScannerViewController {
    func configureVideoOutputImageView() {
        videoOutputImageView.contentMode = .scaleAspectFit
    }
}

// MARK: - Orientation
//
private extension BarcodeScannerViewController {
    private func updatePreviewLayer(layer: AVCaptureConnection, orientation: AVCaptureVideoOrientation) {
        layer.videoOrientation = orientation
    }
}

extension BarcodeScannerViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    // Run Vision code with live stream
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        throttler.throttle { [weak self] in
            guard let self = self else { return }

            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                return
            }

            var requestOptions: [VNImageOption: Any] = [:]

            if let camData = CMGetAttachment(sampleBuffer, key: kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, attachmentModeOut: nil) {
                requestOptions = [.cameraIntrinsics: camData]
            }

            let imageOrientation = self.imageOrientationFromDeviceOrientation()

            // For object detection, keeping track of the image buffer size
            // to know how to draw bounding boxes based on relative values.
            // https://developer.apple.com/documentation/coreml/understanding_a_dice_roll_with_vision_and_object_detection
            // TODO-jc: remove if not needed eventually
//            if self.bufferSize == nil || self.lastBufferOrientation != imageOrientation {
//                self.lastBufferOrientation = imageOrientation
//                let pixelBufferWidth = CVPixelBufferGetWidth(pixelBuffer)
//                let pixelBufferHeight = CVPixelBufferGetHeight(pixelBuffer)
//                if [.up, .down].contains(imageOrientation) {
//                    self.bufferSize = CGSize(width: pixelBufferWidth,
//                                             height: pixelBufferHeight)
//                } else {
//                    self.bufferSize = CGSize(width: pixelBufferHeight,
//                                             height: pixelBufferWidth)
//                }
//                print("video buffer size: \(self.bufferSize)")
//            }

            // CGImagePropertyOrientation(rawValue: 6)
            let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: imageOrientation, options: requestOptions)

            do {
                try imageRequestHandler.perform(self.requests)
            } catch {
                print(error)
            }
        }
    }

    private func imageOrientationFromDeviceOrientation() -> CGImagePropertyOrientation {
        let orientation = UIDevice.current.orientation

        let imageOrientation: CGImagePropertyOrientation
        switch orientation {
        case .portrait:
            imageOrientation = .right
        case .portraitUpsideDown:
            imageOrientation = .left
        case .landscapeLeft:
            imageOrientation = .up
        case .landscapeRight:
            imageOrientation = .down
        case .unknown:
            print("The device orientation is unknown, the predictions may be affected")
            fallthrough
        default:
            // By default keep the last orientation
            // This applies for faceUp and faceDown
            imageOrientation = .right
        }
        return imageOrientation
    }
}
