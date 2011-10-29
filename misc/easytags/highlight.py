'''
This Python script is part of the easytags plug-in for the Vim text editor. The
Python Interface to Vim is used to load this script which accelerates dynamic
syntax highlighting by reimplementing tag file reading and :syntax command
generation in Python with a focus on doing the least amount of work.

Author: Peter Odding <peter@peterodding.com>
Last Change: October 29, 2011
URL: http://peterodding.com/code/vim/easytags
'''

# TODO Cache the contents of tags files to further improve performance?

import re
import vim
import sys

def easytags_ping():
    print 'it works!'

def easytags_gensyncmd(tagsfiles, filetype, tagkinds, syntaxgroup, prefix, suffix, filters, ignoresyntax):
    # Get arguments from Vim.
    if filters:
        tagkinds = filters['kind']
    # Shallow parse tags files for matching identifiers.
    pattern = '^([^\t]+)\t[^\t]+\t[^\t]+\t' + tagkinds + '\tlanguage:' + filetype
    compiled_pattern = re.compile(pattern, re.IGNORECASE)
    matches = {}
    for fname in tagsfiles:
        handle = open(fname)
        for line in handle:
            m = compiled_pattern.match(line)
            if m and ('match' not in filters or re.search(filters['match'], line)) \
                    and ('nomatch' not in filters or not re.search(filters['nomatch'], line)):
                matches[m.group(1)] = True
        handle.close()
    # Generate Vim :syntax command to highlight identifiers.
    patterns, commands = [], []
    counter, limit = 0, 1024 * 20
    to_escape = re.compile(r'[.*^$/\\~\[\]]')
    for ident in matches.keys():
        escaped = to_escape.sub(r'\\\0', ident)
        patterns.append(escaped)
        counter += len(escaped)
        if counter > limit:
            commands.append(_easytags_makecmd(syntaxgroup, prefix, suffix, patterns, ignoresyntax))
            patterns = []
            counter = 0
    if patterns:
        commands.append(_easytags_makecmd(syntaxgroup, prefix, suffix, patterns, ignoresyntax))
    return ' | '.join(commands)

def _easytags_makecmd(syntaxgroup, prefix, suffix, patterns, ignoresyntax):
    template = r'syntax match %s /%s\%%(%s\)%s/ containedin=ALLBUT,%s'
    return template % (syntaxgroup, prefix, r'\|'.join(patterns), suffix, ignoresyntax)
