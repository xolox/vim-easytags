# To-do list for the easytags plug-in for Vim

## New functionality

 * Automatically index C headers when `/usr/include/$name.h` exists?

 * Integration with my unreleased project plug-in so that when you edit any file in a project, all related files are automatically scanned for tags?

 * Make `g:easytags_autorecurse` accept the following values: 0 (only scan the current file), 1 (always scan all files in the same directory) and 2 (always recurse down the current directory)?

 * Several users have reported the plug-in locking Vim up and this was invariably caused by the plug-in trying to highlight the tags from a very large tags file. Maybe the plug-in should warn about this so the cause is immediately clear to users. It's also possible to temporarily change the `tags` option so that `taglist()` doesn't look at tags files that are bigger than a certain size but this feels like a hack and it may be better to go with the option below.
 
 * The functionality of the Python highlight script can just as well be implemented in Vim script (using `readfile()` instead of `taglist()`), the only notable difference being that Vim cannot read files line wise. This would remove the duplication of code between Vim script and Python and would mean all users get to enjoy a faster plug-in! I'm not sure whether a Vim script implementation of the same code would be equally fast though, so I should implement and benchmark! This would also easily enable the plug-in to ignore tags files that are too large (see above).

## Possible bugs

 * Right now easytags is a messy combination of Vim script code and Python scripts. I plan to port the Python code back to Vim script.

 * On Microsoft Windows (tested on XP) GVim loses focus while `ctags` is running because Vim opens a command prompt window. Also the CursorHold event seems to fire repeatedly, contradicting my understanding of the automatic command and its behavior on UNIX?! This behavior doesn't occur when I use the integration with my `shell.vim` plug-in.

 * I might have found a bug in Vim: The tag `easytags#highlight_cmd` was correctly being highlighted by my plug-in (and was indeed included in my tags file) even though I couldn't jump to it using `Ctrl-]`, which caused:

    E426: tag not found: easytags#highlight_cmd

   But immediately after that error if I do:

    :echo taglist('easytags#highlight_cmd')
    [{'cmd': '/^function! easytags#highlight_cmd() " {{{1$/', 'static': 0,
    \ 'name': 'easytags#highlight_cmd', 'language': 'Vim', 'kind': 'f',
    \ 'filename': '/home/peter/Development/Vim/vim-easytags/autoload.vim'}]

   It just works?! Some relevant context: I was editing `~/.vim/plugin/easytags.vim` at the time (a symbolic link to `~/Development/Vim/vim-easytags/easytags.vim`) and wanted to jump to the definition of the function `easytags#highlight_cmd` in `~/.vim/autoload/easytags.vim` (a symbolic link to `~/Development/Vim/vim-easytags/autoload.vim`). I was already editing `~/.vim/autoload/easytags.vim` in another Vim buffer.

vim: ai nofen
