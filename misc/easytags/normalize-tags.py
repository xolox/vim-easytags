#!/usr/bin/python

'''
Resolve symbolic links in tags files and remove duplicate entries from the
resulting list of tags. If your tags files contain symbolic links as well as
canonical filenames this can significantly reduce the size of your tags file.
This script makes a backup of the tags file in case something goes wrong.

Author: Peter Odding <peter@peterodding.com>
Last Change: September 4, 2011
URL: https://github.com/xolox/vim-easytags/blob/master/normalize-tags.py
'''

import os, sys, time

def main(arguments):
  for tagsfile in arguments or [os.path.expanduser('~/.vimtags')]:
    normalize(tagsfile)
  print "Done!"

def normalize(tagsfile):

  # Setup.
  tempname = '%s-new-%d' % (tagsfile, time.time())
  results, cache = {}, {}
  infile = open(tagsfile)
  outfile = open(tempname, 'w')
  nprocessed = 0
  fold_case = False

  # Read tags file. 
  for line in infile:
    line = line.rstrip()
    fields = line.split('\t')
    if line.startswith('!_TAG_'):
      results[line] = True
      if line.startswith('!_TAG_FILE_SORTED\t2'):
        fold_case = True
    else:
      pathname = fields[1]
      if pathname not in cache:
        if os.path.exists(pathname):
          cache[pathname] = os.path.realpath(pathname)
        else:
          cache[pathname] = ''
      if cache[pathname]:
        fields[1] = cache[pathname]
        results['\t'.join(fields)] = True
    nprocessed += 1
  infile.close()

  # Sort tags.
  lines = results.keys()
  if fold_case:
    lines.sort(key=str.lower)
  else:
    lines.sort()

  # Write tags file.
  outfile.write('\n'.join(lines))
  outfile.write('\n')
  outfile.close()

  # Backup old tags file.
  backup = '%s-backup-%d' % (tagsfile, time.time())
  print "Making a backup of %s as %s" % (tagsfile, backup)
  os.rename(tagsfile, backup)

  # Replace tags file.
  print "Replacing old", tagsfile, "with new one"
  os.rename(tempname, tagsfile)

  # Report results.
  nfiltered = nprocessed - len(lines)
  print "Filtered %d out of %d entries" % (nfiltered, nprocessed)

if __name__ == '__main__':
  main(sys.argv[1:])

# vim: ts=2 sw=2 et
