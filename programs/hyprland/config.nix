{
  clangPkgs,
  lib,
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
      configType = "lua";
      settings = {
        mainMod = { _var = "SUPER"; };

        config = {
          xwayland.force_zero_scaling = true;
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
          debug.disable_logs = false;
        };

        bind =
          let
            desktops = builtins.genList (x: builtins.toString (x + 1)) 9;
          in
          [
            { _args = [ (lib.generators.mkLuaInline ''mainMod .. " + SHIFT + return"'') (lib.generators.mkLuaInline ''hl.dsp.exec_cmd("kitty")'') ]; }
            { _args = [ (lib.generators.mkLuaInline ''mainMod .. " + p"'') (lib.generators.mkLuaInline ''hl.dsp.global("floweyshell:launcher")'') ]; }
            { _args = [ (lib.generators.mkLuaInline ''mainMod .. " + d"'') (lib.generators.mkLuaInline ''hl.dsp.global("floweyshell:dashboard")'') ]; }
            { _args = [ (lib.generators.mkLuaInline ''mainMod .. " + SHIFT + c"'') (lib.generators.mkLuaInline "hl.dsp.window.close()") ]; }
            { _args = [ (lib.generators.mkLuaInline ''mainMod .. " + SHIFT + q"'') (lib.generators.mkLuaInline "hl.dsp.exit()") ]; }
            { _args = [ (lib.generators.mkLuaInline ''mainMod .. " + t"'') (lib.generators.mkLuaInline ''hl.dsp.window.float({ action = "toggle" })'') ]; }
            { _args = [ (lib.generators.mkLuaInline ''mainMod .. " + f"'') (lib.generators.mkLuaInline "hl.dsp.window.fullscreen()") ]; }
            { _args = [ (lib.generators.mkLuaInline ''mainMod .. " + mouse:272"'') (lib.generators.mkLuaInline "hl.dsp.window.drag()") { mouse = true; } ]; }
            { _args = [ (lib.generators.mkLuaInline ''mainMod .. " + mouse:273"'') (lib.generators.mkLuaInline "hl.dsp.window.resize()") { mouse = true; } ]; }
          ]
          ++ (util.fMap desktops (id: [
            { _args = [ (lib.generators.mkLuaInline ''mainMod .. " + ${id}"'') (lib.generators.mkLuaInline ''hl.dsp.focus({ workspace = ${id} })'') ]; }
            { _args = [ (lib.generators.mkLuaInline ''mainMod .. " + SHIFT + ${id}"'') (lib.generators.mkLuaInline ''hl.dsp.window.move({ workspace = ${id} })'') ]; }
          ]));

        window_rule = [
          { match.class = "^(kitty)$"; opacity = "0.96 0.6"; }
          { match.class = "^(vesktop)$"; opacity = "0.90 0.6"; }
          { match.class = "^Minecraft.+"; tile = true; }
        ];

        monitor = {
          output = "";
          mode = "preferred";
          position = "auto";
          scale = 1;
        };

        env = {
          _args = [ "AQ_DRM_DEVICES" "/dev/dri/card2" ];
        };
      };
      package = clangPkgs.hyprland;
    };

    home.sessionVariables.NIXOS_OZONE_WL = "1";
  };
}
