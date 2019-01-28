" MIT License. Copyright (c) 2013-2018 Bjorn Neergaard, w0rp, petpetpetpet
" et al.
" vim: et ts=2 sts=2 sw=2

scriptencoding utf-8

function! s:airline_ale_count(cnt, symbol)
  return a:cnt ? a:symbol. a:cnt : ''
endfunction

function! s:decorate_line_num(lnum)
  let open_lnum_symbol  = get(g:, 'airline#extensions#ale#open_lnum_symbol', '(L')
  let close_lnum_symbol = get(g:, 'airline#extensions#ale#close_lnum_symbol', ')')
  return open_lnum_symbol . a:lnum . close_lnum_symbol
endfunction

function! s:old_airline_ale_get_line_data(problem_type, sub_type) abort
  " Older versions of ALE will not have the FirstProblem function. This
  " function obtains line data the hard way.
  let l:buffer       = bufnr('')
  let l:problem_code = (a:problem_type ==# 'error') ? 'E' : 'W'
  let l:problems     = copy(ale#engine#GetLoclist(buffer))

  if a:sub_type ==# 'style'
    call filter(l:problems, 'v:val.bufnr is l:buffer && ' .
                           \'v:val.type is# l:problem_code && ' .
                           \'v:val.sub_type is# a:type')
  else
    call filter(l:problems, 'v:val.bufnr is l:buffer && ' .
                           \'v:val.type is# l:problem_code')
  endif

  if empty(l:problems)
    return {}
  endif

  return l:problems[0]
endfunction

function! s:getFirstProblemOrStyle(buffer, problem_type)
  " Try to get the exact problem_type. If there are no such problems,
  " fall back to the style sub type. Useful if we have
  " a single part displaying both style and error details.
  let l:result = ale#statusline#FirstProblem(a:buffer, a:problem_type)
  if empty(l:result)
    let l:result =  ale#statusline#FirstProblem(a:buffer, 'style_' . a:problem_type)
  endif

  return l:result
endfunction

function! s:getFirstProblemExact(buffer, problem_type, sub_type)
  " Only gets the exact problem type (e.g: if you search for
  " style_errors you'll only get those.)
  " Useful for when style problems and regular problems are being
  " displayed in different parts.
  if a:sub_type ==# 'style'
    return ale#statusline#FirstProblem(a:buffer, 'style_' . a:problem_type)
  else
    return ale#statusline#FirstProblem(a:buffer, a:problem_type)
  endif

endfunction

function! s:new_airline_ale_get_line_data(problem_type, sub_type) abort
  " Chooses the appropriate getFirstProblem function based on
  " the airline#extensions#ale#distinct_style_problem_parts setting.
  let l:buffer = bufnr('')

  if get(g:, 'airline#extensions#ale#distinct_style_problem_parts', 0)
    return s:getFirstProblemExact(l:buffer, a:problem_type, a:sub_type)
  endif

  return s:getFirstProblemOrStyle(l:buffer, a:problem_type)
endfunction

function! s:airline_ale_get_line_data(problem_type, sub_type) abort
  " In order to maintain backwards compatibility with older versions of ALE,
  " we first check whether ALE exposes the FirstIssue function. If so, use it.
  " Otherwise fall back to the old way of pulling line numbers.
  if exists("*ale#statusline#FirstProblem")
    return s:new_airline_ale_get_line_data(a:problem_type, a:sub_type)
  endif

  return s:old_airline_ale_get_line_data(a:problem_type, a:sub_type)
endfunction

function! s:get_problem_count(counts, problem_type, sub_type)
  if type(a:counts) == type({})
    " Use the current Dictionary format.
    if a:sub_type ==# 'style'
        return a:counts["style_" . a:problem_type]
    else
      if get(g:, 'airline#extensions#ale#distinct_style_problem_parts', 0)
        " Get the counts ONLY for the exact problem type and sub type being
        " requested.
        let l:ale_count_key = (a:sub_type ==# 'style') ?
          \ 'style_' . a:problem_type : a:problem_type
        return a:counts[l:ale_count_key]
      else
        " Get the counts of all problems of the requested type.
        let l:errors = a:counts.error + a:counts.style_error
        return (a:problem_type ==# 'error') ? l:errors : a:counts.total - l:errors
      endif
    endif

  endif

  " Older versions of ALE returned the problem counts in a 2-element array.
  return = (a:problem_type ==# 'error') ? counts[0] : counts[1]
endfunction

function! s:get_problem_symbol(problem_type, sub_type)
  " Return the correct symbol based on the problem_type and
  " sub_type.
  let l:error_symbol = get(g:, 'airline#extensions#ale#error_symbol', 'E:')
  let l:warning_symbol = get(g:, 'airline#extensions#ale#warning_symbol', 'W:')
  let l:style_error_symbol = get(g:, 'airline#extensions#ale#style_error_symbol', 'S:')
  let l:style_warning_symbol = get(g:, 'airline#extensions#ale#style_warning_symbol', 'S:')

  if a:sub_type ==# 'style'

    if a:problem_type ==# 'E'
      return l:style_error_symbol
    else
      return l:style_warning_symbol
    endif

  elseif a:problem_type ==# 'E'
    return l:error_symbol
  endif

  return l:warning_symbol
endfunction

function! airline#extensions#ale#get(problem_type, sub_type)
  if !exists(':ALELint')
    return ''
  endif

  let checking_symbol = get(g:, 'airline#extensions#ale#checking_symbol', '...')
  let show_line_numbers = get(g:, 'airline#extensions#ale#show_line_numbers', 1)

  let l:cur_buffer = bufnr('')

  " Check if ALE is still processing. If so, then if problem_type
  " is 'warning' we should display the checking_symbol.
  if ale#engine#IsCheckingBuffer(l:cur_buffer) == 1
    return (a:problem_type ==# 'warning' && a:sub_type ==# '') ?
      \ checking_symbol : ''
  endif

  " Ask ale for the number of problems it found.
  let l:counts = ale#statusline#Count(l:cur_buffer)
  if type(l:counts) != type({})
    " If the result is not a dict, then ALE is an old version which
    " cannot support problem subtypes. (old version of the Count API
    " function returned an array. The current version returns a
    " dictionary.)
    let a:sub_type = ''
  endif

  let l:num = s:get_problem_count(l:counts, a:problem_type, a:sub_type)

  let l:line_num_str = ""
  let l:returned_type_code = (a:problem_type ==# 'error') ? 'E': 'W'
  let l:returned_sub_type = a:sub_type

  if l:num > 0 && show_line_numbers
    let l:line_data = s:airline_ale_get_line_data(a:problem_type, a:sub_type)
    if !empty(l:line_data) && has_key(l:line_data, 'lnum')
      " Depending on the configuration (especially if 
      " distinct_style_problem_parts = 0) the line returned by ALE might not
      " match the a:sub_type we asked for. (e.g: maybe we ask for 
      " problem_type=error, sub_type='' and the returned line_data has a
      " style subtype.)
      " We hande that case by simply decorating the line based on the 
      " *actual* returned sub_type.
      let l:returned_type_code = get(l:line_data, 'type', '')
      let l:returned_sub_type = get(l:line_data, 'sub_type', '')

      let l:line_num_str = s:decorate_line_num(l:line_data.lnum)
    endif
  endif

  let l:symbol = s:get_problem_symbol(l:returned_type_code, l:returned_sub_type)

  " Return the contents of this part.
  if show_line_numbers == 1
    return s:airline_ale_count(l:num, l:symbol) . l:line_num_str
  else
    return s:airline_ale_count(l:num, l:symbol)
  endif
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
  call airline#parts#define_function('ale_error_count', 'airline#extensions#ale#get_errors')
  call airline#parts#define_function('ale_warning_count', 'airline#extensions#ale#get_warnings')
  call airline#parts#define_function('ale_style_error_count', 'airline#extensions#ale#get_style_errors')
  call airline#parts#define_function('ale_style_warning_count', 'airline#extensions#ale#get_style_warnings')
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
