" Vim script
" Maintainer: Peter Odding <peter@peterodding.com>
" Last Change: June 15, 2010
" URL: http://peterodding.com/code/vim/easytags

let s:script = expand('<sfile>:p:~')

" Public interface through (automatic) commands. {{{1

function! easytags#autoload() " {{{2
  try
    " Update the entries for the current file in the global tags file?
    let pathname = s:resolve(expand('%:p'))
    let tags_outdated = getftime(pathname) > getftime(easytags#get_tagsfile())
    if tags_outdated || !easytags#file_has_tags(pathname)
      UpdateTags
    endif
    " Apply highlighting of tags in global tags file to current buffer?
    if &eventignore !~? '\<syntax\>'
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
    endif
  catch
    call xolox#warning("%s: %s (at %s)", s:script, v:exception, v:throwpoint)
  endtry
endfunction

function! easytags#update_cmd(filter_invalid_tags) " {{{2
  try
    let filename = s:resolve(expand('%:p'))
    let ft_supported = index(easytags#supported_filetypes(), &ft) >= 0
    let ft_ignored = g:easytags_ignored_filetypes != '' && &ft =~ g:easytags_ignored_filetypes
    if (ft_supported && !ft_ignored) || a:filter_invalid_tags
      let start = xolox#timer#start()
      let tagsfile = easytags#get_tagsfile()
      let command = [g:easytags_cmd, '-f', shellescape(tagsfile), '--fields=+l']
      if filereadable(tagsfile)
        call add(command, '-a')
        let filter_file_tags = easytags#file_has_tags(filename)
        if a:filter_invalid_tags || filter_file_tags
          let [header, entries] = easytags#read_tagsfile(tagsfile)
          let num_entries = len(entries)
          call s:set_tagged_files(entries)
          let filters = []
          if ft_supported && !ft_ignored && filter_file_tags
            let filename_pattern = '\t' . xolox#escape#pattern(filename) . '\t'
            call add(filters, 'v:val !~ filename_pattern')
          endif
          if a:filter_invalid_tags
            call add(filters, 'filereadable(get(split(v:val, "\t"), 1))')
          endif
          call filter(entries, join(filters, ' && '))
          if len(entries) != num_entries
            if !easytags#write_tagsfile(tagsfile, header, entries)
              let msg = "Failed to write filtered tags file %s!"
              throw printf(msg, fnamemodify(tagsfile, ':~'))
            endif
          endif
        endif
      endif
      if ft_supported && !ft_ignored
        call add(command, '--language-force=' . easytags#to_ctags_ft(&ft))
        call add(command, shellescape(filename))
        let listing = system(join(command))
        if v:shell_error
          let msg = "Failed to update tags file %s: %s!"
          throw printf(msg, fnamemodify(tagsfile, ':~'), strtrans(v:exception))
        endif
        call easytags#add_tagged_file(filename)
      endif
      let msg = "%s: Updated tags for %s in %s."
      call xolox#timer#stop(msg, s:script, expand('%:p:~'), start)
      return 1
    endif
    return 0
  catch
    call xolox#warning("%s: %s (at %s)", s:script, v:exception, v:throwpoint)
  endtry
endfunction

function! easytags#highlight_cmd() " {{{2
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
        if matches != []
          call map(matches, 'xolox#escape#pattern(get(v:val, "name"))')
          let pattern = tagkind.pattern_prefix . '\%(' . join(xolox#unique(matches), '\|') . '\)' . tagkind.pattern_suffix
          let command = 'syntax match %s /%s/ containedin=ALLBUT,.*String.*,.*Comment.*'
          execute printf(command, hlgroup_tagged, escape(pattern, '/'))
        endif
      endfor
      redraw
      let msg = "%s: Highlighted tags in %s in %s."
      call xolox#timer#stop(msg, s:script, expand('%:p:~'), start)
    endif
  catch
    call xolox#warning("%s: %s (at %s)", s:script, v:exception, v:throwpoint)
  endtry
endfunction

" Public supporting functions (might be useful to others). {{{1

function! easytags#supported_filetypes() " {{{2
  if !exists('s:supported_filetypes')
    let start = xolox#timer#start()
    let listing = system(g:easytags_cmd . ' --list-languages')
    if v:shell_error
      let msg = "Failed to get supported languages! (output: %s)"
      throw printf(msg, strtrans(listing))
    endif
    let s:supported_filetypes = split(listing, '\n')
    call map(s:supported_filetypes, 'easytags#to_vim_ft(v:val)')
    let msg = "%s: Retrieved supported languages in %s."
    call xolox#timer#stop(msg, s:script, start)
  endif
  return s:supported_filetypes
endfunction

function! easytags#read_tagsfile(tagsfile) " {{{2
  let lines = readfile(a:tagsfile)
  let header = []
  while lines != [] && lines[0] =~# '^!_TAG_'
    call insert(header, remove(lines, 0))
  endwhile
  while lines != [] && lines[-1] == ''
    call remove(lines, -1)
  endwhile
  return [header, lines]
endfunction

function! easytags#write_tagsfile(tagsfile, header, entries) " {{{2
  let lines = []
  if has('win32') || has('win64')
    for line in a:header
      call add(lines, line . "\r")
    endfor
    for entry in a:entries
      call add(lines, entry . "\r")
    endfor
  else
    call extend(lines, a:header)
    call extend(lines, a:entries)
  endif
  return writefile(lines, a:tagsfile) == 0
endfunction

function! easytags#file_has_tags(filename) " {{{2
  call s:cache_tagged_files()
  return has_key(s:tagged_files, s:resolve(a:filename))
endfunction

function! easytags#add_tagged_file(filename) " {{{2
  call s:cache_tagged_files()
  let filename = s:resolve(a:filename)
  let s:tagged_files[filename] = 1
endfunction

function! easytags#get_tagsfile() " {{{2
  let tagsfile = expand(g:easytags_file)
  if filereadable(tagsfile) && filewritable(tagsfile) != 1
    let message = "The tags file %s isn't writable!"
    throw printf(message, fnamemodify(tagsfile, ':~'))
  endif
  return tagsfile
endfunction

" Public API for file-type specific dynamic syntax highlighting. {{{1

function! easytags#define_tagkind(object) " {{{2
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

function! easytags#map_filetypes(vim_ft, ctags_ft) " {{{2
  call add(s:vim_filetypes, a:vim_ft)
  call add(s:ctags_filetypes, a:ctags_ft)
endfunction

function! easytags#alias_filetypes(...) " {{{2
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

function! easytags#to_vim_ft(ctags_ft) " {{{2
  let type = tolower(a:ctags_ft)
  let index = index(s:ctags_filetypes, type)
  return index >= 0 ? s:vim_filetypes[index] : type
endfunction

function! easytags#to_ctags_ft(vim_ft) " {{{2
  let type = tolower(a:vim_ft)
  let index = index(s:vim_filetypes, type)
  return index >= 0 ? s:ctags_filetypes[index] : type
endfunction

" Miscellaneous script-local functions. {{{1

function! s:resolve(filename) " {{{2
  if g:easytags_resolve_links
    return resolve(a:filename)
  else
    return a:filename
  endif
endfunction

function! s:cache_tagged_files() " {{{2
  if !exists('s:tagged_files')
    let tagsfile = easytags#get_tagsfile()
    try
      let [header, entries] = easytags#read_tagsfile(tagsfile)
      call s:set_tagged_files(entries)
    catch /\<E484\>/
      " Ignore missing tags file.
      call s:set_tagged_files([])
    endtry
  endif
endfunction

function! s:set_tagged_files(entries) " {{{2
  let s:tagged_files = {}
  for entry in a:entries
    let filename = matchstr(entry, '^[^\t]\+\t\zs[^\t]\+')
    if filename != ''
      let filename = s:resolve(filename)
      let s:tagged_files[filename] = 1
    endif
  endfor
endfunction

" Built-in file type & tag kind definitions. {{{1

" Don't bother redefining everything below when this script is sourced again.
if exists('s:tagkinds')
  finish
endif

let s:tagkinds = {}

" Define the built-in Vim <=> Ctags file-type mappings.
let s:vim_filetypes = []
let s:ctags_filetypes = []
call easytags#map_filetypes('cpp', 'c++')
call easytags#map_filetypes('cs', 'c#')
call easytags#map_filetypes(exists('filetype_asp') ? filetype_asp : 'aspvbs', 'asp')

" Define the Vim file-types that are aliased by default.
let s:aliases = {}
call easytags#alias_filetypes('c', 'cpp', 'objc', 'objcpp')

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

" Java. {{{2

call easytags#define_tagkind({
      \ 'filetype': 'java',
      \ 'hlgroup': 'javaClass',
      \ 'filter': 'get(v:val, "kind") ==# "c"'})

call easytags#define_tagkind({
      \ 'filetype': 'java',
      \ 'hlgroup': 'javaMethod',
      \ 'filter': 'get(v:val, "kind") ==# "m"'})

highlight def link javaClass Identifier
highlight def link javaMethod Function

" }}}

" Restore "cpoptions".
let &cpo = s:cpo_save
unlet s:cpo_save

" vim: ts=2 sw=2 et
