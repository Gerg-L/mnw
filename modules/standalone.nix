{ pkgs, ... }:
{
  imports = [
    (pkgs.path + "/nixos/modules/misc/assertions.nix")
  ];
}
