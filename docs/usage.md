---
title: Usage
---
# {{ $frontmatter.title }}

Add the flake input

```nix
mnw.url = "github:Gerg-L/mnw";
```

or `import` the base of this repo which has
[flake-compat](https://github.com/edolstra/flake-compat)

Then use one of the modules or `mnw.lib.wrap`

### Wrapper function

The wrapper takes two arguments:
- a valid instance of `pkgs` or a set of specialArgs, passed to the module
  - the set must contain the aforementioned `pkgs` (to be used by the
    wrapper)!
  - the set can contain extra specialArgs you might need in the module (such
    as functions, collections of such, npins/niv pins, etc)
- a module, containing your setup

```nix
let
  neovim = mnw.lib.wrap pkgs {
    # Your config
  };

  # or, if your config is a separate file
  neovim = mnw.lib.wrap pkgs ./config.nix;

  # or, if you need extra specialArgs in your module
  neovim = mnw.lib.wrap {
    inherit inputs pkgs;
    myLib = self.lib;
  } ./config.nix;
in {
...
```

> [!TIP]
> `mnw.lib.wrap` uses `evalModules`, so you can use `imports`, `options`, and
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

Put your config plugin in `plugins.dev`,

Then you can use the `.devMode` attribute of the created neovim package!

See the examples below:

### Lua variables

Currently mnw only has one lua global variable set

`mnw` which is a table which contains `configDir`

Which is the path to the generated config directory of mnw

You can build/view this directory by building the `.configDir` of the mnw package
