function! s:DiagnosticNotify() abort
    let l:info = get(b:, 'coc_diagnostic_info', {})
    if empty(l:info) | return '' | endif
    let l:msgs = []
    let l:level = 'info'
     if get(l:info, 'warning', 0)
        let l:level = 'warn'
    endif
    if get(l:info, 'error', 0)
        let l:level = 'error'
    endif
 
    if get(l:info, 'error', 0)
        call add(l:msgs, 'Errors: ' . l:info['error'])
    endif
    if get(l:info, 'warning', 0)
        call add(l:msgs, 'Warnings: ' . l:info['warning'])
    endif
    if get(l:info, 'information', 0)
        call add(l:msgs, 'Infos: ' . l:info['information'])
    endif
    if get(l:info, 'hint', 0)
        call add(l:msgs, 'Hints: ' . l:info['hint'])
    endif
    let l:msg = join(l:msgs, "\n")
    if empty(l:msg) | let l:msg = ' All OK' | endif
    call v:lua.coc_diag_notify(l:msg, l:level)
endfunction

function! s:StatusNotify() abort
    let l:status = get(g:, 'coc_status', '')
    let l:level = 'info'
    if empty(l:status) | return '' | endif
    call v:lua.coc_status_notify(l:status, l:level)
endfunction

function! s:InitCoc() abort
    " load overrides
    runtime! autoload/coc/ui.vim
    execute "lua vim.notify('Initialized coc.nvim for LSP support', 'info', { title = 'LSP Status' })"
endfunction
" notifications
autocmd User CocNvimInit call s:InitCoc()
autocmd User CocDiagnosticChange call s:DiagnosticNotify()
autocmd User CocStatusChange call s:StatusNotify()
