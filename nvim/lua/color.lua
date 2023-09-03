vim.cmd("colorscheme everblush")

vim.g.terminal_ansi_colors = {
    "#f65b5b", "#e74c4c", "#6bb05d", "#e59e67", "#5b98a9", "#b185db", "#51a39f", "#c4c4c4",
    "#343636", "#c26f6f", "#8dc776", "#e7ac7e", "#7ab3c3", "#bb84e5", "#6db0ad", "#cccccc",
}

for key, value in pairs({
    ["SpecialKey"] = { fg = "#343636" },
    ["NonText"] = { fg = "#343636", bg = "NONE" },
    ["Folded"] = { bg = "#343636", fg = "#8ccf7e" },
    ["CppObjType"] = { fg = "#6cd0ca" },
    ["CocSemVariable"] = { fg = "#c4c4c4" },
    ["CocSemParameter"] = { fg = "#e5e5e5" },
    ["CocSemFunction"] = { fg = "#e57474" },
    ["CocSemMethod"] = { fg = "#e57474" },
    ["CocSemProperty"] = { fg = "#c4c4c4" },
    ["CocSemClass"] = { link = "CppObjType" },
    ["CocSemInterface"] = { link = "CppObjType" },
    ["CocSemEnum"] = { link = "CppObjType" },
    ["CocSemEnumMember"] = { fg = "#c47fd5" },
    ["CocSemType"] = { link = "CppObjType" },
    ["CocSemUnknown"] = { fg = "#e74c4c" },
    ["CocSemNamespace"] = { fg = "#6cd0ca" },
    ["CocSemTypeParameter"] = { link = "CppObjType" },
    ["CocSemConcept"] = { fg = "#e5c76b" },
    ["CocSemMacro"] = { fg = "#c47fd5" },
    ["CocSemModifier"] = { fg = "#67b0e8" },
    ["CocSemOperator"] = { fg = "#e59e67" },
    ["CocSemComment"] = { link = "cComment" },
    ["CocSemDeprecated"] = { strikethrough = true },
    ["CocSemVirtual"] = { fg = "#e57474", underline = true},
    ["Number"] = { fg = "#8ccf7e" },
    ["CocMenuSel"] = { bg = "#242626", italic = true, bold = true },
    ["CocHighlightText"] = { bg = "#343434" },
    ["CocErrorSign"] = { fg = "#e74c4c", bg = "#232a2d" },
    ["CocInfoSign"] = { fg = "#5b98a9", bg = "#232a2d" },
    ["CocHintSign"] = { fg = "#6bb05d", bg = "#232a2d" },
    ["CocWarningSign"] = { fg = "#e59e67", bg = "#232a2d" },
    ["CocGitAddedSign"] = { fg = "#8ccf7e", bg = "#232a2d" },
    ["CocGitChangeRemovedSign"] = { fg = "#c47fd5", bg = "#232a2d" },
    ["CocGitChangedSign"] = { fg = "#c47fd5", bg = "#232a2d" },
    ["CocGitRemovedSign"] = { fg = "#e57474", bg = "#232a2d" },
    ["CocGitTopRemovedSign"] = { fg = "#e57474", bg = "#232a2d" },
    ["CursorLineNr"] = { fg = "#3b4244" },
    ["MatchParen"] = { fg = "#6bb05d", bg = "#343636" },
}) do
    vim.api.nvim_set_hl(0, key, value);
end

