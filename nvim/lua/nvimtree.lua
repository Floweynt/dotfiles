local api = require("nvim-tree.api");
require("nvim-tree").setup({
    sort_by = "case_sensitive",
    view = {
        width = 30
    },
    renderer = {
        group_empty = true,
        icons = {
            show = {
                git = false
            }
        }
    },
    filters = {
        dotfiles = true,
    },
});

vim.api.nvim_set_hl(0, "NvimTreeFoldername", { fg = "#67b0e8" })
vim.api.nvim_set_hl(0, "NvimTreeOpenedFolderName", { fg = "#8dc776" })
vim.api.nvim_set_hl(0, "NvimTreeIndentMarker", { fg = "#e5e5e5" });

vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
