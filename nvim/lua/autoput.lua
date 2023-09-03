utils = require("lua_utils");

function insert_text(str)
    local pos = vim.api.nvim_win_get_cursor(0)[2]
    local line = vim.api.nvim_get_current_line()
    local nline = line:sub(0, pos) .. str .. line:sub(pos + 1)
    vim.api.nvim_set_current_line(nline)
end

function do_insert(str)
    return function() insert_text(str) end;
end

for key, value in pairs({
    ["t"] = "template<typename T>",
    ["i"] = "inline constexpr"
}) do
    utils.noremap("i", "<C-P>" .. key, do_insert(value))
    utils.noremap("n", "<C-P>" .. key, do_insert(value))
end
