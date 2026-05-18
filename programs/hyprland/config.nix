{
  clangPkgs,
  user,
  util,
  ...
}:
{
  programs.hyprland.enable = true;

  home-manager.users."${user}" = {
    services.hyprpaper = {
      enable = true;
      package = clangPkgs.hyprpaper;
      settings = {
        ipc = "on";
        splash = false;
        splash_offset = 2;
        wallpaper = [
          {
            monitor = "";
            path = "${./bg.png}";
          }
        ];
      };
    };
    wayland.windowManager.hyprland = {
      enable = true;
      settings = {
        "$mainMod" = "SUPER";
        xwayland = {
          force_zero_scaling = true;
        };
        ecosystem = {
          no_update_news = true;
          no_donation_nag = true;
        };
        general = {
          gaps_in = 5;
          gaps_out = 10;
        };
        decoration = {
          rounding = 6;
          rounding_power = 2;
        };
        bind =
          let
            desktops = builtins.genList (x: builtins.toString (x + 1)) 9;
          in
          [
            "$mainMod SHIFT, return, exec, kitty"
            "$mainMod, p, global, floweyshell:launcher"
            "$mainMod, d, global, floweyshell:dashboard"
            "$mainMod SHIFT, c, killactive,"
            "$mainMod SHIFT, q, exit,"
            "$mainMod, t, togglefloating,"
            "$mainMod, f, fullscreen"
          ]
          ++ (util.fMap desktops (id: [
            "$mainMod, ${id}, workspace, ${id}"
            "$mainMod SHIFT, ${id}, movetoworkspace, ${id}"
          ]));
        debug = {
          disable_logs = false;
        };
        bindm = [
          "$mainMod, mouse:272, movewindow"
          "$mainMod, mouse:273, resizewindow"
        ];
        windowrule = [
          "match:class ^(kitty)$, opacity 0.96 0.6"
          "match:class ^(vesktop)$, opacity 0.90 0.6"
          "match:class ^Minecraft.+, tile on"
        ];
        monitor = ",preferred,auto,1";
        env = "AQ_DRM_DEVICES,/dev/dri/card2";
        exec-once = [
          # polkit agent is now handled by quickshell's built-in PolkitAuth
        ];
      };
      package = clangPkgs.hyprland;
    };

    home.sessionVariables.NIXOS_OZONE_WL = "1";
  };
}
