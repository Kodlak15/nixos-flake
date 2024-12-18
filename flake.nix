{
  description = "https://github.com/Kodlak15 NixOS Configurations";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-24.05";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hyprland = {
      url = "git+https://github.com/hyprwm/Hyprland?submodules=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hyprland-plugins.url = "github:hyprwm/hyprland-plugins";
    hyprcursor.url = "github:hyprwm/hyprcursor";

    nur = {
      url = "github:nix-community/NUR";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    eww = {
      url = "github:elkowar/eww";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.rust-overlay.follows = "rust-overlay";
    };

    eww-configs.url = "github:Kodlak15/eww-configs";

    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko.url = "github:nix-community/disko";
    impermanence.url = "github:nix-community/impermanence";

    swwwmgr.url = "github:Kodlak15/swww-manager";
    nvim.url = "github:Kodlak15/nvim-flake";
    tweather.url = "github:Kodlak15/tweather";
  };

  outputs = {
    self,
    nixpkgs,
    nixpkgs-stable,
    home-manager,
    flake-utils,
    nur,
    disko,
    impermanence,
    ...
  } @ inputs: let
    inherit (self) outputs;
    lib = nixpkgs.lib // home-manager.lib;
    supportedSystems = ["x86_64-linux"];
    forEachSystem = f: lib.genAttrs supportedSystems (system: f pkgsFor.${system});
    pkgsFor = lib.genAttrs supportedSystems (system:
      import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      });
    pkgsForStable = lib.genAttrs supportedSystems (system:
      import nixpkgs-stable {
        inherit system;
        config.allowUnfree = true;
      });
  in {
    inherit lib;
    nixosModules = import ./modules/nixos;
    homeManagerModules = import ./modules/home-manager;
    packages = forEachSystem (pkgs: import ./pkgs {inherit pkgs;});
    devShells = forEachSystem (pkgs: import ./shells {inherit pkgs;});
    formatter = forEachSystem (pkgs: pkgs.alejandra);
    overlays = import ./overlays {inherit inputs nur;};

    nixosConfigurations = {
      "skyrim/desktop" = lib.nixosSystem {
        modules = [
          ./hosts/skyrim
          ./hosts/skyrim/desktop
        ];
        specialArgs = {inherit inputs outputs;};
      };
      "skyrim/laptop" = lib.nixosSystem {
        modules = [
          ./hosts/skyrim
          ./hosts/skyrim/laptop
          disko.nixosModules.disko
          impermanence.nixosModules.impermanence
        ];
        specialArgs = {inherit inputs outputs;};
      };
      "elsweyr" = lib.nixosSystem {
        modules = [
          "${inputs.nixpkgs}/nixos/modules/virtualisation/digital-ocean-image.nix"
          ./hosts/elsweyr
        ];
        specialArgs = {inherit inputs outputs;};
      };
      "morrowind" = lib.nixosSystem {
        modules = [
          ./hosts/morrowind
        ];
        specialArgs = {inherit inputs outputs;};
      };
      "rift" = lib.nixosSystem {
        modules = [
          ./hosts/rift
          disko.nixosModules.disko
          impermanence.nixosModules.impermanence
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.cody = import ./home/cody/rift;
            home-manager.backupFileExtension = "backup";
            home-manager.extraSpecialArgs = {
              pkgs-stable = pkgsForStable.x86_64-linux;
              inherit inputs outputs;
            };
          }
        ];
        specialArgs = {inherit inputs outputs;};
      };
      "minimal-iso" = lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
          ./custom-iso/minimal-iso
        ];
        specialArgs = {inherit inputs outputs;};
      };
      "digital-ocean-image" = lib.nixosSystem {
        modules = [
          "${inputs.nixpkgs}/nixos/modules/virtualisation/digital-ocean-image.nix"
          ./images/digital-ocean
        ];
      };
    };

    homeConfigurations = {
      "cody@skyrim/desktop" = lib.homeManagerConfiguration {
        modules = [
          ./home/cody/skyrim/common
          ./home/cody/skyrim/desktop
        ];
        pkgs = pkgsFor.x86_64-linux;
        extraSpecialArgs = {
          pkgs-stable = pkgsForStable.x86_64-linux;
          inherit inputs outputs;
        };
      };
      "cody@skyrim/laptop" = lib.homeManagerConfiguration {
        modules = [
          ./home/cody/skyrim/common
          ./home/cody/skyrim/laptop
        ];
        pkgs = pkgsFor.x86_64-linux;
        extraSpecialArgs = {
          pkgs-stable = pkgsForStable.x86_64-linux;
          inherit inputs outputs;
        };
      };
    };
  };
}
