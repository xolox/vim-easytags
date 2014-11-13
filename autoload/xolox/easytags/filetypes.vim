" Vim script
" Author: Peter Odding <peter@peterodding.com>
" Last Change: November 13, 2014
" URL: http://peterodding.com/code/vim/easytags/

" This submodule of the vim-easytags plug-in translates between back and forth
" between Vim file types and Exuberant Ctags languages. This is complicated by
" a couple of things:
"
"  - Vim allows file types to be combined like `filetype=c.doxygen'.
"
"  - Some file types need to be canonicalized, for example the `htmldjango'
"    Vim file type should be treated as the `html' Exuberant Ctags language.

" Whether we've run Exuberant Ctags to discover the supported file types.
let s:discovered_filetypes = 0

" List of supported Vim file types.
let s:supported_filetypes = []

" Mapping of Exuberant Ctags languages to Vim file types and vice versa.
let g:xolox#easytags#filetypes#ctags_to_vim = {}
let g:xolox#easytags#filetypes#vim_to_ctags = {}

" Mapping of Vim file types to canonical file types.
let s:canonical_filetypes = {}

" Mapping of canonical Vim file types to their groups.
let s:filetype_groups = {}

function! xolox#easytags#filetypes#add_group(...) " {{{1
  " Define a group of Vim file types whose tags should be stored together.
  let canonical_filetype = tolower(a:1)
  let other_filetypes = map(a:000[1:], 'tolower(v:val)')
  let s:filetype_groups[canonical_filetype] = other_filetypes
  for ft in other_filetypes
    let s:canonical_filetypes[ft] = canonical_filetype
  endfor
endfunction

function! xolox#easytags#filetypes#add_mapping(vim_filetype, ctags_language) " {{{1
  " Map an Exuberant Ctags language to a Vim file type and vice versa.
  let vim_filetype = tolower(a:vim_filetype)
  let ctags_language = tolower(a:ctags_language)
  let g:xolox#easytags#filetypes#ctags_to_vim[ctags_language] = vim_filetype
  let g:xolox#easytags#filetypes#vim_to_ctags[vim_filetype] = ctags_language
endfunction

function! xolox#easytags#filetypes#to_vim(ctags_language) " {{{1
  " Translate an Exuberant Ctags language to a Vim file type.
  let ctags_language = tolower(a:ctags_language)
  return get(g:xolox#easytags#filetypes#ctags_to_vim, ctags_language, ctags_language)
endfunction

function! xolox#easytags#filetypes#to_ctags(vim_filetype) " {{{1
  " Translate a Vim file type to an Exuberant Ctags language.
  let vim_filetype = tolower(a:vim_filetype)
  return get(g:xolox#easytags#filetypes#vim_to_ctags, vim_filetype, vim_filetype)
endfunction

function! xolox#easytags#filetypes#canonicalize(vim_filetype_value) " {{{1
  " Select a canonical, supported Vim file type given a value of &filetype.
  call s:discover_supported_filetypes()
  " Split the possibly combined Vim file type into individual file types.
  for filetype in split(tolower(a:vim_filetype_value), '\.')
    " Canonicalize the Vim file type.
    let filetype = get(s:canonical_filetypes, filetype, filetype)
    if index(s:supported_filetypes, filetype) >= 0
      return filetype
    endif
  endfor
  return ''
endfunction

function! xolox#easytags#filetypes#find_ctags_aliases(canonical_vim_filetype) " {{{1
  " Find Exuberant Ctags languages that correspond to a canonical, supported Vim file type.
  if has_key(s:filetype_groups, a:canonical_vim_filetype)
    let filetypes = [a:canonical_vim_filetype]
    call extend(filetypes, s:filetype_groups[a:canonical_vim_filetype])
    return map(filetypes, 'xolox#easytags#filetypes#to_ctags(v:val)')
  else
    return [xolox#easytags#filetypes#to_ctags(a:canonical_vim_filetype)]
  endif
endfunction

function! s:discover_supported_filetypes() " {{{1
  " Initialize predefined groups & mappings and discover supported file types.
  if !s:discovered_filetypes
    " Discover the file types supported by Exuberant Ctags?
    let command_line = xolox#easytags#ctags_command()
    if !empty(command_line)
      let starttime = xolox#misc#timer#start()
      let command_line .= ' --list-languages'
      for line in xolox#misc#os#exec({'command': command_line})['stdout']
        if line =~ '\[disabled\]$'
          " Ignore languages that have been explicitly disabled using `--languages=-Vim'.
          continue
        elseif line =~ '^\w\S*$'
          call add(s:supported_filetypes, xolox#easytags#filetypes#to_vim(xolox#misc#str#trim(line)))
        elseif line =~ '\S'
          call xolox#misc#msg#warn("easytags.vim %s: Failed to parse line of output from ctags --list-languages: %s", g:xolox#easytags#version, string(line))
        endif
      endfor
      let msg = "easytags.vim %s: Retrieved %i supported languages in %s."
      call xolox#misc#timer#stop(msg, g:xolox#easytags#version, len(s:supported_filetypes), starttime)
    endif
    " Add file types supported by language specific programs.
    call extend(s:supported_filetypes, keys(xolox#misc#option#get('easytags_languages', {})))
    " Don't run s:discover_supported_filetypes() more than once.
    let s:discovered_filetypes = 1
  endif
endfunction

" }}}1

" Define the default file type groups. It's important that C normalizes to C++
" because of the following points:
"
"  - Vim and Exuberant Ctags consistently treat *.h files as C++. I guess this
"    is because A) the filename extension is ambiguous and B) C++ is a
"    superset of C so the mapping makes sense.
"
"  - Because of the above point, when you use file type specific tags files
"    and you're editing C source code you'll be missing everything defined in
"    your *.h files. Depending on your programming style those tags might be
"    redundant or they might not be.
"
" To solve this dilemma the vim-easytags plug-in groups the C and C++ file
" types together and tells Exuberant Ctags to treat it all as C++ because C++
" is a superset of C.
call xolox#easytags#filetypes#add_group('cpp', 'c')
call xolox#easytags#filetypes#add_group('html', 'htmldjango')

" Define the default file type mappings.
call xolox#easytags#filetypes#add_mapping('cpp', 'c++')
call xolox#easytags#filetypes#add_mapping('cs', 'c#')
call xolox#easytags#filetypes#add_mapping(exists('g:filetype_asp') ? g:filetype_asp : 'aspvbs', 'asp')

" vim: ts=2 sw=2 et
