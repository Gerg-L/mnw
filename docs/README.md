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

or `import` the base of this repo which has
[flake-compat](https://github.com/edolstra/flake-compat)

Then use one of the modules or `mnw.lib.wrap`

### Wrapper function

The wrapper takes two arguments `pkgs` and then a module

```nix
let
  neovim = mnw.lib.wrap pkgs {
    # Your config
  };
  # or
  neovim = mnw.lib.wrap pkgs ./config.nix;
in {
...
```

> [!TIP]
> `mnw.lib.wrap` uses `evalModules`you can use `imports`, `options`, and
> `config`!

Then add it to `environment.systemPackages` or `users.users.<name>.packages` or
anywhere you can add a package

### Modules

Import `mnw.<module>.mnw` into your config

Where `<module>` is:

`nixosModules` for NixOS,

`darwinModules` for nix-darwin

`homeManagerModules`for home-manager

Then use the `programs.mnw` options

```nix
programs.mnw = {
  enable = true;
  #config options
};
# or
programs.mnw = ./config.nix;
```

> [!TIP]
> `programs.mnw` is a submodule you can use `imports`, `options`, and `config`!

and mnw will install the wrapped neovim to `environment.systemPackages` or
`home.packages`

Alternatively set `programs.mnw.enable = false;` and add
`config.programs.mnw.finalPackage` where you want manually

### Config Options

See the generated docs: <https://gerg-l.github.io/mnw/options.html>

### Examples

[Simple NixOS example](https://github.com/Gerg-L/mnw/tree/master/examples/nixos)

[Standalone, easy development](https://github.com/Gerg-L/mnw/tree/master/examples/easy-dev)

[My Neovim flake](https://github.com/Gerg-L/nvim-flake)

[nvf](https://github.com/notashelf/nvf)

[viperML](https://github.com/viperML/dotfiles/blob/master/packages/neovim/module.nix)

Make a PR to add your config :D
