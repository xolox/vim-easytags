" Vim script
" Author: Peter Odding <peter@peterodding.com>
" Last Change: July 9, 2014
" URL: http://peterodding.com/code/vim/easytags/

let g:xolox#easytags#version = '3.6'

" Plug-in initialization. {{{1

function! xolox#easytags#initialize(min_version) " {{{2
  " Check that the location of Exuberant Ctags has been configured or that the
  " correct version of the program exists in one of its default locations.
  if exists('g:easytags_cmd') && xolox#easytags#check_ctags_compatible(g:easytags_cmd, a:min_version)
    return 1
  endif
  if xolox#misc#os#is_win()
    " FIXME The code below that searches the $PATH is not used on Windows at
    " the moment because xolox#misc#path#which() generally produces absolute
    " paths and on Windows these absolute paths tend to contain spaces which
    " makes xolox#shell#execute_with_dll() fail. I've tried quoting the
    " program name with double quotes but it fails just the same (it works
    " with system() though). Anyway the problem of having multiple conflicting
    " versions of Exuberant Ctags installed is not that relevant to Windows
    " since it doesn't have a package management system. I still want to fix
    " xolox#shell#execute_with_dll() though.
    if xolox#easytags#check_ctags_compatible('ctags', a:min_version)
      let g:easytags_cmd = 'ctags'
      return 1
    endif
  else
    " Exuberant Ctags can be installed under several names:
    "  - On Ubuntu Linux, Exuberant Ctags is installed as `ctags-exuberant'
    "    (and possibly `ctags' but that one can't be trusted :-)
    "  - On Debian Linux, Exuberant Ctags is installed as `exuberant-ctags'.
    "  - On Free-BSD, Exuberant Ctags is installed as `exctags'.
    " IIUC on Mac OS X the program /usr/bin/ctags is installed by default but
    " unusable and when the user installs Exuberant Ctags in an alternative
    " location, it doesn't come before /usr/bin/ctags in the search path. To
    " solve this problem in a general way and to save every Mac user out there
    " some frustration the plug-in will search the path and consider every
    " possible location, meaning that as long as Exuberant Ctags is installed
    " in the $PATH the plug-in should find it automatically.
    for program in xolox#misc#path#which('exuberant-ctags', 'ctags-exuberant', 'ctags', 'exctags')
      if xolox#easytags#check_ctags_compatible(program, a:min_version)
        let g:easytags_cmd = program
        return 1
      endif
    endfor
  endif
endfunction

function! xolox#easytags#check_ctags_compatible(name, min_version) " {{{2
  " Not every executable out there named `ctags' is in fact Exuberant Ctags.
  " This function makes sure it is because the easytags plug-in requires the
  " --list-languages option (and more).
  call xolox#misc#msg#debug("easytags.vim %s: Checking if Exuberant Ctags is installed as '%s'.", g:xolox#easytags#version, a:name)
  " Make sure the given program is executable.
  if !executable(a:name)
    call xolox#misc#msg#debug("easytags.vim %s: Program '%s' is not executable!", g:xolox#easytags#version, a:name)
    return 0
  endif
  " Make sure the command exits without reporting an error.
  let command = a:name . ' --version'
  let result = xolox#misc#os#exec({'command': command, 'check': 0})
  if result['exit_code'] != 0
    call xolox#misc#msg#debug("easytags.vim %s: Command '%s' returned nonzero exit code %i!", g:xolox#easytags#version, a:name, result['exit_code'])
  else
    " Extract the version number from the output.
    let pattern = 'Exuberant Ctags \zs\(\d\+\(\.\d\+\)*\|Development\)'
    let g:easytags_ctags_version = matchstr(get(result['stdout'], 0, ''), pattern)
    " Deal with development builds.
    if g:easytags_ctags_version == 'Development'
      call xolox#misc#msg#debug("easytags.vim %s: Assuming development build is compatible ..", g:xolox#easytags#version, a:name)
      return 1
    endif
    " Make sure the version is compatible.
    if xolox#misc#version#at_least(a:min_version, g:easytags_ctags_version)
      call xolox#misc#msg#debug("easytags.vim %s: Version is compatible! :-)", g:xolox#easytags#version)
      return 1
    else
      call xolox#misc#msg#debug("easytags.vim %s: Version is not compatible! :-(", g:xolox#easytags#version)
    endif
  endif
  call xolox#misc#msg#debug("easytags.vim %s: Standard output of command: %s", g:xolox#easytags#version, string(result['stdout']))
  call xolox#misc#msg#debug("easytags.vim %s: Standard error of command: %s", g:xolox#easytags#version, string(result['stderr']))
  return 0
