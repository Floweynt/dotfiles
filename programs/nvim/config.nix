{
    clangPkgs,
    user,
    userPackages,
    ...
}:
{
    home-manager.users."${user}" = {
        programs.neovim = {
            enable = true;
            package = clangPkgs.neovim-unwrapped;
            extraLuaConfig = builtins.readFile ./init.lua;
            viAlias = true;
            vimAlias = true;
            defaultEditor = true;
            coc = {
                enable = true;
                pluginConfig = builtins.readFile ./coc-plugin-config.vim;
                settings = builtins.fromJSON (builtins.readFile ./coc-settings.json);
            };
            plugins = with clangPkgs.vimPlugins; [
                vim-clang-format
                vim-devicons
                # vista-vim
                undotree
                vim-glsl
                vim-llvm
                nvim-web-devicons
                nvim-tree-lua
                neodev-nvim
                nvim-notify
                lualine-nvim
                indent-blankline-nvim
                nvim-treesitter
                hologram-nvim
                diffview-nvim

                # lsp
                coc-clangd
                coc-highlight
                coc-eslint
                coc-tsserver
                coc-spell-checker
                coc-json
                coc-java
                coc-sumneko-lua
                # userPackages.coc-nav #TODO package this myself
                coc-git
                # coc-nix
                coc-pyright
            ];
        };

        xdg.configFile."nvim/lua" = {
            source = ./scripts;
        };
    };
}
