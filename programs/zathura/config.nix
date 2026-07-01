{ user, ... }:
{
    home-manager.users."${user}" = {
        xdg.configFile."zathura/zathurarc".text = ''
            set synctex true
            # nvr finds the running neovim instance automatically
            set synctex-editor-command "nvr --remote-silent +%{line} %{input}"
            set selection-clipboard clipboard
            set adjust-open width
        '';
    };
}
