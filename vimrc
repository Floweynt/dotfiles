"Personal vim config stuff
set tabstop=8 softtabstop=0 expandtab shiftwidth=4 smarttab
syntax on

set t_Co=256 "sets vim to 256 color
if &term =~ '256color'
    set t_ut=
endif
set encoding=UTF-8

set number relativenumber
set nu rnu

noremap <silent> <C-S> :update<CR>
vnoremap <silent> <C-S> <C-C>:update<CR>
inoremap <silent> <C-S> <C-O>:update<CR>

vnoremap <C-X> "+x
vnoremap <C-C> "+y
map <C-V>      "+gP

autocmd VimEnter * execute "hi MatchParen guibg=#51a39f guifg=white gui=none"
autocmd VimEnter * execute "redraw"

set mouse=a

let g:pathogen_disabled = ['vim-devicons', 'vim-nerdtree-syntax-highlight']

"Syntastic
let g:syntastic_cpp_compiler = 'clang++'
let g:syntastic_cpp_compiler_options = '-std=c++2a'
let g:syntastic_cpp_check_header = 1"
let g:syntastic_cpp_checkers = ['check']
let g:clang_library_path='/usr/lib/libclang.so.13.0.0'
set statusline+=%#warningmsg#
set statusline+=%{SyntasticStatuslineFlag()}
set statusline+=%*
let g:syntastic_always_populate_loc_list = 1
let g:syntastic_auto_loc_list = 1
let g:syntastic_check_on_open = 1
let g:syntastic_check_on_wq = 1

"Nerdtree plugins and friends
let g:NERDTreeStatusline = '%#NonText#'
let g:airline_powerline_fonts = 1
let g:webdevicons_enable_nerdtree = 1
let g:webdevicons_enable_airline_statusline = 1
let g:WebDevIconsUnicodeDecorateFileNodesExtensionSymbols = {} " needed
let g:WebDevIconsUnicodeDecorateFileNodesExtensionSymbols['asm'] = ''
let g:WebDevIconsUnicodeDecorateFileNodesExtensionSymbols['S'] = ''
let g:WebDevIconsUnicodeDecorateFileNodesExtensionSymbols['lds'] = ''
let g:WebDevIconsUnicodeDecorateFileNodesExtensionSymbols['ld'] = ''
let WebDevIconsUnicodeDecorateFileNodesExactSymbols = {}
let g:WebDevIconsUnicodeDecorateFileNodesExactSymbols['meson.build'] = ''

set guifont=JetBrains\ Mono\ Nerd\ Font\ Complete\ Mono\ 14

"Airline
let g:airline_theme='deus'
let g:airline_powerline_fonts = 1

" uwu theme
call plug#begin()
Plug 'mangeshrex/uwu.vim'
call plug#end()
colorscheme uwu

"Filetype support
autocmd BufNewFile,BufRead *.lds set syntax=ld

"Autogenerate compile-commands.json
autocmd BufReadPre,FileReadPre,BufWritePost meson.build execute '! gen-compile-commands meson %:p:h'
autocmd BufReadPre,FileReadPre,BufWritePost CMakeLists.txt execute '! gen-compile-commands cmake %:p:h'

execute pathogen#infect()
redraw!
