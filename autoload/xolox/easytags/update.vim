" Vim script
" Author: Peter Odding <peter@peterodding.com>
" Last Change: August 8, 2014
" URL: http://peterodding.com/code/vim/easytags/

" This Vim auto-load script contains the parts of vim-easytags that are used
" to update tags files. The vim-easytags plug-in can run this code in one of
" two ways:
"
"  - Synchronously inside your main Vim process, blocking your editing session
"    during the tags file update (not very nice as your tags files get larger
"    and updating them becomes slower).
"
"  - Asynchronously in a separate Vim process to update a tags file in the
"    background without blocking your editing session (this provides a much
"    nicer user experience).
"
" This code is kept separate from the rest of the plug-in to force me to use
" simple form of communication (a Vim dictionary with all of the state
" required to update tags files) which in the future can be used to implement
" an alternative update mechanism in a faster scripting language (for example
" I could translate the Vim dictionary to JSON and feed it to Python).

function! xolox#easytags#update#with_vim(params) " {{{1
  let counters = {}
  let starttime = xolox#misc#timer#start()
  call xolox#misc#msg#debug("easytags.vim %s: Executing %s.", g:xolox#easytags#version, a:params['command'])
  let lines = xolox#misc#os#exec({'command': a:params['command']})['stdout']
  let entries = xolox#easytags#update#parse_entries(lines)
  let counters['num_updated'] = len(entries)
  let directory = get(a:params, 'directory', '')
  let cache = s:create_cache()
  if !empty(directory)
    let counters['num_filtered'] = s:save_by_filetype(a:params['filter_tags'], [], entries, cache, directory)
  else
    let counters['num_filtered'] = s:filter_merge_tags(a:params['filter_tags'], a:params['tagsfile'], entries, cache)
  endif
  let counters['elapsed_time'] = xolox#misc#timer#convert(starttime)
  return counters
endfunction

function! xolox#easytags#update#convert_by_filetype(undo) " {{{1
  try
    if empty(g:easytags_by_filetype)
      throw "Please set g:easytags_by_filetype before running :TagsByFileType!"
    endif
    let global_tagsfile = expand(g:easytags_file)
    let disabled_tagsfile = global_tagsfile . '.disabled'
    if !a:undo
      let [headers, entries] = xolox#easytags#update#read_tagsfile(global_tagsfile)
      call s:save_by_filetype(0, headers, entries)
      call rename(global_tagsfile, disabled_tagsfile)
      let msg = "easytags.vim %s: Finished copying tags from %s to %s! Note that your old tags file has been renamed to %s instead of deleting it, should you want to restore it."
      call xolox#misc#msg#info(msg, g:xolox#easytags#version, g:easytags_file, g:easytags_by_filetype, disabled_tagsfile)
    else
      let headers = []
      let all_entries = []
      for tagsfile in split(glob(g:easytags_by_filetype . '/*'), '\n')
        let [headers, entries] = xolox#easytags#update#read_tagsfile(tagsfile)
        call extend(all_entries, entries)
      endfor
      call xolox#easytags#update#write_tagsfile(global_tagsfile, headers, all_entries)
      call xolox#misc#msg#info("easytags.vim %s: Finished copying tags from %s to %s!", g:xolox#easytags#version, g:easytags_by_filetype, g:easytags_file)
    endif
  catch
    call xolox#misc#msg#warn("easytags.vim %s: %s (at %s)", g:xolox#easytags#version, v:exception, v:throwpoint)
  endtry
endfunction

function! s:filter_merge_tags(filter_tags, tagsfile, output, cache) " {{{1
  let [headers, entries] = xolox#easytags#update#read_tagsfile(a:tagsfile)
  let tagged_files = s:find_tagged_files(a:output, a:cache)
  if !empty(tagged_files)
    call filter(entries, '!has_key(tagged_files, a:cache.canonicalize(v:val[1]))')
  endif
  " Filter tags for non-existing files?
  let count_before_filter = len(entries)
  if a:filter_tags
    call filter(entries, 'a:cache.exists(v:val[1])')
  endif
  let num_filtered = count_before_filter - len(entries)
  " Merge the old and new tags.
  call extend(entries, a:output)
  " Now we're ready to save the tags file.
  if !xolox#easytags#update#write_tagsfile(a:tagsfile, headers, entries)
    let msg = "Failed to write filtered tags file %s!"
    throw printf(msg, fnamemodify(a:tagsfile, ':~'))
  endif
  return num_filtered
endfunction

function! s:find_tagged_files(entries, cache) " {{{1
  let tagged_files = {}
  for entry in a:entries
    let filename = a:cache.canonicalize(entry[1])
    if filename != ''
      if !has_key(tagged_files, filename)
        let tagged_files[filename] = 1
      endif
    endif
  endfor
  return tagged_files
endfunction

