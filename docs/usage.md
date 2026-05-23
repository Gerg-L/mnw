---
title: Usage
---

# {{ $frontmatter.title }}

Add the flake input

```nix
mnw.url = "github:Gerg-L/mnw";
```

or fetch this repo and then import the `default.nix`

Then use one of the [modules](#modules) or `mnw.lib.wrap`

### Wrapper function

The wrapper takes two arguments:

- A valid instance of `pkgs`. Or an attrset of `specialArgs` which must contain
  `pkgs`
- A module containing your config

```nix
mnw.lib.wrap pkgs {
  # Your config
};
```

Or if your config is a separate file

```nix
neovim = mnw.lib.wrap pkgs ./config.nix;
```

Or if you want to pass `specialArgs` to your module

```nix
neovim = mnw.lib.wrap {
  inherit inputs pkgs;
  myLib = self.lib;
} ./config.nix;
```

> [!TIP]
> `mnw.lib.wrap` uses `evalModules`, so you can use the full module system

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
> `programs.mnw` is a submodule so you can use the fully module system

and mnw will install the wrapped neovim to `environment.systemPackages` or
`home.packages`

Alternatively set `programs.mnw.enable = false;` and add
`config.programs.mnw.finalPackage` where you want manually

### Dev mode

To setup hot reloading for quicker neovim config iteration:

Put your config plugin in `plugins.dev`,

```nix
plugins = {
  dev.myconfig = {
    pure = "myconfig";
    impure = "/home/user/nix-config/nvim";
  };
};
```

Then you can use the `.devMode` attribute of the created neovim package

For example `nix shell .#neovim.devMode` or
`nix shell .#nixosConfigurations.hostname.config.programs.mnw.finalPackage.devMode`

Which allows you to make changes to your neovim config without rebuilding your
system/home-manager/neovim (you still have to restart your neovim)

See the [examples](./examples)

### Lua variables

Currently mnw only has one lua global variable set

`mnw` which is a table which contains `configDir`

Which is the path to the generated config directory of mnw

You can build/view this directory by building the `.configDir` of the mnw
package
