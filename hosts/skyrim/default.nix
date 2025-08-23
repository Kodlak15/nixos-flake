{
  pkgs,
  lib,
  config,
  ...
}: {
  imports = [
    ./disk-config.nix
    ./hardware-configuration.nix
  ];

  nix.settings = {
    experimental-features = ["nix-command" "flakes" "pipe-operators"];
    substituters = [
      "https://hyprland.cachix.org"
      "https://ghostty.cachix.org"
    ];
    trusted-public-keys = [
      "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
      "ghostty.cachix.org-1:QB389yTa6gTyneehvqG58y0WnHjQOqgnA+wBnpWWxns="
    ];
  };

  nixpkgs.config.allowUnfree = true;

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
    ];

  networking = {
    hostName = "skyrim";
    networkmanager.enable = true;
    firewall = {
      enable = true;
    };
  };

  sops = {
    age = {
      sshKeyPaths = ["/persist/etc/ssh/ssh_host_ed25519_key"];
      keyFile = "/var/lib/sops-nix/key.txt";
      generateKey = true;
    };
    secrets = {
      anthropic_api_key = {
        sopsFile = ./secrets.yaml;
        neededForUsers = true;
      };
    };
  };

  programs = {
    hyprland.enable = true;
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
    # wireshark = {
    #   enable = true;
    #   package = pkgs.wireshark-qt;
    # };
    ssh.startAgent = false; # TODO may need to delete later
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
    ollama = {
      enable = true;
      acceleration = "cuda";
    };
    open-webui = {
      enable = true;
      openFirewall = true;
      port = 8888;
      environment = {
        OLLAMA_API_BASE_URL = "http://127.0.0.1:11434";
        WEBUI_AUTH = "False";
        ENV = "dev";
        ANONYMIZED_TELEMETRY = "False";
        DO_NOT_TRACK = "True";
      };
    };
    pulseaudio.enable = false;
    dbus.enable = true;
    printing = {
      enable = true;
      drivers = with pkgs; [
        gutenprint
        # canon-cups-ufr2
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
    libinput.enable = true;
    xserver = {
      videoDrivers = ["nvidia"];
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
    blueman.enable = true;
  };

  environment = {
    shells = with pkgs; [zsh];
    variables = {
      EDITOR = "nvim";
    };
    shellInit = ''
      gpg-connect-agent /bye
      export SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket)
    '';
  };

  fonts.packages = with pkgs;
    [
      texlivePackages.lm-math
      noto-fonts-color-emoji
    ]
    ++ (builtins.filter lib.attrsets.isDerivation (builtins.attrValues pkgs.nerd-fonts));

  time.timeZone = "US/Pacific";
  i18n.defaultLocale = "en_US.UTF-8";

  boot = {
    kernelPackages = pkgs.linuxPackages_latest;
    loader = {
      grub = {
        enable = true;
        devices = ["nodev"];
        efiSupport = true;
        efiInstallAsRemovable = true;
        configurationLimit = 20;
        splashImage = ./background.jpg;
      };
    };
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
    sane.enable = true;
    nvidia = {
      modesetting.enable = true;
      powerManagement.enable = false;
      powerManagement.finegrained = false;
      open = false;
      nvidiaSettings = true;
      package = config.boot.kernelPackages.nvidiaPackages.beta;
      prime = {
        offload = {
          enable = true;
          enableOffloadCmd = true;
        };
        intelBusId = "PCI:0:2:0";
        nvidiaBusId = "PCI:1:0:0";
      };
    };
    graphics = {
      enable = true;
      enable32Bit = true;
    };
    bluetooth = {
      enable = true;
      powerOnBoot = true;
    };
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
    ];
    persistence."/persist" = {
      enable = true;
      hideMounts = true;
      directories = [
        "/var/log"
        "/var/lib"
        # "/var/lib/bluetooth"
        # "/var/lib/nixos"
        # "/var/lib/sops-nix"
        # "/var/lib/systemd/coredump"
        # "/var/lib/libvirt"
        "/var/cache/mullvad-vpn"
        "/etc/mullvad-vpn"
        "/etc/NetworkManager/system-connections"
      ];
    };
  };

  users = {
    users.cody = {
      shell = pkgs.zsh;
      # hashedPassword = "$y$j9T$o3IYxTwHmV1ocaOXDcNhs/$z.746YINjBuHcnEkALGK3jdUzUasNTx4f8WQpSUqyY9";
      hashedPassword = "$y$j9T$mNohI202LL6Mn1AdfRsNI.$J2LbLUuKbpSkpMfSVqHEQOowdNpy1OJBzgy.gE6HX59";
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
      shell = pkgs.zsh;
      # initialHashedPassword = "$y$j9T$cVBuDErrQuq9PhUTj94mZ0$SNaVM8HEx1AHJgZEFvekLmhAWYm0OhDESkmfRmNLw89";
      initialHashedPassword = "$y$j9T$8G1IlVd0y6vomYkFesWs2/$DrN1fkM7ZcLfg6DJ2yUyeHMnFbkiW3SCCAbaZ1f/yz8";
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHwaOrqTJ6Xq8qU3y/Vn02tHMUZJISNRA/fLAVfYCN21"
      ];
    };
  };

  swapDevices = [
    {
      device = "/var/lib/swapfile";
      size = 16 * 1024;
    }
  ];

  system.stateVersion = "23.05";
}
