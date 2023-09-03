vim.cmd [[packadd packer.nvim]]
require("packer").startup(function(use)
    use "wbthomason/packer.nvim"
    use "vim-airline/vim-airline"
    use "vim-airline/vim-airline-themes"
    use "rhysd/vim-clang-format"
    use "ryanoasis/vim-devicons"
    use "liuchengxu/vista.vim"
    use "mbbill/undotree"
    use "leafoftree/vim-project"
    use {
        "mangeshrex/uwu.vim",
        commit = "1d15981"
    }
    use "tikhomirov/vim-glsl"
    use "aserebryakov/vim-todo-lists"
    use {
        "neoclide/coc.nvim",
        branch ="release",
        run = ":CocUpdate"
    }
    use "rhysd/vim-llvm"
    use "n-shift/scratch.nvim"
    use "nvim-tree/nvim-web-devicons"
    use "nvim-tree/nvim-tree.lua"
    use "folke/neodev.nvim"
    use "rcarriga/nvim-notify"
end);

vim.notify = require("notify")

require("autoput");
require("format");
require("color")
require("keybind");
require("settings");
require("util");
require("coc_notify")

vim.g.webdevicons_enable_airline_statusline = 1;
vim.g.airline_powerline_fonts = 1;
vim.g.airline_theme = "deus";
vim.g.airline_powerline_fonts = 1;

vim.cmd([[
"vista
function! NearestMethodOrFunction() abort
  return get(b:, 'vista_nearest_method_or_function', '')
endfunction

set statusline+=%{NearestMethodOrFunction()}
autocmd VimEnter * call vista#RunForNearestMethodOrFunction()
]]);

vim.cmd([[
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
]])

require("color");

vim.cmd([["Filetype support
autocmd BufNewFile,BufRead *.lds set syntax=ld

set guioptions=

let g:project_enable_welcome = 1
let g:project_use_nerdtree = 1
let g:coc_default_semantic_highlight_groups = 1

command Reload call LoadConfigScripts()

autocmd User CocStatusChange redraws
autocmd User CocStatusChange redrawstatus
]]);

vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- set termguicolors to enable highlight groups
vim.opt.termguicolors = true

require("nvim-tree").setup({
    sort_by = "case_sensitive",
    view = {
        width = 30,
    },
    renderer = {
        group_empty = true,
        icons = {
            show = {
                git = false
            }
        }
    },
    filters = {
        dotfiles = true,
    },
});

vim.api.nvim_set_hl(0, "NvimTreeFoldername", { fg = "#67b0e8"})
vim.api.nvim_set_hl(0, "NvimTreeOpenedFolderName", { fg = "#8dc776"})
vim.api.nvim_set_hl(0, "NvimTreeIndentMarker", { fg = "#e5e5e5"})



