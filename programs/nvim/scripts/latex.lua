-- vimtex config. treesitter is disabled for tex in init.lua so vimtex's
-- own syntax engine runs, which is required for concealment to work.

vim.g.vimtex_lsp_enabled = 0          -- texlab via coc handles LSP
vim.g.vimtex_view_method  = "zathura"
vim.g.vimtex_compiler_method = "latexmk"
vim.g.vimtex_compiler_latexmk = {
    options = {
        "-pdf",
        "-verbose",
        "-file-line-error",
        "-synctex=1",
        "-interaction=nonstopmode",
        "--shell-escape",
    },
}

vim.g.vimtex_fold_enabled = 1

-- Replace LaTeX markup with unicode equivalents inline
vim.g.vimtex_syntax_conceal = {
    accents         = 1,
    ligatures       = 1,
    cites           = 1,
    fancy           = 1,
    greek           = 1,
    math_bounds     = 1,
    math_delimiters = 1,
    math_fracs      = 0,  -- fracs rendered as a/b can be confusing
    math_super_sub  = 1,
    math_symbols    = 1,
    sections        = 0,
    spacing         = 1,
    styles          = 1,
    texTabularChar  = 1,
}

vim.api.nvim_create_autocmd("FileType", {
    pattern  = { "tex" },
    group    = vim.api.nvim_create_augroup("LatexBufSetup", { clear = true }),
    callback = function()
        vim.opt_local.conceallevel = 2
        vim.opt_local.spell        = true
        vim.opt_local.spelllang    = "en_us"
        vim.opt_local.wrap         = true
        vim.opt_local.linebreak    = true
    end,
})
