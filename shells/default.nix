{pkgs ? import <nixpkgs> {}, ...}: {
  imports = [
    ./rust
  ];

  default = pkgs.mkShell {
    NIX_CONFIG = "extra-experimental-features = nix-command flakes";
    nativeBuildInputs = with pkgs; [
      nix
      home-manager
      git
      gnupg
      gnumake
    ];
  };
}
