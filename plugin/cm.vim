if get(g:, 'asyncomplete_shim_loaded')
  finish
endif
let g:asyncomplete_shim_loaded = 1

if exists('*matchstrpos')
    function! s:matchstrpos(expr, pattern) abort
        return matchstrpos(a:expr, a:pattern)
    endfunction
else
    function! s:matchstrpos(expr, pattern) abort
        return [matchstr(a:expr, a:pattern), match(a:expr, a:pattern), matchend(a:expr, a:pattern)]
    endfunction
endif

" omni completion wrapper
func! s:asyncomplete_refresh_omni(opt,ctx)
    " omni function's startcol is zero based, convert it to one based
    let l:startcol = call(a:opt['cm_refresh']['omnifunc'],[1,'']) + 1
    let l:typed = a:ctx['typed']
    let l:base = l:typed[l:startcol-1:]
    let l:matches = call(a:opt['cm_refresh']['omnifunc'],[0, l:base])
    if type(l:matches)!=type([])
        return
    endif
    call asyncomplete#complete(a:opt['name'], a:ctx, l:startcol, l:matches)
endfunc

let g:cm_matcher = get(g:,'cm_matcher',{'module': 'cm_matchers.prefix_matcher', 'case': 'smartcase'})

function! cm#register_source(info) abort
  let l:name = a:info['name']
  if has_key(g:cm_sources_override, l:name)
      " override source default options
      call extend(a:info, g:cm_sources_override[l:name])
  endif

  if !has_key(a:info, 'scopes')
      let a:info['scopes'] = ['*']
  endif
  if !has_key(a:info, 'cm_refresh')
      let a:info['cm_refresh'] = function('asyncomplete#sources#'.l:name.'#completor')
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
    elseif l:type==4 && has_key(l:refresh,'omnifunc')
        call s:asyncomplete_refresh_omni(a:info, a:ctx)
    endif
  endfunction

  call asyncomplete#register_source({
    \ 'name': l:name,
    \ 'priority': a:info['priority'],
    \ 'whitelist': a:info['scopes'],
    \ 'completor': funcref('Closure'),
    \ 'refresh_pattern': a:info['refresh_pattern']
    \ })
endfunction

func! cm#complete(info, context, startcol, matches, ...)
  let l:args = [a:info['name'], a:context, a:startcol, a:matches] + deepcopy(a:000)
  call call('asyncomplete#complete', l:args)
endfunc

func! cm#context_changed(ctx)
  return asyncomplete#context_changed(a:ctx)
endfunc

autocmd User asyncomplete_setup call cm#shim()

function! cm#shim() abort
  doautocmd User CmSetup
endfunction
