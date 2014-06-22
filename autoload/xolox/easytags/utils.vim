" Vim script
" Author: Peter Odding <peter@peterodding.com>
" Last Change: June 20, 2014
" URL: http://peterodding.com/code/vim/easytags/

" Utility functions for vim-easytags.

function! xolox#easytags#utils#canonicalize(pathname)
  if !empty(a:pathname)
    return xolox#misc#path#absolute(xolox#easytags#utils#resolve(a:pathname))
  endif
  return a:pathname
endfunction

function! xolox#easytags#utils#resolve(pathname)
  if !empty(a:pathname) && xolox#misc#option#get('easytags_resolve_links', 0)
    return resolve(a:pathname)
  endif
  return a:pathname
endfunction
