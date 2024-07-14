{
  outputs =
    { self, ... }:
    {
      lib.wrap = pkgs: pkgs.callPackage "${self}/wrapper.nix" { };
    };
}
