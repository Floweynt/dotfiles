utils = require("lua_utils");

utils.noremap("in", "<C-Z>", utils.cmd_callback("undo"));
utils.noremap("in", "<C-Y>", utils.cmd_callback("redo"));
utils.noremap("nicosx", "<C-A>", utils.inject_keys("ggVG", "n"));
utils.noremap("niv", "<C-S>", function()
    utils.cmd_callback("update")()
    vim.notify("file saved", "info", {
        title = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ':t')
    });
end);

if vim.fn.has("clipboard") then
    utils.noremap("v", "<C-X>", "\"+x");
    utils.noremap("v", "<C-C>", "\"+y");
    utils.map("", "<C-V>", "\"+gP");
    utils.map("c", "<C-V>", "<C-R>+");
    utils.noremap("i", "<C-V>", utils.inject_keys( "\"+p", "n"));
end

utils.noremap("v", "<tab>", ">");
utils.noremap("t", "<esc><esc>", "<C-\\><C-n>");
utils.noremap("v", "<C-Down>", ":m '>+1<CR>gv=gv")
utils.noremap("v", "<C-Up>", ":m '<-2<CR>gv=gv");
utils.map("n", "<C-L>", "V");
utils.map("i", "<C-L>", "<Esc>V");
utils.noremap("n", "<F9>", utils.cmd_callback("UndotreeToggle"));

require("coc_keybind");
