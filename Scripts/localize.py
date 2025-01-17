#!/usr/bin/env python
# -*- coding: utf-8 -*-

# This program is free software. It comes without any warranty, to
# the extent permitted by applicable law. You can redistribute it
# and/or modify it under the terms of the Do What The Fuck You Want
# To Public License, Version 2, as published by Sam Hocevar. See
# http://sam.zoy.org/wtfpl/COPYING for more details.
# 
# Localize.py - Incremental localization on XCode projects
# João Moreno 2009
# http://joaomoreno.com/

from sys import argv
from codecs import open
from re import compile
from copy import copy
import os

STRINGS_FILE = 'Localizable.strings'

re_translation = compile(r'^"(.+)" = "(.+)";$')
re_comment_single = compile(r'^/(/.*|\*.*\*/)$')
re_comment_start = compile(r'^/\*.*$')
re_comment_end = compile(r'^.*\*/$')

def print_help():
    print u"""Usage: merge.py merged_file old_file new_file
Xcode localizable strings merger script. João Moreno 2009."""

class LocalizedString():
    def __init__(self, comments, translation):
        self.comments, self.translation = comments, translation
        self.key, self.value = re_translation.match(self.translation).groups()

    def __unicode__(self):
        try:
            for idx, val in enumerate(self.comments):
                if (idx > 0) and (idx < (len(self.comments) - 1)):
                    self.comments[idx] = self.comments[idx].replace('\n',' - ')
                    self.comments[idx + 1] = self.comments[idx + 1].lstrip()
        except:
            exit(-1)
            print "Couldn't strip comments"

        joined_comments = u''.join(self.comments)
        return u'%s%s\n' % (joined_comments, self.translation)

class LocalizedFile():
    def __init__(self, fname=None, auto_read=False):
        self.fname = fname
        self.strings = []
        self.strings_d = {}

        if auto_read:
            self.read_from_file(fname)

    def read_from_file(self, fname=None):
        fname = self.fname if fname == None else fname
        try:
            f = open(fname, encoding='utf_8', mode='r')
        except:
            print 'File %s does not exist.' % fname
            exit(-1)
        
        line = f.readline()
        while line and line == u'\n':
            line = f.readline()

        while line:
            comments = [line]

            if not re_comment_single.match(line):
                while line and not re_comment_end.match(line):
                    line = f.readline()
                    comments.append(line)
            
            line = f.readline()
            if line and re_translation.match(line):
                translation = line
            else:
                raise Exception('invalid file: %s' % line)
            
            line = f.readline()
            while line and line == u'\n':
                line = f.readline()

            string = LocalizedString(comments, translation)
            self.strings.append(string)
            self.strings_d[string.key] = string

        f.close()

    def save_to_file(self, fname=None):
        fname = self.fname if fname == None else fname
        try:
            f = open(fname, encoding='utf_8', mode='w')
        except:
            print 'Couldn\'t open file %s.' % fname
            exit(-1)

        for string in self.strings:
            f.write(string.__unicode__())

        f.close()

    def merge_with(self, new):
        merged = LocalizedFile()

        for string in new.strings:
            if self.strings_d.has_key(string.key):
                new_string = copy(self.strings_d[string.key])
                new_string.comments = string.comments
                string = new_string

            merged.strings.append(string)
            merged.strings_d[string.key] = string

        return merged

def merge(merged_fname, old_fname, new_fname):
    try:
        old = LocalizedFile(old_fname, auto_read=True)
        new = LocalizedFile(new_fname, auto_read=True)
    except Exception as e:
        print 'Error: input files have invalid format. old: %s, new: %s' % (old_fname, new_fname)
        print e

    merged = old.merge_with(new)

    merged.save_to_file(merged_fname)

def convert_file_encoding(input_file, input_encoding, output_encoding):
    tmp_file = input_file + '.' + output_encoding
    os.system('iconv -f %s -t %s "%s" > "%s"' % (input_encoding, output_encoding, input_file, tmp_file))
    os.rename(tmp_file, input_file)

def gen_strings(output_dir, input_files):
    os.system('genstrings -q -o "%s" %s' % (output_dir, input_files))
    # genstrings always produces output in UTF-16LE so we must explictly convert to UTF-8
    convert_file_encoding(output_dir + os.path.sep + STRINGS_FILE, 'UTF-16LE', 'UTF-8')

def localize(paths, language):
    # Failsafe
    current_path = os.getcwd()
    os.chdir(current_path)

    if not os.path.exists('Scripts'):
        print "Must run script from the root folder"
        quit()

    # Output
    original = merged = language + os.path.sep + STRINGS_FILE
    old = original + '.old'
    new = original + '.new'

    # Localization Loop
    target_folders = ' '.join(paths)
    find_cmd = 'find ' + target_folders + ' -name "*.m" -o -name "*.swift" | grep -v Vendor'
    filelist = os.popen(find_cmd).read().strip().split('\n')
    filelist = '"{0}"'.format('" "'.join(filelist))

    if os.path.isfile(original):
        os.rename(original, old)
        gen_strings(language, filelist)
        os.rename(original, new)
        merge(merged, old, new)
        os.remove(new)
        os.remove(old)
    else:
        gen_strings(language, filelist)

## Main
##
if __name__ == '__main__':
    paths = ['WooCommerce', 'Pods/WordPress*', 'Storage/Storage', 'Networking/Networking', 'Hardware/Hardware']
    language = 'WooCommerce/Resources/en.lproj'

    localize(paths, language)