endfunction

function! xolox#easytags#register(global) " {{{2
  " Parse the &tags option and get a list of all tags files *including
  " non-existing files* (this is why we can't just call tagfiles()).
  let tagfiles = xolox#misc#option#split_tags(&tags)
  let expanded = map(copy(tagfiles), 'resolve(expand(v:val))')
  " Add the filename to the &tags option when the user hasn't done so already.
  let tagsfile = a:global ? g:easytags_file : xolox#easytags#get_tagsfile()
  if index(expanded, xolox#misc#path#absolute(tagsfile)) == -1
    " This is a real mess because of bugs in Vim?! :let &tags = '...' doesn't
    " work on UNIX and Windows, :set tags=... doesn't work on Windows. What I
    " mean with "doesn't work" is that tagfiles() == [] after the :let/:set
    " command even though the tags file exists! One easy way to confirm that
    " this is a bug in Vim is to type :set tags= then press <Tab> followed by
    " <CR>. Now you entered the exact same value that the code below also did
    " but suddenly Vim sees the tags file and tagfiles() != [] :-S
    call add(tagfiles, tagsfile)
    let value = xolox#misc#option#join_tags(tagfiles)
    let cmd = (a:global ? 'set' : 'setl') . ' tags=' . escape(value, '\ ')
    if xolox#misc#os#is_win() && v:version < 703
      " TODO How to clear the expression from Vim's status line?
      call feedkeys(":" . cmd . "|let &ro=&ro\<CR>", 'n')
    else
      execute cmd
    endif
  endif
endfunction

" Public interface through (automatic) commands. {{{1

function! xolox#easytags#autoload(event) " {{{2
  try
    let session_loading = xolox#easytags#session_is_loading() && a:event == 'BufReadPost'
    let do_update = xolox#misc#option#get('easytags_auto_update', 1) && !session_loading
    let do_highlight = xolox#misc#option#get('easytags_auto_highlight', 1) && &eventignore !~? '\<syntax\>'
    " Don't execute this function for unsupported file types (doesn't load
    " the list of file types if updates and highlighting are both disabled).
    if (do_update || do_highlight) && !empty(xolox#easytags#filetypes#canonicalize(&filetype))
      " Update entries for current file in tags file?
      if do_update
        let buffer_read = (a:event =~? 'BufReadPost')
        let buffer_written = (a:event =~? 'BufWritePost')
        if buffer_written || (buffer_read && xolox#misc#option#get('easytags_always_enabled', 0))
          call xolox#easytags#update(1, 0, [])
        endif
      endif
      " Apply highlighting of tags to current buffer?
      if do_highlight
        if !exists('b:easytags_last_highlighted')
          call xolox#easytags#highlight()
        else
          for tagfile in tagfiles()
            if getftime(tagfile) > b:easytags_last_highlighted
              call xolox#easytags#highlight()
              break
            endif
          endfor
        endif
        let b:easytags_last_highlighted = localtime()
      endif
    endif
  catch
    call xolox#misc#msg#warn("easytags.vim %s: %s (at %s)", g:xolox#easytags#version, v:exception, v:throwpoint)
  endtry
endfunction

function! xolox#easytags#update(silent, filter_tags, filenames) " {{{2
  let async = xolox#misc#option#get('easytags_async', 0)
  try
    let have_args = !empty(a:filenames)
    let starttime = xolox#misc#timer#start()
    let cfile = s:check_cfile(a:silent, a:filter_tags, have_args)
    let tagsfile = xolox#easytags#get_tagsfile()
    let command_line = s:prep_cmdline(cfile, tagsfile, a:filenames)
    if empty(command_line)
      return
    endif
    " Pack all of the information required to update the tags in
    " a Vim dictionary which is easy to serialize to a string.
    let params = {}
    let params['command'] = command_line
    let params['ctags_version'] = g:easytags_ctags_version
    let params['default_filetype'] = xolox#easytags#filetypes#canonicalize(&filetype)
    let params['filter_tags'] = a:filter_tags || async
    let params['have_args'] = have_args
    if !empty(g:easytags_by_filetype)
      let params['directory'] = xolox#misc#path#absolute(g:easytags_by_filetype)
      let params['filetypes'] = g:xolox#easytags#filetypes#ctags_to_vim
    else
      let params['tagsfile'] = tagsfile
    endif
    if async
      call xolox#misc#async#call({'function': 'xolox#easytags#update#with_vim', 'arguments': [params], 'callback': 'xolox#easytags#async_callback'})
    else
      call s:report_results(xolox#easytags#update#with_vim(params), 0)
      " When :UpdateTags was executed manually we'll refresh the dynamic
      " syntax highlighting so that new tags are immediately visible.
      if !a:silent && xolox#misc#option#get('easytags_auto_highlight', 1)
        HighlightTags
      endif
    endif
    return 1
  catch
    call xolox#misc#msg#warn("easytags.vim %s: %s (at %s)", g:xolox#easytags#version, v:exception, v:throwpoint)
  endtry
endfunction

function! s:check_cfile(silent, filter_tags, have_args) " {{{3
  if a:have_args
    return ''
  endif
  let silent = a:silent || a:filter_tags
  if xolox#misc#option#get('easytags_autorecurse', 0)
    let cdir = xolox#easytags#utils#resolve(expand('%:p:h'))
    if !isdirectory(cdir)
      if silent | return '' | endif
      throw "The directory of the current file doesn't exist yet!"
    endif
    return cdir
  endif
  let cfile = xolox#easytags#utils#resolve(expand('%:p'))
  if cfile == '' || !filereadable(cfile)
    if silent | return '' | endif
    throw "You'll need to save your file before using :UpdateTags!"
  elseif g:easytags_ignored_filetypes != '' && &ft =~ g:easytags_ignored_filetypes
    if silent | return '' | endif
    throw "The " . string(&ft) . " file type is explicitly ignored."
  elseif empty(xolox#easytags#filetypes#canonicalize(&ft))
    if silent | return '' | endif
    throw "Exuberant Ctags doesn't support the " . string(&ft) . " file type!"
  endif
  return cfile
endfunction

function! s:prep_cmdline(cfile, tagsfile, arguments) " {{{3
  let vim_file_type = xolox#easytags#filetypes#canonicalize(&filetype)
  let custom_languages = xolox#misc#option#get('easytags_languages', {})
  let language = get(custom_languages, vim_file_type, {})
  if empty(language)
    let program = xolox#misc#option#get('easytags_cmd')
    let cmdline = [program, '--fields=+l', '--c-kinds=+p', '--c++-kinds=+p']
    call add(cmdline, '--sort=no')
    call add(cmdline, '-f-')
    if xolox#misc#option#get('easytags_include_members', 0)
      call add(cmdline, '--extra=+q')
    endif
  else
    let program = get(language, 'cmd', xolox#misc#option#get('easytags_cmd'))
    if empty(program)
      call xolox#misc#msg#warn("easytags.vim %s: No 'cmd' defined for language '%s', and also no global default!", g:xolox#easytags#version, vim_file_type)
      return
    endif
    let cmdline = [program] + get(language, 'args', [])
    call add(cmdline, xolox#misc#escape#shell(get(language, 'stdout_opt', '-f-')))
  endif
  let have_args = 0
  if a:cfile != ''
    if xolox#misc#option#get('easytags_autorecurse', 0)
      call add(cmdline, empty(language) ? '-R' : xolox#misc#escape#shell(get(language, 'recurse_flag', '-R')))
      call add(cmdline, xolox#misc#escape#shell(a:cfile))
    else
      if empty(language)
        " TODO Should --language-force distinguish between C and C++?
        " TODO --language-force doesn't make sense for JavaScript tags in HTML files?
        let filetype = xolox#easytags#filetypes#to_ctags(vim_file_type)
        call add(cmdline, xolox#misc#escape#shell('--language-force=' . filetype))
      endif
      call add(cmdline, xolox#misc#escape#shell(a:cfile))
    endif
    let have_args = 1
  else
    for arg in a:arguments
      if arg =~ '^-'
        call add(cmdline, arg)
        let have_args = 1
      else
        let matches = split(expand(arg), "\n")
        if !empty(matches)
          call map(matches, 'xolox#misc#escape#shell(xolox#easytags#utils#canonicalize(v:val))')
          call extend(cmdline, matches)
          let have_args = 1
        endif
      endif
    endfor
  endif
  " No need to run Exuberant Ctags without any filename arguments!
  return have_args ? join(cmdline) : ''
endfunction

function! xolox#easytags#highlight() " {{{2
  " TODO This is a mess; Re-implement Python version in Vim script, benchmark, remove Python version.
  try
    " Treat C++ and Objective-C as plain C.
    let filetype = xolox#easytags#filetypes#canonicalize(&filetype)
    let tagkinds = get(s:tagkinds, filetype, [])
    if exists('g:syntax_on') && !empty(tagkinds) && !exists('b:easytags_nohl')
      let starttime = xolox#misc#timer#start()
      let used_python = 0
      for tagkind in tagkinds
        let hlgroup_tagged = tagkind.hlgroup . 'Tag'
        " Define style on first run, clear highlighting on later runs.
        if !hlexists(hlgroup_tagged)
          execute 'highlight def link' hlgroup_tagged tagkind.hlgroup
        else
          execute 'syntax clear' hlgroup_tagged
        endif
        " Try to perform the highlighting using the fast Python script.
        " TODO The tags files are read multiple times by the Python script
        "      within one run of xolox#easytags#highlight()
        if s:highlight_with_python(hlgroup_tagged, tagkind)
          let used_python = 1
        else
          " Fall back to the slow and naive Vim script implementation.
          if !exists('taglist')
            " Get the list of tags when we need it and remember the results.
            let ctags_filetypes = xolox#easytags#filetypes#find_ctags_aliases(filetype)
            let filetypes_pattern = printf('^\(%s\)$', join(map(ctags_filetypes, 'xolox#misc#escape#pattern(v:val)'), '\|'))
            let taglist = filter(taglist('.'), "get(v:val, 'language', '') =~? filetypes_pattern")
          endif
          " Filter a copy of the list of tags to the relevant kinds.
          if has_key(tagkind, 'tagkinds')
            let filter = 'v:val.kind =~ tagkind.tagkinds'
          else
            let filter = tagkind.vim_filter
          endif
          let matches = filter(copy(taglist), filter)
          if matches != []
            " Convert matched tags to :syntax commands and execute them.
            let use_keywords_when = xolox#misc#option#get('easytags_syntax_keyword', 'auto')
            let tagkind_has_patterns = !(empty(tagkind.pattern_prefix) && empty(tagkind.pattern_suffix))
            if use_keywords_when == 'always' || (use_keywords_when == 'auto' && !tagkind_has_patterns)
              " Vim's ":syntax keyword" command doesn't use the regular
              " expression engine and the resulting syntax highlighting is
              " therefor much faster. Because of this we use the syntax
              " keyword command when 1) we can do so without sacrificing
              " accuracy or 2) the user explicitly chose to sacrifice
              " accuracy in order to make the highlighting faster.
              let keywords = []
              for tag in matches
                if s:is_keyword_compatible(tag)
                  call add(keywords, tag.name)
                endif
              endfor
              if !empty(keywords)
                let template = 'syntax keyword %s %s containedin=ALLBUT,%s'
                let command = printf(template, hlgroup_tagged, join(keywords), xolox#easytags#syntax_groups_to_ignore())
                call xolox#misc#msg#debug("easytags.vim %s: Executing command '%s'.", g:xolox#easytags#version, command)
                execute command
                " Remove the tags that we just highlighted from the list of
                " tags that still need to be highlighted.
                call filter(matches, "!s:is_keyword_compatible(v:val)")
              endif
            endif
            if !empty(matches)
              let matches = xolox#misc#list#unique(map(matches, 'xolox#misc#escape#pattern(get(v:val, "name"))'))
              let pattern = tagkind.pattern_prefix . '\%(' . join(matches, '\|') . '\)' . tagkind.pattern_suffix
              let template = 'syntax match %s /%s/ containedin=ALLBUT,%s'
              let command = printf(template, hlgroup_tagged, escape(pattern, '/'), xolox#easytags#syntax_groups_to_ignore())
              call xolox#misc#msg#debug("easytags.vim %s: Executing command '%s'.", g:xolox#easytags#version, command)
              try
                execute command
              catch /^Vim\%((\a\+)\)\=:E339/
                let msg = "easytags.vim %s: Failed to highlight %i %s tags because pattern is too big! (%i KB)"
                call xolox#misc#msg#warn(msg, g:xolox#easytags#version, len(matches), tagkind.hlgroup, len(pattern) / 1024)
              endtry
            endif
          endif
        endif
      endfor
      " Avoid flashing each highlighted buffer in front of the user when
      " loading a session.
      if !xolox#easytags#session_is_loading()
        redraw
      endif
      let bufname = expand('%:p:~')
      if bufname == ''
        let bufname = 'unnamed buffer #' . bufnr('%')
      endif
      let msg = "easytags.vim %s: Highlighted tags in %s in %s%s."
      call xolox#misc#timer#stop(msg, g:xolox#easytags#version, bufname, starttime, used_python ? " (using Python)" : "")
      return 1
    endif
  catch
    call xolox#misc#msg#warn("easytags.vim %s: %s (at %s)", g:xolox#easytags#version, v:exception, v:throwpoint)
  endtry
endfunction

function! s:is_keyword_compatible(tag)
  let name = get(a:tag, 'name', '')
  if !empty(name)
    return name =~ '^\k\+$' && len(name) <= 80
  endif
endfunction

" Public supporting functions (might be useful to others). {{{1

function! xolox#easytags#get_tagsfile() " {{{2
  let tagsfile = ''
  " Look for a suitable project specific tags file?
  let dynamic_files = xolox#misc#option#get('easytags_dynamic_files', 0)
  if dynamic_files == 1
    let tagsfile = get(tagfiles(), 0, '')
  elseif dynamic_files == 2
    let tagsfile = xolox#misc#option#eval_tags(&tags, 1)
    let directory = fnamemodify(tagsfile, ':h')
    if filewritable(directory) != 2
      " If the directory of the dynamic tags file is not writable, we fall
      " back to a file type specific tags file or the global tags file.
      call xolox#misc#msg#warn("easytags.vim %s: Dynamic tags files enabled but %s not writable so falling back.", g:xolox#easytags#version, directory)
      let tagsfile = ''
    endif
  endif
  " Check if a file type specific tags file is useful?
  let vim_file_type = xolox#easytags#filetypes#canonicalize(&filetype)
  if empty(tagsfile) && !empty(g:easytags_by_filetype) && !empty(vim_file_type)
    let directory = xolox#misc#path#absolute(g:easytags_by_filetype)
    let tagsfile = xolox#misc#path#merge(directory, vim_file_type)
  endif
  " Default to the global tags file?
  if empty(tagsfile)
    let tagsfile = expand(xolox#misc#option#get('easytags_file'))
  endif
  " If the tags file exists, make sure it is writable!
  if filereadable(tagsfile) && filewritable(tagsfile) != 1
    let message = "The tags file %s isn't writable!"
    throw printf(message, fnamemodify(tagsfile, ':~'))
  endif
  return xolox#misc#path#absolute(tagsfile)
endfunction

function! xolox#easytags#syntax_groups_to_ignore() " {{{2
  " Get a string matching the syntax groups where dynamic highlighting should
  " *not* apply. This is complicated by the fact that Vim has a tendency to do
  " this:
  "
  "     Vim(syntax):E409: Unknown group name: doxygen.*
  "
  " This happens when a group wildcard doesn't match *anything*. Why does Vim
  " always have to make everything so complicated? :-(
  let groups = ['.*String.*', '.*Comment.*']
  for group_name in ['cIncluded', 'cCppOut2', 'cCppInElse2', 'cCppOutIf2', 'pythonDocTest', 'pythonDocTest2']
    if hlexists(group_name)
      call add(groups, group_name)
    endif
  endfor
  " Doxygen is an "add-on syntax script", it's usually used in combination:
  "   :set syntax=c.doxygen
  " It gets special treatment because it defines a dozen or so groups :-)
  if hlexists('doxygenComment')
    call add(groups, 'doxygen.*')
  endif
  return join(groups, ',')
endfunction

function! xolox#easytags#async_callback(response) " {{{2
  if has_key(a:response, 'result')
    call s:report_results(a:response['result'], 1)
  else
    call xolox#misc#msg#warn("easytags.vim %s: Asynchronous tags file update failed! (%s at %s)", g:xolox#easytags#version, a:response['exception'], a:response['throwpoint'])
  endif
endfunction

function! xolox#easytags#session_is_loading() " {{{2
  return exists('g:SessionLoad')
endfunction

function! xolox#easytags#disable_automatic_updates() " {{{2
  let s:easytags_auto_update_save = xolox#misc#option#get('easytags_auto_update', 1)
  let g:easytags_auto_update = 0
endfunction

function! xolox#easytags#restore_automatic_updates() " {{{2
  if exists('s:easytags_auto_update_save')
    let g:easytags_auto_update = s:easytags_auto_update_save
    unlet s:easytags_auto_update_save
  endif
endfunction

" Public API for definition of file type specific dynamic syntax highlighting. {{{1

function! xolox#easytags#define_tagkind(object) " {{{2
  if !has_key(a:object, 'pattern_prefix')
    let a:object.pattern_prefix = ''
  endif
  if !has_key(a:object, 'pattern_suffix')
    let a:object.pattern_suffix = ''
  endif
  if !has_key(s:tagkinds, a:object.filetype)
    let s:tagkinds[a:object.filetype] = []
  endif
  call add(s:tagkinds[a:object.filetype], a:object)
endfunction

" Miscellaneous script-local functions. {{{1

function! s:report_results(response, async) " {{{2
  let actions = []
  if a:response['num_updated'] > 0
    call add(actions, printf('updated %i tags', a:response['num_updated']))
  endif
  if a:response['num_filtered'] > 0
    call add(actions, printf('filtered %i invalid tags', a:response['num_filtered']))
  endif
  if !empty(actions)
    let function = a:async ? 'xolox#misc#msg#debug' : 'xolox#misc#msg#info'
    let actions_string = xolox#misc#str#ucfirst(join(actions, ' and '))
    let command_type = a:async ? 'asynchronously' : 'synchronously'
    call call(function, ["easytags.vim %s: %s in %s (%s).", g:xolox#easytags#version, actions_string, a:response['elapsed_time'], command_type])
  endif
endfunction

function! s:python_available() " {{{2
  if !exists('s:is_python_available')
    try
      execute 'pyfile' fnameescape(g:easytags_python_script)
      redir => output
        silent python easytags_ping()
      redir END
      let s:is_python_available = (output =~ 'it works!')
    catch
      let s:is_python_available = 0
    endtry
  endif
  return s:is_python_available
endfunction

function! s:highlight_with_python(syntax_group, tagkind) " {{{2
  if xolox#misc#option#get('easytags_python_enabled', 1) && s:python_available()
    " Gather arguments for Python function.
    let context = {}
    let context['tagsfiles'] = tagfiles()
    let context['syntaxgroup'] = a:syntax_group
    " TODO This doesn't support file type groups!
    let context['filetype'] = xolox#easytags#filetypes#to_ctags(xolox#easytags#filetypes#canonicalize(&filetype))
    let context['tagkinds'] = get(a:tagkind, 'tagkinds', '')
    let context['prefix'] = get(a:tagkind, 'pattern_prefix', '')
    let context['suffix'] = get(a:tagkind, 'pattern_suffix', '')
    let context['filters'] = get(a:tagkind, 'python_filter', {})
    let context['ignoresyntax'] = xolox#easytags#syntax_groups_to_ignore()
    " Call the Python function and intercept the output.
    try
      redir => commands
      python import vim
      silent python print easytags_gensyncmd(**vim.eval('context'))
      redir END
      execute commands
      return 1
    catch
      redir END
      " If the Python script raised an error, don't run it again.
      let g:easytags_python_enabled = 0
    endtry
  endif
  return 0
endfunction

" Built-in file type & tag kind definitions. {{{1

" Don't bother redefining everything below when this script is sourced again.
if exists('s:tagkinds')
  finish
endif

let s:tagkinds = {}

" Enable line continuation.
let s:cpo_save = &cpo
set cpo&vim

" Lua. {{{2

call xolox#easytags#define_tagkind({
      \ 'filetype': 'lua',
      \ 'hlgroup': 'luaFunc',
      \ 'tagkinds': 'f'})

" C. {{{2

call xolox#easytags#define_tagkind({
      \ 'filetype': 'c',
      \ 'hlgroup': 'cType',
      \ 'tagkinds': '[cgstu]'})

call xolox#easytags#define_tagkind({
      \ 'filetype': 'c',
      \ 'hlgroup': 'cEnum',
      \ 'tagkinds': 'e'})

call xolox#easytags#define_tagkind({
      \ 'filetype': 'c',
      \ 'hlgroup': 'cPreProc',
      \ 'tagkinds': 'd'})

call xolox#easytags#define_tagkind({
      \ 'filetype': 'c',
      \ 'hlgroup': 'cFunction',
      \ 'tagkinds': '[fp]'})

highlight def link cEnum Identifier
highlight def link cFunction Function

if xolox#misc#option#get('easytags_include_members', 0)
  call xolox#easytags#define_tagkind({
        \ 'filetype': 'c',
        \ 'hlgroup': 'cMember',
        \ 'tagkinds': 'm'})
 highlight def link cMember Identifier
endif

" PHP. {{{2

call xolox#easytags#define_tagkind({
      \ 'filetype': 'php',
      \ 'hlgroup': 'phpFunctions',
      \ 'tagkinds': 'f',
      \ 'pattern_suffix': '(\@='})

call xolox#easytags#define_tagkind({
      \ 'filetype': 'php',
      \ 'hlgroup': 'phpClasses',
      \ 'tagkinds': 'c'})

