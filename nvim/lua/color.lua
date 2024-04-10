utils = require("lua_utils");

local function read_all(file)
    local f = assert(io.open(file, "rb"))
    local content = f:read("*all")
    f:close()
    return content
end

local function script_path()
   local str = debug.getinfo(2, "S").source:sub(2)
   return str
end

local function load_colors()
    local f = vim.json.decode(read_all(vim.fs.dirname(script_path()) .. "/color_config.json"));
    for key, value in pairs(f) do
        vim.api.nvim_set_hl(0, key, value);
    end
end

local function font_dump()
    local tab = {};
    for key, value in pairs(vim.api.nvim_get_hl(0, { link = true })) do
        tab[key] = value;
    end

    local buf = vim.api.nvim_win_get_buf(0);
    vim.api.nvim_buf_set_lines(
        buf, -1, -1, false, {vim.json.encode(tab)}
    );
end

load_colors();

vim.api.nvim_create_user_command("ReloadColors", load_colors, {});
vim.api.nvim_create_user_command("DumpColors", font_dump, {});
