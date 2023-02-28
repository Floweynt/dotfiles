"Personal vim config stuff

function LoadConfigScripts()
    so $HOME/.dotfiles/vim/scripts/keybind.vim
    so $HOME/.dotfiles/vim/scripts/settings.vim
    so $HOME/.dotfiles/vim/scripts/autoput.vim
    so $HOME/.dotfiles/vim/scripts/format.vim
    so $HOME/.dotfiles/vim/scripts/coc_keybind.vim
    so $HOME/.dotfiles/vim/scripts/util.vim
endfunction

call LoadConfigScripts()

"Terminal stuff
command Eterm :term ++curwin 

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

function! NearestMethodOrFunction() abort
  return get(b:, 'vista_nearest_method_or_function', '')
endfunction

set statusline+=%{NearestMethodOrFunction()}
autocmd VimEnter * call vista#RunForNearestMethodOrFunction()

"Plugin shit
call plug#begin()
Plug 'preservim/nerdtree'
Plug 'xuyuanp/nerdtree-git-plugin'
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'
Plug 'rhysd/vim-clang-format'
Plug 'ryanoasis/vim-devicons'
Plug 'liuchengxu/vista.vim'
Plug 'mbbill/undotree'
Plug 'leafoftree/vim-project'
Plug 'mangeshrex/uwu.vim', { 'commit': '1d15981' }
Plug 'tikhomirov/vim-glsl'
Plug 'aserebryakov/vim-todo-lists'
Plug 'neoclide/coc.nvim', {'branch': 'release'}
Plug 'rhysd/vim-llvm'
call plug#end()

let g:vista#renderer#icons = {
\   "function": "\uf794",
\   "variable": "\uf71b",
\  }

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
let g:coc_default_semantic_highlight_groups = 1
call project#begin()

command Reload call LoadConfigScripts()

