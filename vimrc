"Personal vim config stuff

function LoadConfigScripts()
    so $HOME/.dotfiles/vim/scripts/keybind.vim
    so $HOME/.dotfiles/vim/scripts/settings.vim
    so $HOME/.dotfiles/vim/scripts/autoput.vim
    so $HOME/.dotfiles/vim/scripts/format.vim
    so $HOME/.dotfiles/vim/scripts/coc_keybind.vim
endfunction

call LoadConfigScripts()

"Terminal stuff
command Eterm :term ++curwin 

augroup remember_folds
    autocmd!
    autocmd BufWinLeave * silent!mkview
    autocmd BufWinEnter * silent! loadview
augroup END

"Nerdtree plugins and friends
let g:NERDTreeStatusline = '%#NonText#'
let g:airline_powerline_fonts = 1
let g:webdevicons_enable_nerdtree = 1
let g:webdevicons_enable_airline_statusline = 1
let g:WebDevIconsUnicodeDecorateFileNodesExtensionSymbols = {'asm': '', 'S': '', 'lds': '', 'ld': ''}
let NERDTreeShowHidden=1

"Airline
let g:airline_theme='deus'
let g:airline_powerline_fonts = 1

"Plugin shit
call plug#begin()
Plug 'mangeshrex/uwu.vim'
Plug 'neoclide/coc.nvim', {'branch': 'release'}
call plug#end()
execute pathogen#infect()

let g:lsp_cxx_hl_use_text_props = 1
"Colorscheme
colorscheme everblush
so $HOME/.dotfiles/vim/scripts/color.vim

"Filetype support
autocmd BufNewFile,BufRead *.lds set syntax=ld

set guioptions=

"Autogenerate compile-commands.json
"autocmd BufReadPre,FileReadPre,BufWritePost meson.build execute '! gen-compile-commands meson %:p:h'
"autocmd BufReadPre,FileReadPre,BufWritePost CMakeLists.txt execute '! gen-compile-commands cmake %:p:h'

"Other vim jank
"autocmd VimEnter,GUIEnter * call timer_start(69, { tid -> execute('redraw!') })

"Projects
let g:project_enable_welcome = 1
let g:project_use_nerdtree = 1
call project#rc()
let g:coc_default_semantic_highlight_groups = 1

command Reload call LoadConfigScripts()
