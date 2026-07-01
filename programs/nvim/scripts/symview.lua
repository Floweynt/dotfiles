-- Symbol outline panel backed by coc.nvim documentSymbols.
-- coc returns a flat list: { text, kind (string), lnum, col, level, range, selectionRange }
-- lnum/col are 1-indexed; list is already in source order.
local M = {}
local api = vim.api
local sema_syms = require("sema_syms")

local kind_hl = {
    File          = "CocSymbolFile",
    Module        = "CocSymbolModule",
    Namespace     = "CocSymbolNamespace",
    Package       = "CocSymbolPackage",
    Class         = "CocSymbolClass",
    Method        = "CocSymbolMethod",
    Property      = "CocSymbolProperty",
    Field         = "CocSymbolField",
    Constructor   = "CocSymbolConstructor",
    Enum          = "CocSymbolEnum",
    Interface     = "CocSymbolInterface",
    Function      = "CocSymbolFunction",
    Variable      = "CocSymbolVariable",
    Constant      = "CocSymbolConstant",
    String        = "CocSymbolString",
    Number        = "CocSymbolNumber",
    Boolean       = "CocSymbolBoolean",
    Array         = "CocSymbolArray",
    Object        = "CocSymbolObject",
    Key           = "CocSymbolKey",
    Null          = "CocSymbolNull",
    EnumMember    = "CocSymbolEnumMember",
    Struct        = "CocSymbolStruct",
    Event         = "CocSymbolEvent",
    Operator      = "CocSymbolOperator",
    TypeParameter = "CocSymbolTypeParameter",
}

local kind_icon = {
    Module        = sema_syms.namespace,
    Namespace     = sema_syms.namespace,
    Package       = sema_syms.namespace,
    Class         = sema_syms.type,
    Method        = sema_syms.func,
    Property      = sema_syms.variable,
    Field         = sema_syms.variable,
    Constructor   = sema_syms.ctor,
    Enum          = sema_syms.enum,
    Interface     = sema_syms.type,
    Function      = sema_syms.func,
    Variable      = sema_syms.variable,
    Constant      = sema_syms.const,
    EnumMember    = sema_syms.enumerator,
    Struct        = sema_syms.type,
    TypeParameter = sema_syms.type,
}

local WIDTH = 40
local NS    = api.nvim_create_namespace("symview")

local st = {
    panel_buf = nil,
    panel_win = nil,
    src_buf   = nil,
    line_map  = {},
    aug       = nil,
}

local function build_entries(syms)
    local entries = {}
    for _, s in ipairs(syms) do
        local prefix = string.rep("  ", s.level or 0)
        entries[#entries + 1] = {
            text     = prefix .. (kind_icon[s.kind] or "?") .. " " .. (s.text or "?"),
            hl       = kind_hl[s.kind] or "Normal",
            hl_start = #prefix,
            lnum     = s.lnum or 0,
            col      = (s.col or 1) - 1,
        }
    end
    return entries
end

local function render(entries)
    if not st.panel_buf or not api.nvim_buf_is_valid(st.panel_buf) then return end
    local lines = {}
    st.line_map = {}
    for i, e in ipairs(entries) do
        lines[i] = e.text
        st.line_map[i] = { lnum = e.lnum, col = e.col }
    end
    api.nvim_set_option_value("modifiable", true,  { buf = st.panel_buf })
    api.nvim_buf_set_lines(st.panel_buf, 0, -1, false, lines)
    api.nvim_set_option_value("modifiable", false, { buf = st.panel_buf })
    api.nvim_buf_clear_namespace(st.panel_buf, NS, 0, -1)
    for i, e in ipairs(entries) do
        api.nvim_buf_add_highlight(st.panel_buf, NS, e.hl, i - 1, e.hl_start, -1)
    end
end

