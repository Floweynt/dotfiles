"Personal vim config stuff
set tabstop=8 softtabstop=0 expandtab shiftwidth=4 smarttab
syntax on
set t_Co=256 
if &term =~ '256color'
    set t_ut=
endif
set encoding=UTF-8
set number relativenumber
set nu rnu
set guifont=JetBrains\ Mono\ Nerd\ Font\ Complete\ Mono\ 14

"Stolen from msvim
exe 'inoremap <script> <C-V> <C-G>u' . paste#paste_cmd['i']
exe 'vnoremap <script> <C-V> ' . paste#paste_cmd['v']
imap <S-Insert> <C-V>
vmap <S-Insert> <C-V>
noremap <C-Z> u
inoremap <C-Z> <C-O>u
noremap <C-Y> <C-R>
inoremap <C-Y> <C-O><C-R>
noremap <C-A> gggH<C-O>G
inoremap <C-A> <C-O>gg<C-O>gH<C-O>G
cnoremap <C-A> <C-C>gggH<C-O>G
onoremap <C-A> <C-C>gggH<C-O>G
snoremap <C-A> <C-C>gggH<C-O>G
xnoremap <C-A> <C-C>ggVG
if has("gui")
    noremap  <expr> <C-F> has("gui_running") ? ":promptfind\<CR>" : "/"
    inoremap <expr> <C-F> has("gui_running") ? "\<C-\>\<C-O>:promptfind\<CR>" : "\<C-\>\<C-O>/"
    cnoremap <expr> <C-F> has("gui_running") ? "\<C-\>\<C-C>:promptfind\<CR>" : "\<C-\>\<C-O>/"
    nnoremap <expr> <C-H> has("gui_running") ? ":promptrepl\<CR>" : "\<C-H>"
    inoremap <expr> <C-H> has("gui_running") ? "\<C-\>\<C-O>:promptrepl\<CR>" : "\<C-H>"
    cnoremap <expr> <C-H> has("gui_running") ? "\<C-\>\<C-C>:promptrepl\<CR>" : "\<C-H>"
endif
noremap <silent> <C-S> :update<CR>
vnoremap <silent> <C-S> <C-C>:update<CR>
inoremap <silent> <C-S> <C-O>:update<CR>
if has("clipboard")
    vnoremap <C-X> "+x
    vnoremap <C-C> "+y
    map <C-V> "+gP
    cmap <C-V> <C-R>+
endif
set mouse=a

"Terminal stuff
command Eterm :term ++curwin 
tnoremap <ESC><ESC> <C-\><C-n>

"Syntastic
let g:syntastic_cpp_compiler = 'clang++'
let g:syntastic_cpp_compiler_options= '-std=c++17'
let g:syntastic_cpp_check_header = 1"
let g:syntastic_cpp_checkers = ['gcc']
let g:syntastic_mode_map = { 'mode': 'passive', 'active_filetypes': [],'passive_filetypes': [] }
let g:clang_library_path='/usr/lib/libclang.so.13'
set statusline+=%#warningmsg#
set statusline+=%{SyntasticStatuslineFlag()}
set statusline+=%*
let g:syntastic_always_populate_loc_list = 1
let g:syntastic_auto_loc_list = 1
let g:syntastic_check_on_open = 1
let g:syntastic_check_on_wq = 1

"Nerdtree plugins and friends
let g:NERDTreeStatusline = '%#NonText#'
let g:NERDTreeGlyphReadOnly = "RO"
let g:airline_powerline_fonts = 1
let g:webdevicons_enable_nerdtree = 1
let g:webdevicons_enable_airline_statusline = 1
let g:WebDevIconsUnicodeDecorateFileNodesExtensionSymbols = {'asm': '', 'S': '', 'lds': '', 'ld': ''}

"Airline
let g:airline_theme='deus'
let g:airline_powerline_fonts = 1

"Plugin shit
call plug#begin()
Plug 'mangeshrex/uwu.vim'
call plug#end()
execute pathogen#infect()

"Colorscheme
colorscheme uwu
autocmd VimEnter * execute "hi MatchParen guibg=#51a39f guifg=white gui=none"
let g:terminal_ansi_colors = ['#f65b5b', '#e74c4c', '#6bb05d', '#e59e67', '#5b98a9', '#b185db', '#51a39f', '#c4c4c4', '#343636', '#c26f6f', '#8dc776', '#e7ac7e', '#7ab3c3', '#bb84e5', '#6db0ad', '#cccccc']
hi SpecialKey guifg=#343636
hi NonText guifg=#343636 guibg=NONE

"Filetype support
autocmd BufNewFile,BufRead *.lds set syntax=ld

"Autogenerate compile-commands.json
autocmd BufReadPre,FileReadPre,BufWritePost meson.build execute '! gen-compile-commands meson %:p:h'
autocmd BufReadPre,FileReadPre,BufWritePost CMakeLists.txt execute '! gen-compile-commands cmake %:p:h'

"Other vim jank
set exrc
set list
set listchars=eol:¬,space:⋅
autocmd filetype nerdtree set listchars=
autocmd VimEnter,GUIEnter * call timer_start(69, { tid -> execute('redraw!') })
autocmd VimEnter,GUIEnter * call timer_start(10000, { tid -> execute('redraw!') }, {'repeat': -1})
