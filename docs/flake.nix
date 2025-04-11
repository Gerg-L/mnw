{
  inputs = {
    nixpkgs = {
      type = "github";
      owner = "NixOS";
      repo = "nixpkgs";
      ref = "nixos-unstable";
    };
    systems = {
      type = "github";
      owner = "nix-systems";
      repo = "default";
    };
  };
  outputs =
    {
      self,
      nixpkgs,
      systems,
    }:
    let
      inherit (nixpkgs) lib;
      eachSystem = lib.genAttrs (import systems);
    in
    {
      packages = eachSystem (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        pkgs.nixosOptionsDoc {
          inherit
            (
              (lib.evalModules {
                specialArgs = { inherit pkgs; };
                modules = [
                  ../modules/options.nix
                ];
              })
            )
            options
            ;
        }
        // {
          default = pkgs.callPackage ./package.nix {
            inherit (self.packages.${pkgs.stdenv.system}) optionsJSON;
          };
        }
      );

      devShells = eachSystem (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShellNoCC {
            # use npm run dev
            packages = [
              pkgs.nodejs
            ];
            env.MNW_OPTIONS_JSON = self.packages.${system}.optionsJSON;
          };
        }
      );
    };
}
