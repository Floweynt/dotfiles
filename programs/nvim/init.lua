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
        local lang = vim.treesitter.language.get_lang(vim.bo.filetype)
        if lang and pcall(vim.treesitter.language.inspect, lang) then
            vim.treesitter.start()
        end
    end,
})

vim.filetype.add({
    extension = {
        leg = "leg",
        lds = "ld",
        vl = "systemverilog",
        v = "systemverilog",
        fst = "fstar"
    }
})
