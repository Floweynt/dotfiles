local sema_syms = require "sema_syms"
vim.cmd([[packadd packer.nvim]])

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
        branch = "release",
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
    use "lukas-reineke/indent-blankline.nvim";
    use 'nvim-treesitter/nvim-treesitter';
    use { 'edluffy/hologram.nvim' };
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
require("nvimtree");
require("vista");
require("color");

local parser_config = require("nvim-treesitter.parsers").get_parser_configs()
parser_config.lexergen = {
    install_info = {
        url = "~/dev/cpp/tree-sitter-lexer-gen/",
        files = { "src/parser.c" },
        branch = "main",
        generate_requires_npm = false,
        requires_generate_from_grammar = false,
    },
    filetype = "leg",
}

require('nvim-treesitter.configs').setup({
    ensure_installed = { "cpp", "lexergen" },
    highlight = {
        enable = true,
        additional_vim_regex_highlighting = false,
        disable = {"c", "cpp"},
    },
});

vim.api.nvim_create_autocmd({ "BufNewFile", "BufRead" }, {
    pattern = "*.lds",
    callback = function()
        vim.opt.syntax = "ld";
    end
});

vim.filetype.add({ extension = { leg = "leg" } })

vim.cmd([[
autocmd User CocStatusChange redraws
autocmd User CocStatusChange redrawstatus
]]);

-- set termguicolors to enable highlight groups
vim.opt.termguicolors = true