" Vim script. {{{2

call xolox#easytags#define_tagkind({
      \ 'filetype': 'vim',
      \ 'hlgroup': 'vimAutoGroup',
      \ 'tagkinds': 'a'})

highlight def link vimAutoGroup vimAutoEvent

call xolox#easytags#define_tagkind({
      \ 'filetype': 'vim',
      \ 'hlgroup': 'vimCommand',
      \ 'tagkinds': 'c',
      \ 'pattern_prefix': '\(\(^\|\s\):\?\)\@<=',
      \ 'pattern_suffix': '\(!\?\(\s\|$\)\)\@='})

" Exuberant Ctags doesn't mark script local functions in Vim scripts as
" "static". When your tags file contains search patterns this plug-in can use
" those search patterns to check which Vim script functions are defined
" globally and which script local.

call xolox#easytags#define_tagkind({
      \ 'filetype': 'vim',
      \ 'hlgroup': 'vimFuncName',
      \ 'vim_filter': 'v:val.kind ==# "f" && get(v:val, "cmd", "") !~? ''<sid>\w\|\<s:\w''',
      \ 'python_filter': { 'kind': 'f', 'nomatch': '(?i)(<sid>\w|\bs:\w)' },
      \ 'pattern_prefix': '\C\%(\<s:\|<[sS][iI][dD]>\)\@<!\<'})

