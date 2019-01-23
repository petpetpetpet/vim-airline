" MIT License. Copyright (c) 2013-2018 Bailey Ling et al.
" vim: et ts=2 sts=2 sw=2

scriptencoding utf-8

if !exists(':SyntasticCheck')
  finish
endif

let s:error_symbol = get(g:, 'airline#extensions#syntastic#error_symbol', 'E:')
let s:warning_symbol = get(g:, 'airline#extensions#syntastic#warning_symbol', 'W:')
let s:st_warning_symbol = get(g:, 'airline#extensions#syntastic#st_warning_symbol', 'Sw:')
let s:st_error_symbol = get(g:, 'airline#extensions#syntastic#st_error_symbol', 'Se:')
let s:pure_error_symbol = get(g:, 'airline#extensions#syntastic#pure_error_symbol', 'E:')

function! airline#extensions#syntastic#get_warning()
  return airline#extensions#syntastic#get('warning')
endfunction

function! airline#extensions#syntastic#get_error()
  return airline#extensions#syntastic#get('error')
endfunction

function! airline#extensions#syntastic#get_style_warnings()
  return airline#extensions#syntastic#get('style_warnings')
endfunction

function! airline#extensions#syntastic#get_style_errors()
  return airline#extensions#syntastic#get('style_errors')
endfunction

function! airline#extensions#syntastic#get_pure_errors()
  return airline#extensions#syntastic#get('pure_errors')
endfunction

function! airline#extensions#syntastic#get(type)
  let _backup = get(g:, 'syntastic_stl_format', '')
  let prefix_symbol = ''

  " We want to get the number of, and line number of the first
  " error/warn/whatever from syntactic. To do this we are overriding the
  " syntactic status line string so that it contains the info we want.
  if (a:type  is# 'error')
    let g:syntastic_stl_format = get(g:, 'airline#extensions#syntastic#stl_format_err', '%E{[%e(#%fe)]}')
    let prefix_symbol = s:error_symbol
  elseif (a:type  is# 'warning')
    let g:syntastic_stl_format = get(g:, 'airline#extensions#syntastic#stl_format_warn', '%W{[%w(#%fw)]}')
    let prefix_symbol = s:warning_symbol
  elseif (a:type  is# 'style_warnings')
    let g:syntastic_stl_format = get(g:, 'airline#extensions#syntastic#stl_format_st_warn', '%hSW{[%Sw(#%fSw)]}')
    let prefix_symbol = s:st_warning_symbol
  elseif (a:type  is# 'style_errors')
    let g:syntastic_stl_format = get(g:, 'airline#extensions#syntastic#stl_format_st_err', '%hSE{[%Se(#%fSe)]}')
    let prefix_symbol = s:st_error_symbol
  elseif (a:type  is# 'pure_errors')
    let g:syntastic_stl_format = get(g:, 'airline#extensions#syntastic#stl_format_pure_err', '%hPE{[%Pe(#%fPe)]}')
    let prefix_symbol = s:pure_error_symbol
  endif

  "let is_err = (a:type  is# 'error')
  "if is_err
  "  let g:syntastic_stl_format = get(g:, 'airline#extensions#syntastic#stl_format_err', '%E{[%e(#%fe)]}')
  "else
  "  let g:syntastic_stl_format = get(g:, 'airline#extensions#syntastic#stl_format_warn', '%W{[%w(#%fw)]}')
  "endif
  "
  " Now we ask syntactic for its status line.
  let cnt = SyntasticStatuslineFlag()
  if !empty(_backup)
    " Restore the previous syntactic status line formatting, if any.
    let g:syntastic_stl_format = _backup
  endif

  " And return the info.
  if empty(cnt)
    return ''
  else
    return (prefix_symbol).cnt
  endif
endfunction

function! airline#extensions#syntastic#init(ext)
  call airline#parts#define_function('syntastic-warn', 'airline#extensions#syntastic#get_warning')
  call airline#parts#define_function('syntastic-err', 'airline#extensions#syntastic#get_error')
  call airline#parts#define_function('syntastic-style-err', 'airline#extensions#syntastic#get_style_errors')
  call airline#parts#define_function('syntastic-style-warn', 'airline#extensions#syntastic#get_style_warnings')
  call airline#parts#define_function('syntastic-pure-err', 'airline#extensions#syntastic#get_pure_errors')
endfunction
