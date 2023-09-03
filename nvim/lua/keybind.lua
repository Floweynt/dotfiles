utils = require("lua_utils");

utils.noremap("in", "<C-Z>", utils.cmd_callback("undo"));
utils.noremap("in", "<C-Y>", utils.cmd_callback("redo"));
utils.noremap("nicosx", "<C-A>", utils.inject_keys("gggH<C-O>G", "n"));
utils.noremap("niv", "<C-S>", utils.cmd_callback("update"));

if vim.fn.has("clipboard") then
    utils.noremap("v", "<C-X>", "\"+x");
    utils.noremap("v", "<C-C>", "\"+y");
    utils.map("", "<C-V>", "\"+gP");
    utils.map("c", "<C-V>", "<C-R>+");
    utils.noremap("i", "<C-V>", utils.inject_keys("n", "\"+p"));
end

utils.noremap("v", "<tab>", ">");
utils.noremap("t", "<esc><esc>", "<C-\\><C-n>");
utils.noremap("ino", "<F9>", utils.inject_keys("n", "za"));
utils.noremap("v", "<C-Down>", ":m '>+1<CR>gv=gv")
utils.noremap("v", "<C-Up>", ":m '<-2<CR>gv=gv");
utils.noremap("in", "<F9>", utils.inject_keys("n", "V"));
utils.noremap("n", "<F5>", utils.cmd_callback("UndtreeToggle"));

require("coc_keybind");