call xolox#easytags#define_tagkind({
      \ 'filetype': 'vim',
      \ 'hlgroup': 'vimScriptFuncName',
      \ 'vim_filter': 'v:val.kind ==# "f" && get(v:val, "cmd", "") =~? ''<sid>\w\|\<s:\w''',
      \ 'python_filter': { 'kind': 'f', 'match': '(?i)(<sid>\w|\bs:\w)' },
      \ 'pattern_prefix': '\C\%(\<s:\|<[sS][iI][dD]>\)'})

highlight def link vimScriptFuncName vimFuncName

" Python. {{{2

call xolox#easytags#define_tagkind({
      \ 'filetype': 'python',
      \ 'hlgroup': 'pythonFunction',
      \ 'tagkinds': 'f',
      \ 'pattern_prefix': '\%(\<def\s\+\)\@<!\<'})

call xolox#easytags#define_tagkind({
      \ 'filetype': 'python',
      \ 'hlgroup': 'pythonMethod',
      \ 'tagkinds': 'm',
      \ 'pattern_prefix': '\.\@<='})

call xolox#easytags#define_tagkind({
      \ 'filetype': 'python',
      \ 'hlgroup': 'pythonClass',
      \ 'tagkinds': 'c'})

highlight def link pythonMethodTag pythonFunction
highlight def link pythonClassTag pythonFunction

