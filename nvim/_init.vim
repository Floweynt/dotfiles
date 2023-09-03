return

"Personal vim config stuff
let s:script_path = expand('<sfile>:p:h')

function LoadConfigScripts()
    exec 'source' s:script_path . '/scripts/keybind.vim'
    exec 'source' s:script_path . '/scripts/settings.vim'
    exec 'source' s:script_path . '/scripts/autoput.vim'
    exec 'source' s:script_path . '/scripts/format.vim'
    exec 'source' s:script_path . '/scripts/coc_keybind.vim'
    exec 'source' s:script_path . '/scripts/util.vim'
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
Plug 'nvim-tree/nvim-web-devicons' " optional
Plug 'nvim-tree/nvim-tree.lua'
Plug 'folke/neodev.nvim'
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
exec 'source' s:script_path . '/scripts/color.vim'

"Filetype support
autocmd BufNewFile,BufRead *.lds set syntax=ld

set guioptions=

let g:project_enable_welcome = 1
let g:project_use_nerdtree = 1
let g:coc_default_semantic_highlight_groups = 1

command Reload call LoadConfigScripts()

exec 'source' s:script_path . '/a.lua'
autocmd User CocStatusChange redraws
autocmd User CocStatusChange redrawstatus