function! s:save_by_filetype(filter_tags, headers, entries, cache, directory) " {{{1
  let filetypes = {}
  let num_invalid = 0
  let num_filtered = 0
  for entry in a:entries
    let ctags_ft = matchstr(entry[4], '^language:\zs\S\+$')
    if empty(ctags_ft)
      " TODO This triggers on entries where the pattern contains tabs. The interesting thing is that Vim reads these entries fine... Fix it in xolox#easytags#update#read_tagsfile()?
      let num_invalid += 1
      if &vbs >= 1
        call xolox#misc#msg#debug("easytags.vim %s: Skipping tag without 'language:' field: %s",
              \ g:xolox#easytags#version, string(entry))
      endif
    else
      let vim_ft = xolox#easytags#filetypes#to_vim(ctags_ft)
      if !has_key(filetypes, vim_ft)
        let filetypes[vim_ft] = []
      endif
      call add(filetypes[vim_ft], entry)
    endif
  endfor
  if num_invalid > 0
    call xolox#misc#msg#warn("easytags.vim %s: Skipped %i lines without 'language:' tag!", g:xolox#easytags#version, num_invalid)
  endif
  let directory = xolox#misc#path#absolute(a:directory)
  for vim_ft in keys(filetypes)
    let tagsfile = xolox#misc#path#merge(directory, vim_ft)
    let existing = filereadable(tagsfile)
    call xolox#misc#msg#debug("easytags.vim %s: Writing %s tags to %s tags file %s.",
          \ g:xolox#easytags#version, len(filetypes[vim_ft]),
          \ existing ? "existing" : "new", tagsfile)
    if !existing
      call xolox#easytags#update#write_tagsfile(tagsfile, a:headers, filetypes[vim_ft])
    else
      let num_filtered += s:filter_merge_tags(a:filter_tags, tagsfile, filetypes[vim_ft], a:cache)
    endif
  endfor
  return num_filtered
endfunction

function! xolox#easytags#update#read_tagsfile(tagsfile) " {{{1
  " I'm not sure whether this is by design or an implementation detail but
  " it's possible for the "!_TAG_FILE_SORTED" header to appear after one or
  " more tags and Vim will apparently still use the header! For this reason
  " the xolox#easytags#update#write_tagsfile() function should also recognize it,
  " otherwise Vim might complain with "E432: Tags file not sorted".
  let headers = []
  let entries = []
  let num_invalid = 0
  if filereadable(a:tagsfile)
    let lines = readfile(a:tagsfile)
  else
    let lines = []
  endif
  for line in lines
    if line =~# '^!_TAG_'
      call add(headers, line)
    else
      let entry = xolox#easytags#update#parse_entry(line)
      if !empty(entry)
        call add(entries, entry)
      else
        let num_invalid += 1
      endif
    endif
  endfor
  if num_invalid > 0
    call xolox#misc#msg#warn("easytags.vim %s: Ignored %i invalid line(s) in %s!", g:xolox#easytags#version, num_invalid, a:tagsfile)
  endif
  return [headers, entries]
endfunction

function! xolox#easytags#update#parse_entry(line) " {{{1
  let fields = split(a:line, '\t')
  return len(fields) >= 3 ? fields : []
endfunction

function! xolox#easytags#update#parse_entries(lines) " {{{1
  call map(a:lines, 'xolox#easytags#update#parse_entry(v:val)')
  return filter(a:lines, '!empty(v:val)')
endfunction

function! xolox#easytags#update#write_tagsfile(tagsfile, headers, entries) " {{{1
  " This function always sorts the tags file but understands "foldcase".
  let sort_order = 0
  let sort_header_present = 0
  let sort_header_pattern = '^!_TAG_FILE_SORTED\t\zs\d'
  " Discover the sort order defined in the tags file headers.
  let i = 0
  for line in a:headers
    let match = matchstr(line, sort_header_pattern)
    if !empty(match)
      let sort_header_present = 1
      let sort_order = match + 0
      if sort_order == 0
        let sort_order = 2
        let a:headers[i] = substitute(line, sort_header_pattern, '2', '')
      endif
    endif
  endfor
  if !sort_header_present
    " If no sorting is defined in the tags file headers we default to
    " "foldcase" sorting and add the header.
    let sort_order = 2
    call add(a:headers, "!_TAG_FILE_SORTED\t2\t/0=unsorted, 1=sorted, 2=foldcase/")
  endif
  call xolox#easytags#update#join_entries(a:entries)
  if sort_order == 1
    call sort(a:entries)
  else
    call sort(a:entries, function('xolox#easytags#update#foldcase_compare'))
  endif
  let lines = []
  if xolox#misc#os#is_win()
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
  " Make sure the directory exists.
  let directory = fnamemodify(a:tagsfile, ':h')
  if !isdirectory(directory)
    call mkdir(directory, 'p')
  endif
  " Write the new contents to a temporary file and atomically rename the
  " temporary file into place while preserving the file's permissions.
  return xolox#misc#perm#update(a:tagsfile, lines)
endfunction

function! s:enumerate(list)
  let items = []
  let index = 0
  for item in a:list
    call add(items, [index, item])
    let index += 1
  endfor
  return items
endfunction

function! xolox#easytags#update#join_entry(value) " {{{1
  return type(a:value) == type([]) ? join(a:value, "\t") : a:value
endfunction

function! xolox#easytags#update#join_entries(values) " {{{1
  call map(a:values, 'xolox#easytags#update#join_entry(v:val)')
  return filter(a:values, '!empty(v:val)')
endfunction

function! xolox#easytags#update#foldcase_compare(a, b) " {{{1
  let a = toupper(a:a)
  let b = toupper(a:b)
  return a == b ? 0 : a ># b ? 1 : -1
endfunction

function! s:create_cache() " {{{1
  let cache = {'canonicalize_cache': {}, 'exists_cache': {}}
  function cache.canonicalize(pathname) dict
    let cache = self['canonicalize_cache']
    if !empty(a:pathname)
      if !has_key(cache, a:pathname)
        let cache[a:pathname] = xolox#easytags#utils#canonicalize(a:pathname)
      endif
      return cache[a:pathname]
    endif
    return ''
  endfunction
  function cache.exists(pathname) dict
    let cache = self['exists_cache']
    if !empty(a:pathname)
      if !has_key(cache, a:pathname)
        let cache[a:pathname] = filereadable(a:pathname)
      endif
      return cache[a:pathname]
    endif
    return 0
  endfunction
  return cache
endfunction
