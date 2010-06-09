# Long term plans

 * Integration with my unreleased project plug-in so that when you edit any
   file in a project, all related files are automatically scanned for tags?

 * Use separate tags files for each language stored in ~/.vim/tags/ to increase
   performance because a single, global tags file quickly grows to a megabyte?

 * I might have found a bug in Vim: The tag `easytags#highlight_cmd` was
   correctly being highlighted by my plug-in (and was indeed included in my
   tags file) even though I couldn't jump to it using `Ctrl-]`, which caused:

    E426: tag not found: easytags#highlight_cmd

   But immediately after that error if I do:

    :echo taglist('easytags#highlight_cmd')
    [{'cmd': '/^function! easytags#highlight_cmd() " {{{1$/', 'static': 0,
    \ 'name': 'easytags#highlight_cmd', 'language': 'Vim', 'kind': 'f',
    \ 'filename': '/home/peter/Development/Vim/vim-easytags/autoload.vim'}]

   It just works?! Some relevant context:
   I was editing `~/.vim/plugin/easytags.vim` at the time (a symbolic link to
   `~/Development/Vim/vim-easytags/easytags.vim`) and wanted to jump to the
   definition of the function `easytags#highlight_cmd` in
   `~/.vim/autoload/easytags.vim` (a symbolic link to
   `~/Development/Vim/vim-easytags/autoload.vim`). I was already editing
   `~/.vim/autoload/easytags.vim` in another Vim buffer.
