
# Minimal NeoVim Wrapper

This flake exists because the nixpkgs neovim wrapper is a pain

and I conceptually disagree with nixvim

## About

Based off the nixpkgs wrapper but:
- in one place
- more error checking
- a sane interface
- `evalModules` "type" checking
- more convenience options
- doesn't take two functions to wrap

There are no flake inputs.

## Usage

Add the flake input
```nix
mnw.url = "github:Gerg-L/mnw";
```

or `import` the base of this repo using [flake-compat](https://github.com/edolstra/flake-compat)

Then use one of the modules or `mnw.lib.wrap`

### Wrapper function
The wrapper takes two arguments `pkgs` and then an attribute set of config options

```nix
let
  neovim = mnw.lib.wrap pkgs {
    #config options
  };
in {
...
```

then add it to `environment.systemPackages` or `users.users.<name>.packages` or anywhere you can add a package

### Modules
Import `{nixosModules,darwinModules,homeManagerModules}.mnw` into your respective config

and use the `programs.mnw` options

```nix
programs.mnw = {
  enable = true;
  #config options
```

and it'll install the wrapped neovim to `environment.systemPackages` or `home.packages`

to not install by default use the `.dontInstall` module instead and add `config.programs.mnw.finalPackage` where you want


### Config Options

See the generated docs:
<https://gerg-l.github.io/mnw/options.html>



### Examples

[Simple NixOS example](https://github.com/Gerg-L/mnw/tree/master/examples/nixos)

[Standalone, easy development](https://github.com/Gerg-L/mnw/tree/master/examples/easy-dev)

[My Neovim flake](https://github.com/Gerg-L/nvim-flake)

[NotAShelf](https://github.com/notashelf/nvf)

Make a PR to add your config :D