" Java. {{{2

call xolox#easytags#define_tagkind({
      \ 'filetype': 'java',
      \ 'hlgroup': 'javaClass',
      \ 'tagkinds': 'c'})

call xolox#easytags#define_tagkind({
      \ 'filetype': 'java',
      \ 'hlgroup': 'javaInterface',
      \ 'tagkinds': 'i'})

call xolox#easytags#define_tagkind({
      \ 'filetype': 'java',
      \ 'hlgroup': 'javaMethod',
      \ 'tagkinds': 'm'})

highlight def link javaClass Identifier
highlight def link javaMethod Function
highlight def link javaInterface Identifier

" C#. {{{2

" TODO C# name spaces, interface names, enumeration member names, structure names?

call xolox#easytags#define_tagkind({
      \ 'filetype': 'cs',
      \ 'hlgroup': 'csClassOrStruct',
      \ 'tagkinds': 'c'})

call xolox#easytags#define_tagkind({
      \ 'filetype': 'cs',
      \ 'hlgroup': 'csMethod',
      \ 'tagkinds': '[ms]'})

highlight def link csClassOrStruct Identifier
highlight def link csMethod Function

" Ruby. {{{2

call xolox#easytags#define_tagkind({
      \ 'filetype': 'ruby',
      \ 'hlgroup': 'rubyModuleName',
      \ 'tagkinds': 'm'})

