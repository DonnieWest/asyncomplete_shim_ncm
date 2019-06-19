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

let s:prev_typed = ''
let s:prev_matches = []
let s:prev_startcol = 0
let s:prev_cur = []

" omni completion wrapper
func! s:asyncomplete_refresh_omni(opt,ctx)
    " omni function's startcol is zero based, convert it to one based
    let l:startcol = call(a:opt['on_complete']['omnifunc'],[1,'']) + 1
    let l:typed = a:ctx['typed']
    if l:typed ==# s:prev_typed || a:ctx['curpos'] == s:prev_cur
      call asyncomplete#complete(a:opt['name'], a:ctx, l:startcol, s:prev_matches)
    endif
    let l:base = l:typed[l:startcol-1:]
    let l:matches = call(a:opt['on_complete']['omnifunc'],[0, l:base])
    if type(l:matches)!=type([])
        return
    endif
    let s:prev_typed = l:typed
    let s:prev_startcol = l:startcol
    let s:prev_matches = l:matches
    call asyncomplete#complete(a:opt['name'], a:ctx, l:startcol, l:matches)
endfunc

let g:cm_matcher = get(g:,'cm_matcher',{'module': 'cm_matchers.prefix_matcher', 'case': 'smartcase'})

function! ncm2#register_source(info) abort
  let l:name = a:info['name']

  if !has_key(a:info, 'scope')
      let a:info['scope'] = ['*']
  endif
  if !has_key(a:info, 'on_complete')
      let a:info['on_complete'] = function('asyncomplete#sources#'.l:name.'#completor')
  endif

  if !has_key(a:info, 'priority')
      let a:info['priority'] = 0
  endif

  if has_key(a:info, 'complete_pattern')
    let l:patterns = a:info['complete_pattern']

    if len(l:patterns) == 1
      let a:info['refresh_pattern'] = '\v('. l:patterns[0] . ')$'
    else
      let a:info['refresh_pattern'] = '\v('. join(l:patterns, '|') . ')$'
    endif
  endif

  if has_key(a:info, 'word_pattern')
    let l:word_pattern = '\v('. a:info['word_pattern'] . '$)'
  else
    let l:word_pattern = '\v((-?\d*\.\d\w*)|([^\`\~\!\@\#\$\%\^\&\*\(\)\-\=\+\[\{\]\}\\\|\;\:\''\"\,\.\<\>\/\?\s]+)$)'
  endif

  function! Closure(opt, ctx) closure
    let l:refresh = a:info['on_complete']
    let l:type = type(l:refresh)

    if  l:type == 1
      let l:ctx = copy(a:ctx)
      let l:match = s:matchstrpos(l:ctx['typed'], l:word_pattern)
      let l:ctx['base'] = l:match[0]
      let l:ctx['name'] = a:opt['name']
      let l:ctx['startccol'] = l:ctx['col'] - len(l:match[0])
      let l:ctx['ccol'] = l:ctx['col']

      return function(l:refresh)(l:ctx)
    elseif  l:type == 2
      let l:ctx = copy(a:ctx)
      let l:match = s:matchstrpos(l:ctx['typed'], l:word_pattern)
      let l:ctx['base'] = l:match[0]
      let l:ctx['name'] = a:opt['name']
      let l:ctx['startccol'] = l:ctx['col'] - len(l:match[0])
      let l:ctx['ccol'] = l:ctx['col']

      return l:refresh(l:ctx)
    elseif l:type==4 && has_key(l:refresh,'omnifunc')
        call s:asyncomplete_refresh_omni(a:info, a:ctx)
    endif
  endfunction

  call asyncomplete#register_source({
    \ 'name': l:name,
    \ 'priority': a:info['priority'],
    \ 'whitelist': a:info['scope'],
    \ 'completor': funcref('Closure'),
    \ 'refresh_pattern': a:info['refresh_pattern']
    \ })
endfunction

func! ncm2#complete(context, startccol, matches, ...)
  let l:args = [a:context['name'], a:context, a:startccol, a:matches] + deepcopy(a:000)
  Echos l:args
  call call('asyncomplete#complete', l:args)
endfunc


func! ncm2#file_exists(file)
  return !empty(glob(a:file))
endfunction

func! ncm2#load_plugins()
  let rtp = &rtp
  let rtp_entries = split(rtp, ',')
  for entry in rtp_entries
    let globbed_file = glob(entry . 'ncm2-plugin/*.vim')
    if !empty(globbed_file)
      try
        execute 'source ' . globbed_file
      endtry
    endif
  endfor
endfunc

func! ncm2#enable_for_buffer()
    if get(b:, 'ncm2_enable', 0)
        return
    endif
    let b:ncm2_enable = 1

    call ncm2#load_plugins()

endfunc

autocmd BufEnter * call ncm2#enable_for_buffer()
