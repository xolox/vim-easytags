" Vim plug-in
" Author: Peter Odding <peter@peterodding.com>
" Last Change: August 19, 2013
" URL: http://peterodding.com/code/vim/easytags/
" Requires: Exuberant Ctags (http://ctags.sf.net)

" Support for automatic update using the GLVS plug-in.
" GetLatestVimScripts: 3114 1 :AutoInstall: easytags.zip

" Don't source the plug-in when it's already been loaded or &compatible is set.
if &cp || exists('g:loaded_easytags')
  finish
endif

" Make sure vim-misc is installed. {{{1

try
  " The point of this code is to do something completely innocent while making
  " sure the vim-misc plug-in is installed. We specifically don't use Vim's
  " exists() function because it doesn't load auto-load scripts that haven't
  " already been loaded yet (last tested on Vim 7.3).
  call type(g:xolox#misc#version)
catch
  echomsg "Warning: The vim-easytags plug-in requires the vim-misc plug-in which seems not to be installed! For more information please review the installation instructions in the readme (also available on the homepage and on GitHub). The vim-easytags plug-in will now be disabled."
  let g:loaded_easytags = 1
  finish
endtry

" Configuration defaults and initialization. {{{1

if !exists('g:easytags_file')
  if xolox#misc#os#is_win()
    let g:easytags_file = '~\_vimtags'
  else
    let g:easytags_file = '~/.vimtags'
  endif
endif

if !exists('g:easytags_by_filetype')
  let g:easytags_by_filetype = ''
endif

if !exists('g:easytags_events')
  let g:easytags_events = []
  if !exists('g:easytags_on_cursorhold') || g:easytags_on_cursorhold
    call extend(g:easytags_events, ['CursorHold', 'CursorHoldI'])
  endif
  if exists('g:easytags_always_enabled') && g:easytags_always_enabled
    call extend(g:easytags_events, ['BufReadPost', 'BufWritePost', 'FocusGained', 'ShellCmdPost', 'ShellFilterPost'])
  endif
endif

if !exists('g:easytags_ignored_filetypes')
  let g:easytags_ignored_filetypes = '^tex$'
endif

if exists('g:easytags_ignored_syntax_groups')
  call xolox#misc#msg#warn("easytags.vim %s: The 'g:easytags_ignored_syntax_groups' option is no longer supported. It has been moved back into the code base for more flexible handling at runtime.", g:xolox#easytags#version)
endif

if !exists('g:easytags_python_script')
  let g:easytags_python_script = expand('<sfile>:p:h') . '/../misc/easytags/highlight.py'
endif

" Make sure Exuberant Ctags >= 5.5 is installed.
if !xolox#easytags#initialize('5.5')
  " Did the user configure the plug-in to suppress the regular warning message?
  if !(exists('g:easytags_suppress_ctags_warning') && g:easytags_suppress_ctags_warning)
    " Explain to the user what went wrong:
    if !exists('g:easytags_ctags_version') || empty(g:easytags_ctags_version)
      " Exuberant Ctags is not installed / could not be found.
      let s:msg = "easytags.vim %s: Plug-in not loaded because Exuberant Ctags isn't installed!"
      if executable('apt-get')
        let s:msg .= " On Ubuntu & Debian you can install Exuberant Ctags by"
        let s:msg .= " installing the package named `exuberant-ctags':"
        let s:msg .= " sudo apt-get install exuberant-ctags"
      else
        let s:msg .= " Please download & install Exuberant Ctags from http://ctags.sf.net"
      endif
      call xolox#misc#msg#warn(s:msg, g:xolox#easytags#version)
    else
      " The installed version is too old.
      let s:msg = "easytags.vim %s: Plug-in not loaded because Exuberant Ctags 5.5"
      let s:msg .= " or newer is required while you have version %s installed!"
      call xolox#misc#msg#warn(s:msg, g:xolox#easytags#version, g:easytags_ctags_version)
    endif
    unlet s:msg
  endif
  " Stop loading the plug-in; don't define the (automatic) commands.
  finish
endif

" The plug-in initializes the &tags option as soon as possible so that the
" global tags file is available when using "vim -t some_tag". If &tags is
" reset, we'll try again on the "VimEnter" automatic command event (below).
call xolox#easytags#register(1)

" The :UpdateTags and :HighlightTags commands. {{{1

command! -bar -bang -nargs=* -complete=file UpdateTags call xolox#easytags#update(0, <q-bang> == '!', [<f-args>])
command! -bar HighlightTags call xolox#easytags#highlight()
command! -bang TagsByFileType call xolox#easytags#by_filetype(<q-bang> == '!')

" Automatic commands. {{{1

augroup PluginEasyTags
  autocmd!
  " This is the alternative way of registering the global tags file using
  " the automatic command event "VimEnter". Apparently this makes the
  " plug-in behave better when used together with tplugin?
  autocmd VimEnter * call xolox#easytags#register(1)
  " Define the automatic commands to perform updating/highlighting.
  for s:eventname in g:easytags_events
    execute 'autocmd' s:eventname '* call xolox#easytags#autoload(' string(s:eventname) ')'
  endfor
  " Define an automatic command to register file type specific tags files?
  if !empty(g:easytags_by_filetype)
    autocmd FileType * call xolox#easytags#register(0)
  endif
  " After reloading a buffer the dynamic syntax highlighting is lost. The
  " following code makes sure the highlighting is refreshed afterwards.
  autocmd BufReadPost * unlet! b:easytags_last_highlighted
augroup END

" }}}1

" Make sure the plug-in is only loaded once.
let g:loaded_easytags = 1

" vim: ts=2 sw=2 et
