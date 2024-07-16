{
  outputs =
    { self, ... }:
    {
      lib.wrap = pkgs: pkgs.callPackage ./wrapper.nix { };

      nixosModules = {
        default = self.nixosModules.mnw;
        noInstall = {
          imports = [
            (import ./modules/nixos.nix {
              inherit self;
              install = false;
            })
            ./modules/common.nix
          ];
        };
        mnw = {
          imports = [
            (import ./modules/nixos.nix {
              inherit self;
              install = true;
            })
            ./modules/common.nix
          ];
        };
      };

      homeManagerModules = {
        default = self.homeManagerModules.mnw;
        noInstall = {
          imports = [
            (import ./modules/homeManager.nix {
              inherit self;
              install = false;
            })
            ./modules/common.nix
          ];
        };
        mnw = {
          imports = [
            (import ./modules/homeManager.nix {
              inherit self;
              install = true;
            })
            ./modules/common.nix
          ];
        };
      };

      darwinModules = {
        default = self.darwinModules.mnw;
        noInstall = {
          imports = [
            (import ./modules/nixDarwin.nix {
              inherit self;
              install = false;
            })
            ./modules/common.nix
          ];
        };
        mnw = {
          imports = [
            (import ./modules/nixDarwin.nix {
              inherit self;
              install = true;
            })
            ./modules/common.nix
          ];
        };
      };
    };
}
