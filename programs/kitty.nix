{
  clangPkgs,
  user,
  ...
}:
{
  home-manager.users."${user}".programs.kitty = {
    enable = true;
    package = clangPkgs.kitty;
    shellIntegration.enableZshIntegration = true;
    settings = {
      font_family = "JetBrainsMono Nerd Font Mono";
      bold_font = "JetBrainsMono NFM ExtraBold";
      bold_italic_font = "JetBrainsMono NFM ExtraBold Italic";
      font_size = 14;
      sync_to_monitor = true;
      enable_audio_bell = false;
      window_padding_width = 3; # maybe increase if i want rounded corners
      foreground = "#c5c8c9";
      background = "#131A1C";
      cursor = "#808080";
      color0 = "#131A1C";
      color1 = "#e74c4c";
      color2 = "#6bb05d";
      color3 = "#e59e67";
      color4 = "#5b98a9";
      color5 = "#b185db";
      color6 = "#51a39f";
      color7 = "#c4c4c4";
      color8 = "#343636";
      color9 = "#c26f6f";
      color10 = "#8dc776";
      color11 = "#e7ac7e";
      color12 = "#7ab3c3";
      color13 = "#bb84e5";
      color14 = "#6db0ad";
      color15 = "#cccccc ";
      selection_foreground = "#131A1C";
      selection_background = "#232a2c";
      tab_bar_edge = "bottom";
      tab_bar_style = "powerline";
      tab_separator = "|";
      active_tab_foreground = "#E182E0";
      active_tab_background = "#1b2224";
      inactive_tab_foreground = "#CD69CC";
      inactive_tab_background = "#232a2c";
      active_tab_font_style = "italic";
      update_check_interval = 0;
      touch_scroll_multiplier = 10.0;
      momentum_scroll = 0;
      auto_reload_config = -1;
    };
  };
}