call xolox#easytags#define_tagkind({
      \ 'filetype': 'ruby',
      \ 'hlgroup': 'rubyClassName',
      \ 'tagkinds': 'c'})

call xolox#easytags#define_tagkind({
      \ 'filetype': 'ruby',
      \ 'hlgroup': 'rubyMethodName',
      \ 'tagkinds': '[fF]'})

highlight def link rubyModuleName Type
highlight def link rubyClassName Type
highlight def link rubyMethodName Function

" Awk. {{{2

call xolox#easytags#define_tagkind({
      \ 'filetype': 'awk',
      \ 'hlgroup': 'awkFunctionTag',
      \ 'tagkinds': 'f'})

highlight def link awkFunctionTag Function

" Shell. {{{2

call xolox#easytags#define_tagkind({
      \ 'filetype': 'sh',
      \ 'hlgroup': 'shFunctionTag',
      \ 'tagkinds': 'f',
      \ 'pattern_suffix': '\(\w\|\s*()\)\@!'})

highlight def link shFunctionTag Operator

" Tcl. {{{2

call xolox#easytags#define_tagkind({
      \ 'filetype': 'tcl',
      \ 'hlgroup': 'tclCommandTag',
      \ 'tagkinds': 'p'})

highlight def link tclCommandTag Operator

" }}}

" Restore "cpoptions".
let &cpo = s:cpo_save
unlet s:cpo_save

" vim: ts=2 sw=2 et
