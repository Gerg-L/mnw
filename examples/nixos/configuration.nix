{
  inputs,
  pkgs,
  lib,
  ...
}:
{
  imports = [ inputs.mnw.nixosModules.default ];

  programs.mnw = {
    enable = true;
    initLua = ''
      require("myconfig")
    '';
    plugins = [
      ./nvim
      pkgs.vimPlugins.oil-nvim
    ];
  };

  # Other configuration here

  # These are dummy options to allow eval
  nixpkgs.hostPlatform = "x86_64-linux";
  boot.loader.grub.enable = false;
  fileSystems."/".device = "nodev";
  system.stateVersion = lib.trivial.release;
}
