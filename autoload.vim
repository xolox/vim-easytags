" Vim script
" Author: Peter Odding <peter@peterodding.com>
" Last Change: September 6, 2010
" URL: http://peterodding.com/code/vim/easytags/

let s:script = expand('<sfile>:p:~')

" Public interface through (automatic) commands. {{{1

function! easytags#autoload() " {{{2
  try
    " Update the entries for the current file in the global tags file?
    let pathname = s:resolve(expand('%:p'))
    if pathname != ''
      let tags_outdated = getftime(pathname) > getftime(easytags#get_tagsfile())
      if tags_outdated || !easytags#file_has_tags(pathname)
        call easytags#update(1, 0, [])
      endif
    endif
    " Apply highlighting of tags in global tags file to current buffer?
    if &eventignore !~? '\<syntax\>'
      if !exists('b:easytags_last_highlighted')
        call easytags#highlight()
      else
        for tagfile in tagfiles()
          if getftime(tagfile) > b:easytags_last_highlighted
            call easytags#highlight()
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

function! easytags#update(silent, filter_tags, filenames) " {{{2
  try
    let s:cached_filenames = {}
    let starttime = xolox#timer#start()
    let cfile = s:check_cfile(a:silent, a:filter_tags, !empty(a:filenames))
    let tagsfile = easytags#get_tagsfile()
    let firstrun = !filereadable(tagsfile)
    let cmdline = s:prep_cmdline(cfile, tagsfile, firstrun, a:filenames)
    let output = s:run_ctags(starttime, cfile, tagsfile, firstrun, cmdline)
    if !firstrun
      let num_filtered = s:filter_merge_tags(a:filter_tags, tagsfile, output)
      if cfile != ''
        let msg = "%s: Updated tags for %s in %s."
        call xolox#timer#stop(msg, s:script, expand('%:p:~'), starttime)
      elseif a:0 > 0
        let msg = "%s: Updated tags in %s."
        call xolox#timer#stop(msg, s:script, starttime)
      else
        let msg = "%s: Filtered %i invalid tags in %s."
        call xolox#timer#stop(msg, s:script, num_filtered, starttime)
      endif
    endif
    return 1
  catch
    call xolox#warning("%s: %s (at %s)", s:script, v:exception, v:throwpoint)
  finally
    unlet s:cached_filenames
  endtry
endfunction

function! s:check_cfile(silent, filter_tags, have_args) " {{{3
  if a:have_args
    return ''
  endif
  let silent = a:silent || a:filter_tags
  if g:easytags_autorecurse
    let cdir = s:resolve(expand('%:p:h'))
    if !isdirectory(cdir)
      if silent | return '' | endif
      throw "The directory of the current file doesn't exist yet!"
    endif
    return cdir
  endif
  let cfile = s:resolve(expand('%:p'))
  if cfile == '' || !filereadable(cfile)
    if silent | return '' | endif
    throw "You'll need to save your file before using :UpdateTags!"
  elseif g:easytags_ignored_filetypes != '' && &ft =~ g:easytags_ignored_filetypes
    if silent | return '' | endif
    throw "The " . string(&ft) . " file type is explicitly ignored."
  elseif index(easytags#supported_filetypes(), &ft) == -1
    if silent | return '' | endif
    throw "Exuberant Ctags doesn't support the " . string(&ft) . " file type!"
  endif
  return cfile
endfunction

function! s:prep_cmdline(cfile, tagsfile, firstrun, arguments) " {{{3
  let cmdline = [g:easytags_cmd, '--fields=+l', '--c-kinds=+p', '--c++-kinds=+p']
  if a:firstrun
    call add(cmdline, shellescape('-f' . a:tagsfile))
    call add(cmdline, '--sort=' . (&ic ? 'foldcase' : 'yes'))
  else
    call add(cmdline, '--sort=no')
    call add(cmdline, '-f-')
  endif
  if g:easytags_include_members
    call add(cmdline, '--extra=+q')
  endif
  let have_args = 0
  if a:cfile != ''
    if g:easytags_autorecurse
      call add(cmdline, '-R')
      call add(cmdline, shellescape(a:cfile))
    else
      let filetype = easytags#to_ctags_ft(&filetype)
      call add(cmdline, shellescape('--language-force=' . filetype))
      call add(cmdline, shellescape(a:cfile))
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
          call map(matches, 'shellescape(s:canonicalize(v:val))')
          call extend(cmdline, matches)
          let have_args = 1
        endif
      endif
    endfor
  endif
  " No need to run Exuberant Ctags without any filename arguments!
  return have_args ? join(cmdline) : ''
endfunction

function! s:run_ctags(starttime, cfile, tagsfile, firstrun, cmdline) " {{{3
  let output = []
  if a:cmdline != ''
    call xolox#debug("%s: Executing %s", s:script, a:cmdline)
    try
      let output = xolox#shell#execute(a:cmdline, 1)
    catch /^Vim\%((\a\+)\)\=:E117/
      " Ignore missing shell.vim plug-in.
      let output = split(system(a:cmdline), "\n")
      if v:shell_error
        let msg = "Failed to update tags file %s: %s!"
        throw printf(msg, fnamemodify(a:tagsfile, ':~'), strtrans(join(output, "\n")))
      endif
    endtry
    if a:firstrun
      if a:cfile != ''
        call easytags#add_tagged_file(a:cfile)
        call xolox#timer#stop("%s: Created tags for %s in %s.", s:script, expand('%:p:~'), a:starttime)
      else
        call xolox#timer#stop("%s: Created tags in %s.", s:script, a:starttime)
      endif
    endif
  endif
  return output
endfunction

function! s:filter_merge_tags(filter_tags, tagsfile, output) " {{{3
  let [headers, entries] = easytags#read_tagsfile(a:tagsfile)
  call s:set_tagged_files(entries)
  let filters = []
  let tagged_files = s:find_tagged_files(a:output)
  if !empty(tagged_files)
    call add(filters, '!has_key(tagged_files, s:canonicalize(get(v:val, 1)))')
  endif
  if a:filter_tags
    call add(filters, 'filereadable(get(v:val, 1))')
  endif
  let num_old_entries = len(entries)
  if !empty(filters)
    call filter(entries, join(filters, ' && '))
  endif
  let num_filtered = num_old_entries - len(entries)
  call map(entries, 'join(v:val, "\t")')
  call extend(entries, a:output)
  if !easytags#write_tagsfile(a:tagsfile, headers, entries)
    let msg = "Failed to write filtered tags file %s!"
    throw printf(msg, fnamemodify(a:tagsfile, ':~'))
  endif
  return num_filtered
endfunction

function! s:find_tagged_files(new_entries) " {{{3
  let tagged_files = {}
  for line in a:new_entries
    " Never corrupt the tags file by merging an invalid line
    " (probably an error message) with the existing tags!
    if match(line, '^[^\t]\+\t[^\t]\+\t.\+$') == -1
      throw "Exuberant Ctags returned invalid data: " . strtrans(line)
    endif
    let filename = matchstr(line, '^[^\t]\+\t\zs[^\t]\+')
    if !has_key(tagged_files, filename)
      let filename = s:canonicalize(filename)
      let tagged_files[filename] = 1
      call easytags#add_tagged_file(filename)
    endif
  endfor
  return tagged_files
endfunction

function! easytags#highlight() " {{{2
  try
    let filetype = get(s:canonical_aliases, &ft, &ft)
    let tagkinds = get(s:tagkinds, filetype, [])
    if exists('g:syntax_on') && !empty(tagkinds) && !exists('b:easytags_nohl')
      let starttime = xolox#timer#start()
      if !has_key(s:aliases, &ft)
        let taglist = filter(taglist('.'), "get(v:val, 'language', '') ==? &ft")
      else
        let aliases = s:aliases[&ft]
        let taglist = filter(taglist('.'), "has_key(aliases, tolower(get(v:val, 'language', '')))")
      endif
      for tagkind in tagkinds
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
          let template = 'syntax match %s /%s/ containedin=ALLBUT,.*String.*,.*Comment.*'
          let command = printf(template, hlgroup_tagged, escape(pattern, '/'))
          try
            execute command
          catch /^Vim\%((\a\+)\)\=:E339/
            let msg = "easytags.vim: Failed to highlight %i %s tags because pattern is too big! (%i KB)"
            call xolox#warning(printf(msg, len(matches), tagkind.hlgroup, len(pattern) / 1024))
          endtry
        endif
      endfor
      redraw
      let bufname = expand('%:p:~')
      if bufname == ''
        let bufname = 'unnamed buffer #' . bufnr('%')
      endif
      let msg = "%s: Highlighted tags in %s in %s."
      call xolox#timer#stop(msg, s:script, bufname, starttime)
      return 1
    endif
  catch
    call xolox#warning("%s: %s (at %s)", s:script, v:exception, v:throwpoint)
  endtry
endfunction

" Public supporting functions (might be useful to others). {{{1

function! easytags#supported_filetypes() " {{{2
  if !exists('s:supported_filetypes')
    let starttime = xolox#timer#start()
    let command = g:easytags_cmd . ' --list-languages'
    try
      let listing = xolox#shell#execute(command, 1)
    catch /^Vim\%((\a\+)\)\=:E117/
      " Ignore missing shell.vim plug-in.
      let listing = split(system(command), "\n")
      if v:shell_error
        let msg = "Failed to get supported languages! (output: %s)"
        throw printf(msg, strtrans(join(listing, "\n")))
      endif
    endtry
    let s:supported_filetypes = map(copy(listing), 's:check_filetype(listing, v:val)')
    let msg = "%s: Retrieved %i supported languages in %s."
    call xolox#timer#stop(msg, s:script, len(s:supported_filetypes), starttime)
  endif
  return s:supported_filetypes
endfunction

function! s:check_filetype(listing, cline)
  if a:cline !~ '^\w\S*$'
    let msg = "Failed to get supported languages! (output: %s)"
    throw printf(msg, strtrans(join(a:listing, "\n")))
  endif
  return easytags#to_vim_ft(a:cline)
endfunction

function! easytags#read_tagsfile(tagsfile) " {{{2
  " I'm not sure whether this is by design or an implementation detail but
  " it's possible for the "!_TAG_FILE_SORTED" header to appear after one or
  " more tags and Vim will apparently still use the header! For this reason
  " the easytags#write_tagsfile() function should also recognize it, otherwise
  " Vim might complain with "E432: Tags file not sorted".
  let headers = []
  let entries = []
  let pattern = '^\([^\t]\+\)\t\([^\t]\+\)\t\(.\+\)$'
  for line in readfile(a:tagsfile)
    if line =~# '^!_TAG_'
      call add(headers, line)
    else
      call add(entries, matchlist(line, pattern)[1:3])
    endif
  endfor
  return [headers, entries]
endfunction

function! easytags#write_tagsfile(tagsfile, headers, entries) " {{{2
  " This function always sorts the tags file but understands "foldcase".
  let sort_order = 1
  for line in a:headers
    if match(line, '^!_TAG_FILE_SORTED\t2') == 0
      let sort_order = 2
    endif
  endfor
  if sort_order == 1
    call sort(a:entries)
  else
    call sort(a:entries, 1)
  endif
  let lines = []
  if has('win32') || has('win64')
    " Exuberant Ctags on Windows requires \r\n but Vim's writefile() doesn't add them!
    for line in a:headers
      call add(lines, line . "\r")
    endfor
    for line in a:entries
      call add(lines, line . "\r")
    endfor
  else
    call extend(lines, a:headers)
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
    let s:canonical_aliases[type] = a:1
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

function! s:canonicalize(filename) " {{{2
  if has_key(s:cached_filenames, a:filename)
    return s:cached_filenames[a:filename]
  endif
    let canonical = s:resolve(fnamemodify(a:filename, ':p'))
    let s:cached_filenames[a:filename] = canonical
    return canonical
  endif
endfunction

function! s:cache_tagged_files() " {{{2
  if !exists('s:tagged_files')
    let tagsfile = easytags#get_tagsfile()
    try
      let [headers, entries] = easytags#read_tagsfile(tagsfile)
      call s:set_tagged_files(entries)
    catch /\<E484\>/
      " Ignore missing tags file.
      call s:set_tagged_files([])
    endtry
  endif
endfunction

function! s:set_tagged_files(entries) " {{{2
  " TODO use taglist() instead of readfile() so that all tag files are
  " automatically used :-)
  let s:tagged_files = {}
  for entry in a:entries
    let filename = get(entry, 1, '')
    if filename != ''
      let s:tagged_files[s:resolve(filename)] = 1
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
call easytags#map_filetypes(exists('g:filetype_asp') ? g:filetype_asp : 'aspvbs', 'asp')

" Define the Vim file-types that are aliased by default.
let s:aliases = {}
let s:canonical_aliases = {}
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
      \ 'hlgroup': 'cEnum',
      \ 'filter': 'get(v:val, "kind") ==# "e"'})

call easytags#define_tagkind({
      \ 'filetype': 'c',
      \ 'hlgroup': 'cPreProc',
      \ 'filter': 'get(v:val, "kind") ==# "d"'})

call easytags#define_tagkind({
      \ 'filetype': 'c',
      \ 'hlgroup': 'cFunction',
      \ 'filter': 'get(v:val, "kind") =~# "[fp]"'})

highlight def link cEnum Identifier
highlight def link cFunction Function

if g:easytags_include_members
  call easytags#define_tagkind({
        \ 'filetype': 'c',
        \ 'hlgroup': 'cMember',
        \ 'filter': 'get(v:val, "kind") ==# "m"'})
 highlight def link cMember Identifier
endif

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
