if exists('*matchstrpos')
    function! s:matchstrpos(expr, pattern) abort
        return matchstrpos(a:expr, a:pattern)
    endfunction
else
    function! s:matchstrpos(expr, pattern) abort
        return [matchstr(a:expr, a:pattern), match(a:expr, a:pattern), matchend(a:expr, a:pattern)]
    endfunction
endif

let g:cm_matcher = get(g:,'cm_matcher',{'module': 'cm_matchers.prefix_matcher', 'case': 'smartcase'})

function! cm#register_source(info) abort
  if !has_key(a:info, 'scopes')
      let a:info['scopes'] = ['*']
  endif
  if !has_key(a:info, 'cm_refresh')
      let a:info['cm_refresh'] = function('asyncomplete#sources#'.a:info['name'].'#completor')
  endif

  if !has_key(a:info, 'priority')
      let a:info['priority'] = 0
  endif

  if has_key(a:info, 'cm_refresh_patterns')
    let l:patterns = a:info['cm_refresh_patterns']

    if len(l:patterns) == 1
      let a:info['refresh_pattern'] = '\v('. l:patterns[0] . ')'
    else
      let a:info['refresh_pattern'] = '\v('. join(l:patterns, '|') . ')'
    endif
  endif

  if has_key(a:info, 'word_pattern')
    let l:word_pattern = '\v('. a:info['word_pattern'] . '$)'
  else
    let l:word_pattern = '\v((-?\d*\.\d\w*)|([^\`\~\!\@\#\$\%\^\&\*\(\)\-\=\+\[\{\]\}\\\|\;\:\''\"\,\.\<\>\/\?\s]+)$)'
  endif

  function! Closure(opt, ctx) closure
    let l:refresh = a:info['cm_refresh']
    let l:type = type(l:refresh)
    if  l:type == 1
      let l:ctx = copy(a:ctx)
      let l:match = s:matchstrpos(l:ctx['typed'], l:word_pattern)
      let l:ctx['base'] = l:match[0]
      let l:ctx['startcol'] = l:ctx['col'] - len(l:match[0])

      return function(l:refresh)(a:opt, l:ctx)
    elseif  l:type == 2
      let l:ctx = copy(a:ctx)
      let l:match = s:matchstrpos(l:ctx['typed'], l:word_pattern)
      let l:ctx['base'] = l:match[0]
      let l:ctx['startcol'] = l:ctx['col'] - len(l:match[0])

      return l:refresh(a:opt, l:ctx)
  endfunction

  call asyncomplete#register_source({
    \ 'name': a:info['name'],
    \ 'priority': a:info['priority'],
    \ 'whitelist': a:info['scopes'],
    \ 'completor': funcref('Closure'),
    \ 'refresh_pattern': a:info['refresh_pattern']
    \ })
endfunction

func! cm#complete(info, context, startcol, matches, ...)
  call asyncomplete#complete(a:info['name'], a:context, a:startcol, a:matches)
endfunc

func! cm#context_changed(ctx)
  return asyncomplete#context_changed(a:ctx)
endfunc

autocmd User asyncomplete_setup call cm#shim()

function! cm#shim() abort
  doautocmd User CmSetup
endfunction
