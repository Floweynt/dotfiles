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
require("symview");
require("latex");

vim.api.nvim_create_autocmd('FileType', {
    pattern = { '*' },
    callback = function()
        -- vimtex owns tex syntax (needed for concealment); skip treesitter for it
        if vim.bo.filetype ~= 'tex' then
            pcall(vim.treesitter.start)
        end
    end,
})

vim.filetype.add({
    extension = {
        leg = "leg",
        lds = "ld",
        vl = "systemverilog",
        v = "systemverilog"
    }
})
