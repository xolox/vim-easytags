#!/usr/bin/python

'''
Resolve symbolic links in tags files and remove duplicate entries from the
resulting list of tags. If your tags files contain symbolic links as well as
canonical filenames this can significantly reduce the size of your tags file.
This script makes a backup of the tags file in case something goes wrong.

Author: Peter Odding <peter@peterodding.com>
Last Change: May 11, 2011
URL: https://github.com/xolox/vim-easytags/blob/master/normalize-tags.py
'''

import os, sys, time

tagsfile = os.path.expanduser(len(sys.argv) > 1 and sys.argv[1] or '~/.vimtags')
tempname = '%s-new-%d' % (tagsfile, time.time())
results, cache = {}, {}
infile = open(tagsfile)
outfile = open(tempname, 'w')
nprocessed = 0
fold_case = False

for line in infile:
  nprocessed += 1
  line = line.rstrip()
  fields = line.split('\t')
  if line.startswith('!_TAG_'):
    results[line] = True
    if line.startswith('!_TAG_FILE_SORTED\t2'):
      fold_case = True
  else:
    pathname = fields[1]
    if pathname not in cache:
      if not os.path.exists(pathname): continue
      cache[pathname] = os.path.realpath(pathname)
    fields[1] = cache[pathname]
    results['\t'.join(fields)] = True

infile.close()

lines = results.keys()
if fold_case:
  lines.sort(key=str.lower)
else:
  lines.sort()

outfile.write('\n'.join(lines))
outfile.write('\n')
outfile.close()

backup = '%s-backup-%d' % (tagsfile, time.time())
print "Making a backup of %s as %s" % (tagsfile, backup)
os.rename(tagsfile, backup)

print "Replacing old", tagsfile, "with new one"
os.rename(tempname, tagsfile)

nfiltered = nprocessed - len(lines)
print "Filtered %d out of %d entries" % (nfiltered, nprocessed)

# vim: ts=2 sw=2 et
