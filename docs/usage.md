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

### Dev mode

To setup hot reloading for quicker neovim config iteration:

Put your config plugin in `devExcludedPlugins`,

and set `devPluginPaths` to the absolute path of the plugin.

Then you can use the `.devMode` attribute of the created neovim package!

See the examples below:

### Examples

[Simple NixOS example](https://github.com/Gerg-L/mnw/tree/master/examples/nixos)

[Standalone, easy development](https://github.com/Gerg-L/mnw/tree/master/examples/standalone)

[Lazy loading with lz.n](https://github.com/Gerg-L/mnw/tree/master/examples/lazy)

[My Neovim flake](https://github.com/Gerg-L/nvim-flake)

[nvf](https://github.com/NotAShelf/nvf)

[viperML](https://github.com/viperML/dotfiles/blob/master/packages/neovim/module.nix)

Make a PR to add your config :D
