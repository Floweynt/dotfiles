{
    clangPkgs,
    user,
    lib,
    ...
}:
{
    programs.zsh.enable = true;

    users.users."${user}".shell = clangPkgs.zsh;

    home-manager.users."${user}" = {config, ...}: {
        programs.zsh = {
            enable = true;
            package = clangPkgs.zsh;
            autocd = true;
            enableVteIntegration = true;
            history.append = true;
            dotDir = "${config.xdg.configHome}/zsh";
            oh-my-zsh = {
                enable = true;
                extraConfig = ''
                zstyle ':omz:update' mode disabled
                '';
            };
            shellAliases = {
                update = "sudo nixos-rebuild switch --flake /home/${user}/dotfiles#nix-fw16";
                cat = "bat";
                shell = "nix-shell --run $SHELL";
                develop = "nix develop --command $SHELL";
                env-c = "nix-shell --run $SHELL ${./env-c.nix}";
                env-rs = "nix-shell --run $SHELL ${./env-rs.nix}";
            };
            initContent = lib.mkAfter (builtins.readFile ./rc.zsh);
            syntaxHighlighting = {
                enable = true;
                highlighters = [
                    "main"
                    "brackets"
                    "pattern"
                    "cursor"
                    "root"
                ];
                styles = {
                    comment = "fg=black,bold";
                    alias = "fg=magenta,bold";
                };
                patterns = {
                    "rm -rf *" = "fg=white,bold,bg=red";
                };
            };
            autosuggestion = {
                enable = true;
                highlight = "fg=244";
                strategy = [
                    "history"
                    "completion"
                ];
            };
        };
    };
}
