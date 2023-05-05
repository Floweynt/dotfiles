"Personal vim config stuff

function LoadConfigScripts()
    so $HOME/.dotfiles/nvim/scripts/keybind.vim
    so $HOME/.dotfiles/nvim/scripts/settings.vim
    so $HOME/.dotfiles/nvim/scripts/autoput.vim
    so $HOME/.dotfiles/nvim/scripts/format.vim
    so $HOME/.dotfiles/nvim/scripts/coc_keybind.vim
    so $HOME/.dotfiles/nvim/scripts/util.vim
endfunction

call LoadConfigScripts()

"Nerdtree plug
let g:NERDTreeStatusline = '%#NonText#'
let g:webdevicons_enable_nerdtree = 1
let g:webdevicons_enable_airline_statusline = 1
let g:WebDevIconsUnicodeDecorateFileNodesExtensionSymbols = {'asm': '', 'S': '', 'lds': '', 'ld': ''}
let NERDTreeShowHidden=1
let g:NERDTreeDirArrowExpandable = ''
let g:NERDTreeDirArrowCollapsible = ''

"Airline
let g:airline_powerline_fonts = 1
let g:airline_theme='deus'
let g:airline_powerline_fonts = 1

"vista
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
Plug 'n-shift/scratch.nvim'
call plug#end()

let g:vista#renderer#icons = {
\    'func': "",
\    'function': "",
\    'functions': "",
\    'var': "",
\    'variable': "",
\    'variables': "",
\    'const': "",
\    'constant': "",
\    'constructor': "",
\    'method': "",
\    'package': "",
\    'packages': "",
\    'enum': "",
\    'enummember': "",
\    'enumerator': "",
\    'module': "",
\    'modules': "",
\    'type': "",
\    'typedef': "",
\    'types': "",
\    'field': "",
\    'fields': "",
\    'macro': "!",
\    'macros': "!",
\    'map': "!",
\    'class': "",
\    'augroup': "!",
\    'struct': "",
\    'union': "",
\    'member': "",
\    'target': "!",
\    'property': "",
\    'interface': "!",
\    'namespace': "",
\    'subroutine': "!",
\    'implementation': "!",
\    'typeParameter': "!",
\    'default': "?"
\} 
let g:vista_icon_indent = ["╰─▸ ", "├─▸ "]

"Colorscheme
colorscheme everblush
so $HOME/.dotfiles/nvim/scripts/color.vim

"Filetype support
autocmd BufNewFile,BufRead *.lds set syntax=ld

set guioptions=

let g:project_enable_welcome = 1
let g:project_use_nerdtree = 1
let g:coc_default_semantic_highlight_groups = 1

command Reload call LoadConfigScripts()

