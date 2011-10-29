" Vim plug-in
" Author: Peter Odding <peter@peterodding.com>
" Last Change: October 29, 2011
" URL: http://peterodding.com/code/vim/easytags/
" Requires: Exuberant Ctags (http://ctags.sf.net)

" Support for automatic update using the GLVS plug-in.
" GetLatestVimScripts: 3114 1 :AutoInstall: easytags.zip

" Don't source the plug-in when it's already been loaded or &compatible is set.
if &cp || exists('g:loaded_easytags')
  finish
endif

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

if !exists('g:easytags_ignored_syntax_groups')
  let g:easytags_ignored_syntax_groups = '.*String.*,.*Comment.*,cIncluded'
endif

if !exists('g:easytags_python_script')
  let g:easytags_python_script = expand('<sfile>:p:h') . '/../misc/easytags/highlight.py'
endif

function! s:InitEasyTags(version)
  " Check that the location of Exuberant Ctags has been configured or that the
  " correct version of the program exists in one of its default locations.
  if exists('g:easytags_cmd') && s:CheckCtags(g:easytags_cmd, a:version)
    return 1
  endif
  if xolox#misc#os#is_win()
    " FIXME The code below that searches the $PATH is not used on Windows at
    " the moment because xolox#misc#path#which() generally produces absolute
    " paths and on Windows these absolute paths tend to contain spaces which
    " makes xolox#shell#execute() fail. I've tried quoting the program name
    " with double quotes but it fails just the same (it works with system()
    " though). Anyway the problem of having multiple conflicting versions of
    " Exuberant Ctags installed is not that relevant to Windows since it
    " doesn't have a package management system. I still want to fix
    " xolox#shell#execute() though.
    if s:CheckCtags('ctags', a:version)
      let g:easytags_cmd = 'ctags'
      return 1
    endif
  else
    " Exuberant Ctags can be installed under multiple names:
    "  - On Ubuntu Linux, Exuberant Ctags is installed as `ctags'.
    "  - On Debian Linux, Exuberant Ctags is installed as `exuberant-ctags'.
    "  - On Free-BSD, Exuberant Ctags is installed as `exctags'.
    " IIUC on Mac OS X the program /usr/bin/ctags is installed by default but
    " unusable and when the user installs Exuberant Ctags in an alternative
    " location, it doesn't come before /usr/bin/ctags in the search path. To
    " solve this problem in a general way and to save every Mac user out there
    " some frustration the plug-in will search the path and consider every
    " possible location, meaning that as long as Exuberant Ctags is installed
    " in the $PATH the plug-in should find it automatically.
    for program in xolox#misc#path#which('ctags', 'exuberant-ctags', 'exctags')
      if s:CheckCtags(program, a:version)
        let g:easytags_cmd = program
        return 1
      endif
    endfor
  endif
endfunction

function! s:CheckCtags(name, version)
  " Not every executable out there named `ctags' is in fact Exuberant Ctags.
  " This function makes sure it is because the easytags plug-in requires the
  " --list-languages option (and more).
  if executable(a:name)
    let command = a:name . ' --version'
    try
      let listing = join(xolox#shell#execute(command, 1), '\n')
    catch /^Vim\%((\a\+)\)\=:E117/
      " Ignore missing shell.vim plug-in.
      let listing = system(command)
    catch
      " xolox#shell#execute() converts shell errors to exceptions and since
      " we're checking whether one of several executables exists we don't want
      " to throw an error when the first one doesn't!
      return
    endtry
    let pattern = 'Exuberant Ctags \zs\(\d\+\(\.\d\+\)*\|Development\)'
    let g:easytags_ctags_version = matchstr(listing, pattern)
    if g:easytags_ctags_version == 'Development'
      return 1
    else
      return s:VersionToNumber(g:easytags_ctags_version) >= a:version
    endif
  endif
endfunction

function! s:VersionToNumber(s)
  let values = split(a:s, '\.')
  if len(values) == 1
    return values[0] * 10
  elseif len(values) >= 2
    return values[0] * 10 + values[1][0]
  endif
endfunction

if !s:InitEasyTags(55)
  if exists('g:easytags_suppress_ctags_warning') && g:easytags_suppress_ctags_warning
    finish
  endif
  if !exists('g:easytags_ctags_version') || empty(g:easytags_ctags_version)
    let s:msg = "easytags.vim %s: Plug-in not loaded because Exuberant Ctags isn't installed!"
    if executable('apt-get')
      let s:msg .= " On Ubuntu & Debian you can install Exuberant Ctags by"
      let s:msg .= " installing the package named `exuberant-ctags':"
      let s:msg .= " sudo apt-get install exuberant-ctags"
    else
      let s:msg .= " Please download & install Exuberant Ctags from http://ctags.sf.net"
    endif
    echomsg printf(s:msg, g:xolox#easytags#version)
  else
    let s:msg = "easytags.vim %s: Plug-in not loaded because Exuberant Ctags 5.5"
    let s:msg .= " or newer is required while you have version %s installed!"
    echomsg printf(s:msg, g:xolox#easytags#version, g:easytags_ctags_version)
  endif
  unlet s:msg
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
