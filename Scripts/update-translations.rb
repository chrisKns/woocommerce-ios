#!/usr/bin/env ruby
# Supported languages:
# ar,zh-Hans,zh-Hant,nl,fr,de,he,id,ko,pt,ru,es,sv,tr,ja,it
# * Arabic
# * Chinese (China) [zh-Hans]
# * Chinese (Taiwan) [zh-Hant]
# * Dutch
# * French
# * German
# * Hebrew
# * Indonesian
# * Korean
# * Portuguese (Brazil)
# * Russian
# * Spanish
# * Swedish
# * Turkish
# * Japanese
# * Italian

if Dir.pwd =~ /Scripts/
  puts 'Must run script from root folder'
  exit
end

ALL_LANGS = {
  'ar' => 'ar',         # Arabic
  'de' => 'de',         # German
  'es' => 'es',         # Spanish
  'fr' => 'fr',         # French
  'he' => 'he',         # Hebrew
  'id' => 'id',         # Indonesian
  'it' => 'it',         # Italian
  'ja' => 'ja',         # Japanese
  'ko' => 'ko',         # Korean
  'nl' => 'nl',         # Dutch
  'pt-br' => 'pt-BR',   # Portuguese (Brazil)
  'ru' => 'ru',         # Russian
  'sv' => 'sv',         # Swedish
  'tr' => 'tr',         # Turkish
  'zh-cn' => 'zh-Hans', # Chinese (China)
  'zh-tw' => 'zh-Hant' # Chinese (Taiwan)
}

langs = {}
if ARGV.count > 0
  ARGV.each do |key|
    unless local = ALL_LANGS[key]
      puts "Unknown language #{key}"
      exit 1
    end
    langs[key] = local
  end
else
  langs = ALL_LANGS
end

langs.each do |code, local|
  lang_dir = File.join('WooCommerce', 'Resources', "#{local}.lproj")
  puts "Updating #{code}"
  system "mkdir -p #{lang_dir}"
  system "if [ -e #{lang_dir}/Localizable.strings ]; then cp #{lang_dir}/Localizable.strings #{lang_dir}/Localizable.strings.bak; fi"
  system "curl -sSfL --globoff -o #{lang_dir}/Localizable.strings https://translate.wordpress.com/projects/woocommerce/woocommerce-ios/#{code}/default/export-translations?format=strings" or begin
    puts "Error downloading #{code}"
  end
  system "./Scripts/fix-translation #{lang_dir}/Localizable.strings"
  system "plutil -lint #{lang_dir}/Localizable.strings" and system "rm #{lang_dir}/Localizable.strings.bak"
  system "grep -a '\\x00\\x20\\x00\\x22\\x00\\x22\\x00\\x3b$' #{lang_dir}/Localizable.strings"
end
