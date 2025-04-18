{
  pkgs,
  lib,
  inputs,
  ...
}: {
  imports = [
    ./disk-config.nix
    ./hardware-configuration.nix
  ];

  nix.settings = {
    experimental-features = ["nix-command" "flakes"];
    substituters = ["https://hyprland.cachix.org"];
    trusted-public-keys = ["hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="];
  };

  nixpkgs = {
    overlays = [inputs.nur.overlays.default];
    config.allowUnfree = true;
  };

  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (lib.getName pkg) [
      "nvidia-x11"
      "nvidia-settings"
      "nvidia-persistenced"
      "libXNVCtrl"
      "steam"
      "steam-original"
      "steam-run"
      "cudatoolkit"
      "canon-cups-ufr2"
    ];

  networking = {
    hostName = "valenwood";
    networkmanager.enable = true;
    firewall = {
      enable = true;
      allowedTCPPorts = [22];
    };
  };

  sops = {
    age = {
      sshKeyPaths = ["/persist/etc/ssh/ssh_host_ed25519_key"];
      keyFile = "/var/lib/sops-nix/key.txt";
      generateKey = true;
    };
    secrets = {};
  };

  programs = {
    steam = {
      enable = true;
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = true;
    };
    gnupg.agent = {
      enable = true;
      enableSSHSupport = true;
    };
    zsh = {
      enable = true;
    };
    wireshark = {
      enable = true;
      package = pkgs.wireshark-qt;
    };
    ssh.startAgent = false;
    fuse.userAllowOther = true;
  };

  services = {
    openssh = {
      enable = true;
      ports = [22];
      settings = {
        PasswordAuthentication = false;
      };
      # ISSUE: https://github.com/nix-community/impermanence/issues/192
      # When using impermanence, after installing with nixos-anywhere
      # and disko, /etc/ssh/sshd_config is not generated. This prevents the
      # ssh daemon from starting, and makes it impossible to ssh into the
      # new system. Manually adding the host keys as seen below is a workaround
      # for this issue.
      hostKeys = [
        {
          type = "ed25519";
          path = "/persist/etc/ssh/ssh_host_ed25519_key";
        }
        {
          type = "rsa";
          bits = 4096;
          path = "/persist/etc/ssh/ssh_host_rsa_key";
        }
      ];
    };
    dbus.enable = true;
    printing = {
      enable = true;
      drivers = with pkgs; [
        gutenprint
        canon-cups-ufr2
      ];
      browsedConf = ''
        BrowseDNSSDSubTypes _cups,_print
        BrowseLocalProtocols all
        BrowseRemoteProtocols all
        CreateIPPPrinterQueues All

        BrowseProtocols all
      '';
    };
    avahi = {
      enable = true;
      nssmdns4 = true;
      openFirewall = true;
    };
    pipewire = {
      enable = true;
      alsa = {
        enable = true;
        support32Bit = true;
      };
      pulse.enable = true;
    };
    pcscd.enable = true; # Enable to change settings on sc, disable to use w/ gpg
    mullvad-vpn.enable = true;
    udev.packages = with pkgs; [
      yubikey-personalization
    ];
    getty.autologinUser = "cody";
  };

  environment = {
    shells = with pkgs; [zsh];
    variables = {
      EDITOR = "${pkgs.neovim}";
    };
    shellInit = ''
      gpg-connect-agent /bye
      export SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket)
    '';
  };

  fonts.packages = with pkgs; [
    nerd-fonts.fira-code
  ];

  time.timeZone = "US/Pacific";
  i18n.defaultLocale = "en_US.UTF-8";

  boot = {
    loader = {
      grub = {
        enable = true;
        devices = ["nodev"];
        efiSupport = true;
        efiInstallAsRemovable = true;
      };
    };
    # NOTE: see impermanence issue below
    initrd = {
      postDeviceCommands = lib.mkAfter ''
        mkdir /btrfs_tmp
        mount /dev/mapper/root /btrfs_tmp
        if [[ -e /btrfs_tmp/root ]]; then
            mkdir -p /btrfs_tmp/old_roots
            timestamp=$(date --date="@$(stat -c %Y /btrfs_tmp/root)" "+%Y-%m-%-d_%H:%M:%S")
            mv /btrfs_tmp/root "/btrfs_tmp/old_roots/$timestamp"
        fi

        delete_subvolume_recursively() {
            IFS=$'\n'
            for i in $(btrfs subvolume list -o "$1" | cut -f 9- -d ' '); do
                delete_subvolume_recursively "/btrfs_tmp/$i"
            done
            btrfs subvolume delete "$1"
        }

        for i in $(find /btrfs_tmp/old_roots/ -maxdepth 1 -mtime +30); do
            delete_subvolume_recursively "$i"
        done

        btrfs subvolume create /btrfs_tmp/root
        umount /btrfs_tmp
      '';
    };
  };

  hardware = {
    gpgSmartcards.enable = true;
    pulseaudio.enable = false;
    sane.enable = true;
  };

  virtualisation = {
    docker.enable = true;
    libvirtd = {
      enable = true;
      qemu.ovmf.enable = true;
      onBoot = "ignore";
      onShutdown = "shutdown";
    };
  };

  programs.dconf = {
    enable = true;
  };

  environment = {
    systemPackages = with pkgs; [
      wget
      curl
      git
      gnupg
      pass
      nix-prefetch-git
      gnumake
      bc
      killall
      age
      virtiofsd
      cups-bjnp # cups backend for canon printers
    ];
    persistence."/persist" = {
      enable = true;
      hideMounts = true;
      directories = [
        "/var/log"
        "/var/lib/bluetooth"
        "/var/lib/nixos"
        "/var/lib/sops-nix"
        "/var/lib/systemd/coredump"
        "/var/lib/libvirt"
        "/var/cache/mullvad-vpn"
        "/etc/mullvad-vpn"
        "/etc/NetworkManager/system-connections"
      ];
      files = [];
      users.cody = {
        directories = [
          {
            directory = ".ssh";
            mode = "0700";
          }
          {
            directory = ".gnupg";
            mode = "0700";
          }
          {
            directory = ".local/share/Steam";
            mode = "0700";
          }
          {
            directory = ".local/share/keyrings";
            mode = "0700";
          }
        ];
        files = [];
      };
    };
  };

  users = {
    # mutableUsers = false;
    users.cody = {
      # hashedPasswordFile = config.sops.secrets.password_hash.path;
      hashedPassword = "$y$j9T$o3IYxTwHmV1ocaOXDcNhs/$z.746YINjBuHcnEkALGK3jdUzUasNTx4f8WQpSUqyY9";
      isNormalUser = true;
      extraGroups = [
        "wheel"
        "audio"
        "video"
        "input"
        "docker"
        "libvirtd"
        "wireshark"
        "usb"
        "plugdev"
        "networkmanager"
        "scanner"
        "lp"
      ];
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHwaOrqTJ6Xq8qU3y/Vn02tHMUZJISNRA/fLAVfYCN21"
      ];
    };
    users.root = {
      initialHashedPassword = "$y$j9T$cVBuDErrQuq9PhUTj94mZ0$SNaVM8HEx1AHJgZEFvekLmhAWYm0OhDESkmfRmNLw89";
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHwaOrqTJ6Xq8qU3y/Vn02tHMUZJISNRA/fLAVfYCN21"
      ];
    };
    defaultUserShell = pkgs.zsh;
  };

  system.stateVersion = "23.05";
}
