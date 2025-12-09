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

local parser_config = require("nvim-treesitter.parsers").get_parser_configs()

require("nvim-treesitter.configs").setup({
    ensure_installed = { "cpp" },
    highlight = {
        enable = true,
        additional_vim_regex_highlighting = false,
        disable = { "c", "cpp" },
    },
});

vim.api.nvim_create_autocmd({ "BufNewFile", "BufRead" }, {
    pattern = "*.lds",
    callback = function()
        vim.opt.syntax = "ld";
    end
});

vim.filetype.add({ extension = { leg = "leg" } })

-- set termguicolors to enable highlight groups
vim.opt.termguicolors = true
