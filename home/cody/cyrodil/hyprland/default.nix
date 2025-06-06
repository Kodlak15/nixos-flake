{
  imports = [
    ./keybinds.nix
    ./environment.nix
    ./windowRules.nix
    ./windowSettings.nix
    ./monitors.nix
    ./startup.nix
    ./animations.nix
    ./colors.nix
    ./startup.nix
    ./plugins.nix
    ./devices.nix
  ];

  wayland.windowManager.hyprland = {
    enable = true;
    xwayland.enable = true;
    systemd.enable = true;
    settings = {
      misc = {
        enable_anr_dialog = false;
      };
    };
    extraConfig = ''

      # Get rid of default wallpaper
      misc {
        disable_hyprland_logo=1
        disable_splash_rendering=1
      }

      # For all categories, see https://wiki.hyprland.org/Configuring/Variables/
      input {
          kb_layout = us
          kb_variant =
          kb_model =
          kb_options =
          kb_rules =
          follow_mouse = 1
          touchpad {
              natural_scroll = false
          }
          sensitivity = 0.25 # -1.0 - 1.0, 0 means no modification.
      }

      cursor {
        no_hardware_cursors = true
      }

      gestures {
          workspace_swipe = false
      }
    '';
  };
}
