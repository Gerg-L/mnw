{
  inputs.nixpkgs = {
    type = "github";
    owner = "NixOS";
    repo = "nixpkgs";
    ref = "nixos-unstable";
  };
  outputs =
    { self, nixpkgs }:
    let
      system = "x86_64-linux";
      inherit (nixpkgs) lib;
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      packages.${system} = {
        optionsJSON =
          (pkgs.nixosOptionsDoc {
            options =
              (lib.evalModules {
                modules = [
                  {
                    _module = {
                      args.pkgs = pkgs;
                    };
                  }
                  ../modules/common.nix
                ];
              }).options;
          }).optionsJSON;

        default =
          with pkgs;
          buildNpmPackage {
            name = "mnw-docs";
            src = ./.;
            npmDeps = importNpmLock {
              npmRoot = ./.;
            };
            npmConfigHook = importNpmLock.npmConfigHook;
            env.MNW_OPTIONS_JSON = self.packages.${system}.optionsJSON;
            # VitePress hangs if you don't pipe the output into a file
            buildPhase = ''
              local exit_status=0
              npm run build > build.log 2>&1 || {
                  exit_status=$?
                  :
              }
              cat build.log
              return $exit_status
            '';
            installPhase = ''
              mv .vitepress/dist $out
            '';
          };
      };

      devShells.${system}.default =
        with pkgs;
        mkShell {
          packages = [
            nodejs
          ];
          env.MNW_OPTIONS_JSON = self.packages.${system}.optionsJSON;
        };
    };
}
