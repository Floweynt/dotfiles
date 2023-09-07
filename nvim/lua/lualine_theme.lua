local everblush = {}

local colors = {
    fg = "#dadada",
    bg = "#181f21",
    black = "#22292b",
    darkbg = "#151b1d",
    red = "#e06e6e",
    green = "#8ccf7e",
    yellow = "#e5c76b",
    blue = "#67b0e8",
    magenta = "#c47fd5",
    cyan = "#6cd0ca",
    white = "#b3b9b8",

    -- different gray variants 
    light_gray = "#343636",
    gray = "#22292b",
}

everblush.normal = {
    a = { bg = colors.magenta, fg = colors.bg },
    b = { bg = colors.light_gray, fg = colors.cyan },
    c = { bg = colors.gray, fg = colors.fg },

    y = { bg = colors.light_gray, fg = colors.blue },
}

everblush.insert = {
    a = { bg = colors.green, fg = colors.bg },
    b = { bg = colors.light_gray, fg = colors.green },
    c = { bg = colors.gray, fg = colors.fg },

    y = { bg = colors.light_gray, fg = colors.blue },
}

everblush.command = {
    a = { bg = colors.blue, fg = colors.bg },
    b = { bg = colors.light_gray, fg = colors.blue },
    c = { bg = colors.gray, fg = colors.fg },

    y = { bg = colors.light_gray, fg = colors.blue },
}

everblush.visual = {
    a = { bg = colors.yellow, fg = colors.bg },
    b = { bg = colors.light_gray, fg = colors.yellow },
    c = { bg = colors.gray, fg = colors.fg },

    y = { bg = colors.light_gray, fg = colors.blue },
}

everblush.replace = {
    a = { bg = colors.red, fg = colors.bg },
    b = { bg = colors.light_gray, fg = colors.red },
    c = { bg = colors.gray, fg = colors.fg },

    y = { bg = colors.light_gray, fg = colors.blue },
}

everblush.inactive = {
    a = { bg = colors.bg, fg = colors.fg },
    b = { bg = colors.light_gray, fg = colors.fg, gui = "bold" },
    c = { bg = colors.gray, fg = colors.fg },

    y = { bg = colors.light_gray, fg = colors.fg },
}

local config = {
    options = {
        -- Disable sections and component separators
        component_separators = { left = "", right = ""},
        section_separators = { left = "", right = ""},
        theme = everblush,
    },
    disabled_filetypes = { "packer", "NvimTree" },
    sections = {
        lualine_a = { "mode" },
        lualine_b = { "branch", "diff" },
        lualine_c = { "filename" },

        lualine_x = { "diagnostics" },
        lualine_y = { "encoding", "fileformat", "filetype" },
        lualine_z = { "progress", "location" },
    },
    inactive_sections = {
        lualine_a = { "mode"},
        lualine_b = { "branch", "diff" },
        lualine_c = { "filename" },
        lualine_x = { "diagnostics" },
        lualine_y = { "encoding", "fileformat", "filetype" },
        lualine_z = { "progress", "location" },
    },
    winbar = {
        lualine_c = { require("breadcrumbs") }
    },
}

require("lualine").setup(config);
