{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs?ref=nixos-unstable";
    mnw.url = "../../.";
    # If you're actually using this, change your input to this:
    #mnw.url = "github:Gerg-L/mnw";
  };
  outputs =
    { nixpkgs, self, ... }@inputs:
    {
      nixosConfigurations.hostname = nixpkgs.lib.nixosSystem {
        modules = [ ./configuration.nix ];
        specialArgs = {
          inherit inputs;
        };
      };

      packages.x86_64-linux = {
        # "nix run"-able packages
        neovimDev = self.nixosConfigurations.hostname.config.programs.mnw.finalPackage.devMode;
        neovim = self.nixosConfigurations.hostname.config.programs.mnw.finalPackage;
      };
    };
}
