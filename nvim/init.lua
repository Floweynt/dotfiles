local sema_syms = require "sema_syms"
vim.cmd [[packadd packer.nvim]]
require("packer").startup(function(use)
    use "wbthomason/packer.nvim";
    use "rhysd/vim-clang-format";
    use "ryanoasis/vim-devicons";
    use "liuchengxu/vista.vim";
    use "mbbill/undotree";
    use "leafoftree/vim-project";
    use {
        "mangeshrex/uwu.vim",
        commit = "1d15981"
    };
    use "tikhomirov/vim-glsl";
    use "aserebryakov/vim-todo-lists";
    use {
        "neoclide/coc.nvim",
        branch ="release",
        run = ":CocUpdate"
    };
    use "rhysd/vim-llvm";
    use "n-shift/scratch.nvim";
    use "nvim-tree/nvim-web-devicons";
    use "nvim-tree/nvim-tree.lua";
    use "folke/neodev.nvim";
    use "rcarriga/nvim-notify";
    use {
        'nvim-lualine/lualine.nvim',
        requires = { 'nvim-tree/nvim-web-devicons', opt = true }
    };
end);

vim.notify = require("notify");

require("autoput");
require("format");
require("color");
require("keybind");
require("settings");
require("util");
require("coc_notify");
require("lualine_theme");

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

vim.g["vista#renderer#icons"] = {
    func = sema_syms.func,
    ["function"] = sema_syms.func,
    functions = sema_syms.func,
    var = sema_syms.variable,
    variable = sema_syms.variable,
    variables = sema_syms.variable,
    const = sema_syms.const,
    constant = sema_syms.const,
    constructor = sema_syms.ctor,
    method = sema_syms.func,
    package = sema_syms.namespace,
    packages = sema_syms.namespace,
    enum = sema_syms.enum,
    enummember = sema_syms.enumerator,
    enumerator = sema_syms.enumerator,
    module = sema_syms.namespace,
    modules = sema_syms.namespace,
    type =  sema_syms.type,
    typedef = sema_syms.type,
    types = sema_syms.type,
    macro = "!",
    macros = "!",
    map = "!",
    class = sema_syms.type,
    augroup = "!",
    struct = sema_syms.type,
    union = sema_syms.type,
    member = sema_syms.variable,
    target = "!",
    property = sema_syms.variable,
    interface = sema_syms.type,
    namespace = sema_syms.namespace,
    subroutine = sema_syms.func,
    implementation = sema_syms.type,
    typeParameter = sema_syms.type,
    default = "?"
}

vim.g.vista_icon_indent = {"╰─▸ ", "├─▸ "};

require("color");

vim.api.nvim_create_autocmd({"BufNewFile", "BufRead"}, {
    pattern = "*.lds",
    callback = function ()
        vim.opt.syntax = "ld";
    end
})

vim.cmd([[
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



