local M = require("lualine.component"):extend()
local utils = require("lualine.utils.utils")
local highlight = require("lualine.highlight")

function M:init(options)
    M.super.init(self, options)
    self.color_cache = {}
end

--- @param color string
function M:get_color_fmt(color)
    if self.color_cache[color] == nil then
        self.color_cache[color] = self:format_hl(self:create_hl({ fg = color }, string.sub(color, 2)));
    end

    return self.color_cache[color];
end

local sema_syms = require("sema_syms");

local hi_to_syms = {
    CocSymbolArray = sema_syms.array,
    CocSymbolBoolean = sema_syms.type,
    CocSymbolClass = sema_syms.type,
    CocSymbolColor = "?",
    CocSymbolComment = sema_syms.comment,
    CocSymbolConcept = sema_syms.type,
    CocSymbolConstant = sema_syms.const,
    CocSymbolConstructor = sema_syms.ctor,
    CocSymbolDefault = "?",
    CocSymbolDeprecated = "?",
    CocSymbolEnumMember = sema_syms.enumerator,
    CocSymbolEnum = sema_syms.enum,
    CocSymbolEvent = sema_syms.type,
    CocSymbolField = sema_syms.variable,
    CocSymbolFile = "",
    CocSymbolFolder = "",
    CocSymbolFunction = sema_syms.func,
    CocSymbolInterface = sema_syms.type,
    CocSymbolKeyword = "?",
    CocSymbolKey = "?",
    CocSymbolMacro = "?",
    CocSymbolMethod = sema_syms.func,
    CocSymbolModifier = "?",
    CocSymbolModule = sema_syms.namespace,
    CocSymbolNamespace = sema_syms.namespace,
    CocSymbolNull = sema_syms.type,
    CocSymbolNumber = "?",
    CocSymbolObject = sema_syms.namespace,
    CocSymbolOperator = sema_syms.func,
    CocSymbolPackage = sema_syms.namespace,
    CocSymbolParameter = sema_syms.variable,
    CocSymbolProperty = sema_syms.variable,
    CocSymbolReference = "?",
    CocSymbolSnippet = "?",
    CocSymbolString = "",
    CocSymbolStruct = sema_syms.type,
    CocSymbolText = "?",
    CocSymbolTypeParameter = sema_syms.type,
    CocSymbolType = sema_syms.type,
    CocSymbolUnit = "?",
    CocSymbolUnknown = "?",
    CocSymbolValue = "?",
    CocSymbolVariable = sema_syms.variable,
    CocSymbolVirtual = "?"
};

function M:update_status(is_focused)
    if not is_focused then
        return '';
    end

    local fg = self:get_color_fmt("#dadada");
    local filename = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ':t')

    local icon, color = require('nvim-web-devicons').get_icon_color(filename);
    local result = {};

    if icon == nil then
        result = { " " .. (fg .. filename) }
    else
        local icon_color_str = self:get_color_fmt(color);
        result = { " " .. (icon_color_str .. icon) .. " ".. (fg .. filename)};
    end

    if not (vim.b.coc_nav == nil) then
        local crumbs = vim.b.coc_nav;

        for _, crumb in ipairs(crumbs) do
            table.insert(result, self:get_color_fmt(utils.extract_highlight_colors(crumb.highlight, "fg")) ..
                hi_to_syms[crumb.highlight] .. " " .. crumb.name)
        end
    end

    return table.concat(result, fg .. '  ')
end

return M
