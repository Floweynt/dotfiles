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

vim.api.nvim_create_autocmd('FileType', {
    pattern = { '*' },
    callback = function() pcall(vim.treesitter.start) end,
})

vim.filetype.add({ 
    extension = { 
        leg = "leg",
        lds = "ld",
        vl = "systemverilog",
        v = "systemverilog"
    }
})

-- set termguicolors to enable highlight groups
vim.opt.termguicolors = true
