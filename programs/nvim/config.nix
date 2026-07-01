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
            withRuby = true;
            withPython3 = true;
            initLua = builtins.readFile ./init.lua;
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
                nvim-treesitter.withAllGrammars
                hologram-nvim
                diffview-nvim
                vimtex

                # lsp
                coc-clangd
                coc-highlight
                coc-eslint
                # coc-tsserver
                coc-spell-checker
                coc-json
                coc-java
                coc-rust-analyzer
                # coc-sumneko-lua # TODO this is broken
                userPackages.coc-nav
                coc-git
                # coc-nix
                coc-pyright
            ];
            extraPackages = with clangPkgs; [
                nodejs
                tree-sitter
                nil
                nixfmt
                svls
                texlab
                zathura
                neovim-remote
                (texlive.combine { inherit (texlive) scheme-small latexmk minted fvextra; })
            ];
        };

        xdg.configFile."nvim/lua" = {
            source = ./scripts;
        };
    };
}
