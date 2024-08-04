{ inputs, pkgs, ... }:
{
  imports = [ inputs.mnw.nixosModules.default ];

  programs.mnw = {
    enable = true;
    plugins = [
      ./nvim
      pkgs.vimPlugins.oil-nvim
    ];
  };

  # Other configuration here

  # These are dummy options to allow eval
  fileSystems."/".label = "x";
  boot.loader.grub.enable = false;
  nixpkgs.hostPlatform = "x86_64-linux";
}
