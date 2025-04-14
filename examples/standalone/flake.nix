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

          dev = self.packages.x86_64-linux.default.devMode;
        };
    };
}
