#!/usr/bin/python

'''
Determine which files are contributing the most to the size of a tags file. You
can specify the location of the tags file as a command line argument. If you
pass a numeric argument, no more than that many files will be reported.

Author: Peter Odding <peter@peterodding.com>
Last Change: May 11, 2011
URL: https://github.com/xolox/vim-easytags/blob/master/why-so-slow.py
'''

import os, sys

tagsfile = '~/.vimtags'
topfiles = 10

for arg in sys.argv[1:]:
  if os.path.isfile(arg):
    tagsfile = arg
  else:
    topfiles = int(arg)

infile = open(os.path.expanduser(tagsfile))
counters = {}

for line in infile:
  fields = line.split('\t')
  filename = fields[1]
  counters[filename] = counters.get(filename, 0) + len(line)
infile.close()

sortedfiles = sorted([(s, n) for (n, s) in counters.iteritems()], reverse=True)
for filesize, filename in sortedfiles[:topfiles]:
  if filename.startswith(os.environ['HOME']):
    filename = filename.replace(os.environ['HOME'], '~')
  print '%i KB - %s' % (filesize / 1024, filename)

# vim: ts=2 sw=2 et
