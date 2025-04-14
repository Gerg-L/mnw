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
      pkgs.vimPlugins.oil-nvim
    ];

    devExcludedPlugins = [
      ./nvim
    ];
    devPluginPaths = [
      # This normally should be a absolute path
      # here it'll only work from this directory
      "./nvim"
    ];
  };

  # Other configuration here

  # These are dummy options to allow eval
  nixpkgs.hostPlatform = "x86_64-linux";
  boot.loader.grub.enable = false;
  fileSystems."/".device = "nodev";
  system.stateVersion = lib.trivial.release;
}
