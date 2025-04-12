/*
  This example has a devShell which allows
  you to edit your neovim configuration
  with your current config without rebuilding
  use with direnv for maximum effect
*/
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs?ref=nixos-unstable";
    mnw.url = "../../.";
    # If you're actually using this, change your input to this:
    #mnw.url = "github:Gerg-L/mnw";
  };
  outputs =
    {
      nixpkgs,
      mnw,
      self,
      ...
    }:
    let
      inherit (nixpkgs) lib;
    in
    {
      packages.x86_64-linux =
        let
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
        in
        {
          default = mnw.lib.wrap pkgs {
            neovim = pkgs.neovim-unwrapped;
            initLua = ''
              require('myconfig')
            '';
            devExcludedPlugins = [
              ./nvim
            ];
            devPluginPaths = [
              # This normally should be a absolute path
              # here it'll only work from this directory
              "./nvim"
            ];
            plugins = [ pkgs.vimPlugins.oil-nvim ];
          };
        };

      devShells.x86_64-linux.default =
        let
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
        in
        pkgs.mkShell {
          packages = [ self.packages.x86_64-linux.default.devMode ];
        };

    };
}
