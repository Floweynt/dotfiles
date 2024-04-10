--- @param modes string
--- @param lhs string
--- @param rhs string|function
--- @param opts table|nil
function map_multimode(modes, lhs, rhs, opts)
    if modes:len() == 0 then
        vim.keymap.set("", lhs, rhs, opts);
        return;
    end

    for mode in modes:gmatch(".") do
        vim.keymap.set(mode, lhs, rhs, opts);
    end
end

return {
    cmd_callback = function(command) return function() vim.api.nvim_command(command) end end,
    inject_keys = function(keys, mode)
        return function()
            return vim.cmd("normal " .. keys);--[[
            return vim.api.nvim_feedkeys(
                vim.api.nvim_replace_termcodes(
                    keys,
                    true,
                    false,
                    true
                ),
                mode,
                true
            );]]
        end;
    end,
    noremap = function(modes, lhs, rhs) map_multimode(modes, lhs, rhs, { remap = false }) end,
    map = function(modes, lhs, rhs) map_multimode(modes, lhs, rhs, { remap = true }) end,
    filename = function() return vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ':t') end,
    merge_tab = function(a, b)
        local c = {}
        for k,v in pairs(a) do c[k] = v end
        for k,v in pairs(b) do c[k] = v end
        return c
    end
}
