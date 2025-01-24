{
  outputs =
    { self, ... }:
    {
      lib = {
        uncheckedWrap = pkgs: pkgs.callPackage ./wrapper.nix { };
        wrap =
          pkgs: config:
          let
            inherit (pkgs) lib;
          in
          self.lib.uncheckedWrap pkgs (
            (builtins.removeAttrs
              (lib.evalModules {
                specialArgs = {
                  inherit pkgs;
                };
                modules = [
                  ./modules/common.nix
                  { programs.mnw = config; }
                ];
              }).config.programs.mnw
            )
              [
                "enable"
                "finalPackage"
              ]
          );
      };
    }
    // builtins.listToAttrs (
      map
        (x: {
          name = "${x}Modules";
          value = {
            default = self."${x}Modules";
            mnw = {
              imports = [
                (import ./modules/${x}.nix {
                  inherit self;
                  install = true;
                })
                ./modules/common.nix
              ];
            };
            noInstall = {
              imports = [
                (import ./modules/${x}.nix {
                  inherit self;
                  install = false;
                })
                ./modules/common.nix
              ];
            };
          };
        })
        [
          "nixos"
          "homeManager"
          "darwin"
        ]
    );
}
