" MIT License. Copyright (c) 2013-2019 Bjorn Neergaard, w0rp, petpetpetpet
" et al.
" vim: et ts=2 sts=2 sw=2

scriptencoding utf-8

function! s:treat_distinct(problem_type)
  " Determines whether problems matching problem_type should be
  " distinguished from their style subtypes.
  if a:problem_type is# 'error'
    return get(g:, 'airline#extensions#ale#distinct_style_errors', 0)
  endif

  return get(g:, 'airline#extensions#ale#distinct_style_warnings', 0)
endfunction

function! s:decorate_ale_count(cnt, symbol)
  return a:cnt ? a:symbol . a:cnt : ''
endfunction

function! s:decorate_line_num(lnum)
  " Pre and appends the open_lnum_symbol and close_lnum_symbol
  " to the lnum result.

  let l:open_lnum_symbol  = get(
    \g:,
    \'airline#extensions#ale#open_lnum_symbol',
    \'(L')

  let l:close_lnum_symbol = get(
    \g:,
    \'airline#extensions#ale#close_lnum_symbol',
    \')')

  return l:open_lnum_symbol . a:lnum . l:close_lnum_symbol
endfunction

function! s:old_airline_ale_get_line_data(problem_type, sub_type) abort
  " Older versions of ALE will not have the FirstProblem function. This
  " function obtains line data the hard way.
  let l:buffer       = bufnr('')
  let l:problem_code = (a:problem_type is# 'error') ? 'E' : 'W'
  let l:problems     = copy(ale#engine#GetLoclist(buffer))

  if a:sub_type ==# 'style'
    call filter(l:problems, 'v:val.bufnr is l:buffer && ' .
                           \'v:val.type is# l:problem_code && ' .
                           \'get(v:val, "sub_type", "") is# a:sub_type')
  else
    call filter(l:problems, 'v:val.bufnr is l:buffer && ' .
                           \'v:val.type is# l:problem_code')
  endif

  if empty(l:problems)
    return {}
  endif

  return l:problems[0]
endfunction

function! airline#extensions#ale#line_data_fallback(buffer, problem_type)
  " Try to get the exact problem_type. If there are no such problems,
  " fall back to the style sub type. Useful if we have
  " a single part displaying both style and error details.
  let l:result = ale#statusline#FirstProblem(a:buffer, a:problem_type)

  if empty(l:result)

    let l:result = ale#statusline#FirstProblem(
      \a:buffer,
      \'style_' . a:problem_type)

  endif

  return l:result
endfunction

function! airline#extensions#ale#line_data_exact(buf, problem_type, sub_type)
  " Only gets the exact problem type (e.g: if you search for
  " style_errors you'll only get those.)
  " Useful for when style problems and regular problems are being
  " displayed in different parts.
  if a:sub_type ==# 'style'
    return ale#statusline#FirstProblem(a:buf, 'style_' . a:problem_type)
  else
    return ale#statusline#FirstProblem(a:buf, a:problem_type)
  endif

endfunction

function! s:new_airline_ale_get_line_data(problem_type, sub_type) abort
  " Chooses the appropriate getFirstProblem function based on
  " the treat_distinct setting.
  let l:buf = bufnr('')

  if s:treat_distinct(a:problem_type)
    return airline#extensions#ale#line_data_exact(l:buf, a:problem_type, a:sub_type)
  endif

  return airline#extensions#ale#line_data_fallback(l:buf, a:problem_type)
endfunction

function! s:airline_ale_get_line_data(problem_type, sub_type) abort
  " In order to maintain backwards compatibility with older versions of ALE,
  " we first check whether ALE exposes the FirstIssue function. If so, use it.
  " Otherwise fall back to the old way of pulling line numbers.
  if !exists("*ale#statusline#FirstProblem") ||
      \ get(g:, 'airline#extensions#ale#use_old_prioritisation', 0)
    return s:old_airline_ale_get_line_data(a:problem_type, a:sub_type)
  endif

  return s:new_airline_ale_get_line_data(a:problem_type, a:sub_type)
endfunction

function! s:get_problem_count(counts, problem_type, sub_type)
  if type(a:counts) == type({})
    " Use the current Dictionary format.
    if a:sub_type is# 'style'
        return a:counts["style_" . a:problem_type]
    else
      if s:treat_distinct(a:problem_type)
        " Get the counts ONLY for the exact problem type and sub type being
        " requested.
        let l:ale_count_key = (a:sub_type is# 'style') ?
          \ 'style_' . a:problem_type : a:problem_type
        return a:counts[l:ale_count_key]
      else
        " Get the counts of all problems of the requested type.
        let l:errors = a:counts.error + a:counts.style_error
        return (a:problem_type is# 'error') ? l:errors :
          \a:counts.total - l:errors
      endif
    endif

  endif

  " Older versions of ALE returned the problem counts in a 2-element array.
  return = (a:problem_type is# 'error') ? counts[0] : counts[1]
endfunction

function! s:get_problem_symbol(problem_type, sub_type)
  " Return the correct symbol based on the problem_type and sub_type.
  let l:error_symbol = get(g:, 'airline#extensions#ale#error_symbol', 'E:')
  let l:warning_symbol = get(g:, 'airline#extensions#ale#warning_symbol', 'W:')

  let l:style_error_symbol = get(
    \g:,
    \'airline#extensions#ale#style_error_symbol',
    \'S:')

  let l:style_warning_symbol = get(
    \g:,
    \'airline#extensions#ale#style_warning_symbol',
    \'S:')

  if a:sub_type is# 'style'

    if a:problem_type is# 'E'
      return l:style_error_symbol
    else
      return l:style_warning_symbol
    endif

  elseif a:problem_type is# 'E'
    return l:error_symbol
  endif

  return l:warning_symbol
endfunction

function! airline#extensions#ale#get(problem_type, sub_type)
  " Returns a formatted string containing:
  "
  " 1. The number of problems of the specified type.
  " 2. Optionally, the line number of the first such problem.
  "
  " The return value of this function is used to populate
  " airline parts pertaining to errors and warnings.
  if !exists(':ALELint')
    return ''
  endif

  let l:checking_symbol = get(
    \g:,
    \'airline#extensions#ale#checking_symbol',
    \'...')

  let l:show_line_numbers = get(g:,
    \'airline#extensions#ale#show_line_numbers',
    \1)

  let l:cur_buffer = bufnr('')

  " Check if ALE is still processing. If so, then if problem_type
  " is 'warning' we should display the checking_symbol.
  if ale#engine#IsCheckingBuffer(l:cur_buffer) == 1
    return (a:problem_type ==# 'warning' && a:sub_type ==# '') ?
      \ l:checking_symbol : ''
  endif

  " Ask ale for the number of problems it found.
  let l:counts = ale#statusline#Count(l:cur_buffer)
  if type(l:counts) != type({})
    " If the result is not a dict, then ALE is a super old version (< 2.0)
    " that cannot support problem subtypes. (old version of the Count API
    " function returned an array. The current version returns a
    " dictionary.)
    let a:sub_type = ''
  endif

  let l:num = s:get_problem_count(l:counts, a:problem_type, a:sub_type)

  let l:line_num_str = ""
  let l:returned_type_code = (a:problem_type ==# 'error') ? 'E': 'W'
  let l:returned_sub_type = a:sub_type

  if l:num > 0 && l:show_line_numbers
    let l:line_data = s:airline_ale_get_line_data(a:problem_type, a:sub_type)
    if !empty(l:line_data) && has_key(l:line_data, 'lnum')
      " If one of the style distinctiveness settings are off, then the sub
      " type of the line returned from airline_ale_get_line_data might be
      " different than a:sub_type. This code ensures that when we are showing
      " line numbers, that we use the returned sub type to construct the
      " part contents, *not* a:sub_type.
      let l:returned_type_code = get(l:line_data, 'type', '')
      let l:returned_sub_type = get(l:line_data, 'sub_type', '')
      let l:line_num_str = s:decorate_line_num(l:line_data.lnum)
    endif
  endif

  let l:symbol = s:get_problem_symbol(
    \l:returned_type_code,
    \l:returned_sub_type)

  " The part always includes a count...
  let l:part_contents = s:decorate_ale_count(l:num, l:symbol)

  " And might also include line numbers
  if l:show_line_numbers == 1
    let l:part_contents .= l:line_num_str
  endif

  return l:part_contents
endfunction

function! airline#extensions#ale#get_style_warnings()
  return airline#extensions#ale#get('warning', 'style')
endfunction

function! airline#extensions#ale#get_style_errors()
  return airline#extensions#ale#get('error', 'style')
endfunction

function! airline#extensions#ale#get_warnings()
  return airline#extensions#ale#get('warning', '')
endfunction

function! airline#extensions#ale#get_errors()
  return airline#extensions#ale#get('error', '')
endfunction

function! airline#extensions#ale#init(ext)
  call airline#parts#define_function('ale_error_count',
    \'airline#extensions#ale#get_errors')
  call airline#parts#define_function('ale_warning_count',
    \'airline#extensions#ale#get_warnings')
  call airline#parts#define_function('ale_style_error_count',
    \'airline#extensions#ale#get_style_errors')
  call airline#parts#define_function('ale_style_warning_count',
    \'airline#extensions#ale#get_style_warnings')
  augroup airline_ale
    autocmd!
    autocmd CursorHold,BufWritePost * call <sid>ale_refresh()
    autocmd User ALEJobStarted,ALELintPost call <sid>ale_refresh()
  augroup END
endfunction

function! s:ale_refresh()
  if get(g:, 'airline_skip_empty_sections', 0)
    exe ':AirlineRefresh'
  endif
endfunction