-- Fold level = leading spaces / 2, matching the indent step used above
function M.foldexpr()
    local line = vim.fn.getline(vim.v.lnum) --[[@as string]]
    return math.floor((#line - #(line:gsub("^%s*", ""))) / 2)
end

function M.refresh()
    if not st.src_buf or not api.nvim_buf_is_valid(st.src_buf) then return end
    if not st.panel_buf or not api.nvim_buf_is_valid(st.panel_buf) then return end
    -- Pass bufnr directly; coc uses it instead of querying the current buffer
    local ok, syms = pcall(vim.fn.CocAction, "documentSymbols", st.src_buf)
    if not ok or type(syms) ~= "table" or #syms == 0 then return end
    render(build_entries(syms))
end

function M.jump()
    local row = api.nvim_win_get_cursor(0)[1]
    local loc = st.line_map[row]
    if not loc then return end
    for _, w in ipairs(api.nvim_list_wins()) do
        if api.nvim_win_get_buf(w) == st.src_buf then
            api.nvim_set_current_win(w)
            api.nvim_win_set_cursor(w, { loc.lnum, loc.col })
            return
        end
    end
end

local function make_buf()
    local buf = api.nvim_create_buf(false, true)
    local set = function(k, v) api.nvim_set_option_value(k, v, { buf = buf }) end
    set("buftype",    "nofile")
    set("bufhidden",  "wipe")
    set("swapfile",   false)
    set("modifiable", false)
    api.nvim_buf_set_name(buf, "[Symbols]")
    local o = { buffer = buf, nowait = true, noremap = true, silent = true }
    vim.keymap.set("n", "<CR>", M.jump,    o)
    vim.keymap.set("n", "q",    M.close,   o)
    vim.keymap.set("n", "r",    M.refresh, o)
    return buf
end

local function make_win(buf)
    local prev = api.nvim_get_current_win()
    vim.cmd("botright " .. WIDTH .. "vsplit")
    local win = api.nvim_get_current_win()
    api.nvim_win_set_buf(win, buf)
    local set = function(k, v) api.nvim_set_option_value(k, v, { win = win }) end
    set("wrap",           false)
    set("number",         false)
    set("relativenumber", false)
    set("signcolumn",     "no")
    set("winfixwidth",    true)
    set("cursorline",     true)
    set("foldmethod",     "expr")
    set("foldexpr",       "v:lua.require('symview').foldexpr()")
    set("foldlevel",      99)
    api.nvim_set_current_win(prev)
    return win
end

local function setup_autocmds()
    if st.aug then api.nvim_del_augroup_by_id(st.aug) end
    st.aug = api.nvim_create_augroup("SymView", { clear = true })
    api.nvim_create_autocmd({ "BufWritePost", "CursorHold" }, {
        buffer   = st.src_buf,
        group    = st.aug,
        callback = M.refresh,
    })
    api.nvim_create_autocmd("BufDelete", {
        buffer   = st.src_buf,
        group    = st.aug,
        callback = M.close,
    })
    api.nvim_create_autocmd("WinClosed", {
        group    = st.aug,
        callback = function(ev)
            if tonumber(ev.match) == st.panel_win then
                st.panel_win = nil
                st.panel_buf = nil
                if st.aug then
                    api.nvim_del_augroup_by_id(st.aug)
                    st.aug = nil
                end
            end
        end,
    })
end

function M.open()
    if st.panel_win and api.nvim_win_is_valid(st.panel_win) then return end
    st.src_buf   = api.nvim_get_current_buf()
    st.panel_buf = make_buf()
    st.panel_win = make_win(st.panel_buf)
    setup_autocmds()
    M.refresh()
end

function M.close()
    if st.panel_win and api.nvim_win_is_valid(st.panel_win) then
        api.nvim_win_close(st.panel_win, true)
    end
    st.panel_win = nil
    st.panel_buf = nil
    if st.aug then
        api.nvim_del_augroup_by_id(st.aug)
        st.aug = nil
    end
end

function M.toggle()
    if st.panel_win and api.nvim_win_is_valid(st.panel_win) then
        M.close()
    else
        M.open()
    end
end

api.nvim_create_user_command("SymOpen",   M.open,   {})
api.nvim_create_user_command("SymClose",  M.close,  {})
api.nvim_create_user_command("SymToggle", M.toggle, {})

return M
