" Vim script
" Maintainer: Peter Odding <peter@peterodding.com>
" Last Change: June 9, 2010
" URL: http://peterodding.com/code/vim/easytags

function! easytags#autoload() " {{{1
  try
    " Update the entries for the current file in the global tags file?
    let start = xolox#timer#start()
    if getftime(expand('%')) > getftime(easytags#get_tagsfile())
      UpdateTags
      call xolox#timer#stop(start, "easytags.vim: Automatically updated tags in %s second(s)")
    endif
    " Apply highlighting of tags in global tags file to current buffer?
    if &eventignore !~? '\<syntax\>'
      let start = xolox#timer#start()
      if !exists('b:easytags_last_highlighted')
        HighlightTags
      else
        for tagfile in tagfiles()
          if getftime(tagfile) > b:easytags_last_highlighted
            HighlightTags
            break
          endif
        endfor
      endif
      let b:easytags_last_highlighted = localtime()
      call xolox#timer#stop(start, "easytags.vim: Automatically highlighted tags in %s second(s)")
    endif
  catch
    call xolox#warning("easytags.vim: %s (at %s)", v:exception, v:throwpoint)
  endtry
endfunction

function! easytags#update_cmd(filter_invalid_tags) " {{{1
  try
    let ft_supported = index(easytags#supported_filetypes(), &ft) >= 0
    let ft_ignored = g:easytags_ignored_filetypes != '' && &ft =~ g:easytags_ignored_filetypes
    if (ft_supported && !ft_ignored) || a:filter_invalid_tags
      let start = xolox#timer#start()
      let tagsfile = easytags#get_tagsfile()
      let filename = expand('%:p')
      if g:easytags_resolve_links
        let filename = resolve(filename)
      endif
      let command = [g:easytags_cmd, '-f', shellescape(tagsfile)]
      if filereadable(tagsfile)
        call add(command, '-a')
        let start_filter = xolox#timer#start()
        let lines = readfile(tagsfile)
        let filters = []
        if ft_supported && !ft_ignored
          let filename_pattern = '\s' . xolox#escape#pattern(filename) . '\s'
          call add(filters, 'v:val !~ filename_pattern')
        endif
        if a:filter_invalid_tags
          call add(filters, 'filereadable(get(split(v:val, "\t"), 1))')
        endif
        let filter = 'v:val =~ "^!_TAG_" || (' . join(filters, ' && ') . ')'
        let filtered = filter(copy(lines), filter)
        if lines != filtered
          if writefile(filtered, tagsfile) != 0
            throw "Failed to write filtered tags file!"
          endif
        endif
        call xolox#timer#stop(start_filter, "easytags.vim: Filtered tags file in %s second(s)")
      endif
      if ft_supported && !ft_ignored
        call add(command, '--language-force=' . easytags#to_ctags_ft(&ft))
        call add(command, shellescape(filename))
        let listing = system(join(command))
        if v:shell_error
          throw "Failed to update tags file! (Ctags output: `" . listing . "')"
        endif
      endif
      call xolox#timer#stop(start, "easytags.vim: Updated tags in %s second(s)")
      return 1
    endif
    return 0
  catch
    call xolox#warning("easytags.vim: %s (at %s)", v:exception, v:throwpoint)
  endtry
endfunction

function! easytags#supported_filetypes() " {{{1
  if !exists('s:supported_filetypes')
    let start = xolox#timer#start()
    let listing = system(g:easytags_cmd . ' --list-languages')
    if v:shell_error
      throw "Failed to get Exuberant Ctags language mappings!"
    endif
    let s:supported_filetypes = split(listing, '\n')
    call map(s:supported_filetypes, 'easytags#to_vim_ft(v:val)')
    call xolox#timer#stop(start, "easytags.vim: Parsed language mappings in %s second(s)")
  endif
  return s:supported_filetypes
endfunction

function! easytags#highlight_cmd() " {{{1
  try
    if exists('g:syntax_on') && has_key(s:tagkinds, &ft)
      let start = xolox#timer#start()
      if !has_key(s:aliases, &ft)
        let taglist = filter(taglist('.'), "get(v:val, 'language', '') ==? &ft")
      else
        let aliases = s:aliases[&ft]
        let taglist = filter(taglist('.'), "has_key(aliases, tolower(get(v:val, 'language', '')))")
      endif
      for tagkind in s:tagkinds[&ft]
        let hlgroup_tagged = tagkind.hlgroup . 'Tag'
        if hlexists(hlgroup_tagged)
          execute 'syntax clear' hlgroup_tagged
        else
          execute 'highlight def link' hlgroup_tagged tagkind.hlgroup
        endif
        let matches = filter(copy(taglist), tagkind.filter)
        call map(matches, 'xolox#escape#pattern(get(v:val, "name"))')
        let pattern = tagkind.pattern_prefix . '\%(' . join(xolox#unique(matches), '\|') . '\)' . tagkind.pattern_suffix
        let command = 'syntax match %s /%s/ containedin=ALLBUT,.*String.*,.*Comment.*'
        execute printf(command, hlgroup_tagged, escape(pattern, '/'))
      endfor
      redraw
      call xolox#timer#stop(start, "easytags.vim: Highlighted tags in %s second(s)")
    endif
  catch
    call xolox#warning("easytags.vim: %s (at %s)", v:exception, v:throwpoint)
  endtry
endfunction

function! easytags#get_tagsfile() " {{{1
  let tagsfile = expand(g:easytags_file)
  if filereadable(tagsfile) && filewritable(tagsfile) != 1
    let message = "The tags file isn't writable! (%s)"
    throw printf(message, tagsfile)
  endif
  return tagsfile
endfunction

function! easytags#define_tagkind(object) " {{{1
  if !has_key(a:object, 'pattern_prefix')
    let a:object.pattern_prefix = '\C\<'
  endif
  if !has_key(a:object, 'pattern_suffix')
    let a:object.pattern_suffix = '\>'
  endif
  if !has_key(s:tagkinds, a:object.filetype)
    let s:tagkinds[a:object.filetype] = []
  endif
  call add(s:tagkinds[a:object.filetype], a:object)
endfunction

function! easytags#map_filetypes(vim_ft, ctags_ft) " {{{1
  call add(s:vim_filetypes, a:vim_ft)
  call add(s:ctags_filetypes, a:ctags_ft)
endfunction

function! easytags#alias_filetypes(...) " {{{1
  for type in a:000
    if !has_key(s:aliases, type)
      let s:aliases[type] = {}
    endif
  endfor
  for i in range(a:0)
    for j in range(a:0)
      let vimft1 = a:000[i]
      let ctagsft1 = easytags#to_ctags_ft(vimft1)
      let vimft2 = a:000[j]
      let ctagsft2 = easytags#to_ctags_ft(vimft2)
      if !has_key(s:aliases[vimft1], ctagsft2)
        let s:aliases[vimft1][ctagsft2] = 1
      endif
      if !has_key(s:aliases[vimft2], ctagsft1)
        let s:aliases[vimft2][ctagsft1] = 1
      endif
    endfor
  endfor
endfunction

function! easytags#to_vim_ft(ctags_ft) " {{{1
  let type = tolower(a:ctags_ft)
  let index = index(s:ctags_filetypes, type)
  return index >= 0 ? s:vim_filetypes[index] : type
endfunction

function! easytags#to_ctags_ft(vim_ft) " {{{1
  let type = tolower(a:vim_ft)
  let index = index(s:vim_filetypes, type)
  return index >= 0 ? s:ctags_filetypes[index] : type
endfunction

" Built-in file type & tag kind definitions. {{{1

if !exists('s:tagkinds')

  let s:vim_filetypes = []
  let s:ctags_filetypes = []
  call easytags#map_filetypes('cpp', 'c++')
  call easytags#map_filetypes('cs', 'c#')
  call easytags#map_filetypes(exists('filetype_asp') ? filetype_asp : 'aspvbs', 'asp')

  let s:aliases = {}
  call easytags#alias_filetypes('c', 'cpp', 'objc', 'objcpp')

  let s:tagkinds = {}

  " Enable line continuation.
  let s:cpo_save = &cpo
  set cpo&vim

  " Lua. {{{2

  call easytags#define_tagkind({
        \ 'filetype': 'lua',
        \ 'hlgroup': 'luaFunc',
        \ 'filter': 'get(v:val, "kind") ==# "f"'})

  " C. {{{2

  call easytags#define_tagkind({
        \ 'filetype': 'c',
        \ 'hlgroup': 'cType',
        \ 'filter': 'get(v:val, "kind") =~# "[cgstu]"'})

  call easytags#define_tagkind({
        \ 'filetype': 'c',
        \ 'hlgroup': 'cPreProc',
        \ 'filter': 'get(v:val, "kind") ==# "d"'})

  call easytags#define_tagkind({
        \ 'filetype': 'c',
        \ 'hlgroup': 'cFunction',
        \ 'filter': 'get(v:val, "kind") =~# "[fp]"'})

  highlight def link cFunction Function

  " PHP. {{{2

  call easytags#define_tagkind({
        \ 'filetype': 'php',
        \ 'hlgroup': 'phpFunctions',
        \ 'filter': 'get(v:val, "kind") ==# "f"'})

  call easytags#define_tagkind({
        \ 'filetype': 'php',
        \ 'hlgroup': 'phpClasses',
        \ 'filter': 'get(v:val, "kind") ==# "c"'})

  " Vim script. {{{2

  call easytags#define_tagkind({
        \ 'filetype': 'vim',
        \ 'hlgroup': 'vimAutoGroup',
        \ 'filter': 'get(v:val, "kind") ==# "a"'})

  highlight def link vimAutoGroup vimAutoEvent

  call easytags#define_tagkind({
        \ 'filetype': 'vim',
        \ 'hlgroup': 'vimCommand',
        \ 'filter': 'get(v:val, "kind") ==# "c"',
        \ 'pattern_prefix': '\(\(^\|\s\):\?\)\@<=',
        \ 'pattern_suffix': '\(!\?\(\s\|$\)\)\@='})

  " Exuberant Ctags doesn't mark script local functions in Vim scripts as
  " "static". When your tags file contains search patterns this plug-in can use
  " those search patterns to check which Vim script functions are defined
  " globally and which script local.

  call easytags#define_tagkind({
        \ 'filetype': 'vim',
        \ 'hlgroup': 'vimFuncName',
        \ 'filter': 'get(v:val, "kind") ==# "f" && get(v:val, "cmd") !~? ''<sid>\w\|\<s:\w''',
        \ 'pattern_prefix': '\C\%(\<s:\|<[sS][iI][dD]>\)\@<!\<'})

  call easytags#define_tagkind({
        \ 'filetype': 'vim',
        \ 'hlgroup': 'vimScriptFuncName',
        \ 'filter': 'get(v:val, "kind") ==# "f" && get(v:val, "cmd") =~? ''<sid>\w\|\<s:\w''',
        \ 'pattern_prefix': '\C\%(\<s:\|<[sS][iI][dD]>\)'})

  highlight def link vimScriptFuncName vimFuncName

  " Python. {{{2

  call easytags#define_tagkind({
        \ 'filetype': 'python',
        \ 'hlgroup': 'pythonFunction',
        \ 'filter': 'get(v:val, "kind") ==# "f"',
        \ 'pattern_prefix': '\%(\<def\s\+\)\@<!\<'})

  call easytags#define_tagkind({
        \ 'filetype': 'python',
        \ 'hlgroup': 'pythonMethod',
        \ 'filter': 'get(v:val, "kind") ==# "m"',
        \ 'pattern_prefix': '\.\@<='})

  highlight def link pythonMethodTag pythonFunction

  " Restore "cpoptions".
  let &cpo = s:cpo_save
  unlet s:cpo_save

endif

" vim: ts=2 sw=2 et
