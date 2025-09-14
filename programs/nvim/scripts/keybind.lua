utils = require("lua_utils");

utils.noremap("in", "<C-Z>", utils.cmd_callback("undo"));
utils.noremap("in", "<C-Y>", utils.cmd_callback("redo"));
utils.noremap("nicosx", "<C-A>", "<Esc>ggVG");

local save_notif;
utils.noremap("niv", "<C-S>", function()
    utils.cmd_callback("update")()
    save_notif = vim.notify("file saved", "info", {
        title = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ':t'),
        replace = save_notif,
        on_close = function()
            save_notif = nil
        end
    });
end);

if vim.fn.has("clipboard") then
    utils.noremap("v", "<C-X>", "\"+x");
    utils.noremap("v", "c", "\"+y");
    utils.map("", "<C-V>", "\"+gP");
    utils.map("c", "<C-V>", "<C-R>+");
    utils.noremap("i", "<C-V>", "<Esc>\"+pi");
end

utils.noremap("v", "<tab>", ">");
utils.noremap("t", "<esc><esc>", "<C-\\><C-n>");
utils.noremap("v", "<C-Down>", ":m '>+1<CR>gv=gv")
utils.noremap("v", "<C-Up>", ":m '<-2<CR>gv=gv");
utils.map("n", "<C-L>", "V");
utils.map("i", "<C-L>", "<Esc>V");
utils.noremap("n", "<F9>", utils.cmd_callback("UndotreeToggle"));

require("coc_keybind");
