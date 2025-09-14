local notify = require("notify");

notify.setup({
    fps = 165,
    stages = "static",
    render = "compact",
    background_colour = "FloatShadow",
    timeout = 3000,
})

vim.notify = notify;

require("autoput");
require("format");
require("color");
require("keybind");
require("settings");
require("util");
require("coc_notify");
require("lualine_theme");
require("nvimtree");
-- require("vista");
require("color");
--[[
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

require("nvim-treesitter.configs").setup({
    ensure_installed = { "cpp", "lexergen" },
    highlight = {
        enable = true,
        additional_vim_regex_highlighting = false,
        disable = { "c", "cpp" },
    },
});]]

vim.api.nvim_create_autocmd({ "BufNewFile", "BufRead" }, {
    pattern = "*.lds",
    callback = function()
        vim.opt.syntax = "ld";
    end
});

vim.filetype.add({ extension = { leg = "leg" } })

-- set termguicolors to enable highlight groups
vim.opt.termguicolors = true
