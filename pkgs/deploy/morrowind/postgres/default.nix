{pkgs, ...}:
pkgs.writeShellScriptBin "deploy" ''
  nixos-rebuild switch --flake .#morrowind/vm/postgres --target-host morrowind-vm-pg --build-host cody@localhost --max-jobs auto
''
