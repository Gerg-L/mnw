
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

or `import` the base of this repo using

to use [flake-compat](https://github.com/edolstra/flake-compat)

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
#other config
```

and it'll install the wrapped neovim to `environment.systemPackages` or `home.packages`

to not install by default use the `.dontInstall` module instead and add `config.programs.mnw.finalPackage` where you want


### Config Options

```nix
# The neovim package to wrap
# Ensure you're using the -unwrapped variant
neovim = pkgs.neovim-unwrapped;

#
# These are all put into a generated init.lua
#

# Lua files
luaFiles = [ ];
# Lua string
initLua = ''
  require("myConfig")
'';
# Vimscript files
vimlFiles = [ ];
# Vimscript string
initViml = "";

plugins = [
  # you can pass vimPlugins from nixpkgs
  pkgs.vimPlugins.fzf-lua
  # You can pass a directory
  # this is recommend for using your own
  # ftplugins and treesitter queries
  ./myNeovimConfig
];
# I recommend using plugins from a npins source
# to track the newest commits of a plugin
# check my config for an example

# Lsps and fzf/rg go here and get appended to PATH
extraBinPath = [ pkgs.nil ];

# Sets NVIMAPP_NAME
appName = "mnw";

# Extra arguments passed to makeWrapper
wrapperArgs = [ ];

# Symlink vi/vim to nvim
viAlias = false;
vimAlias = false;

# Setup and enable providers
withRuby = true;
withNodeJs = false;
withPerl = false;
withPython3 = true;
extraPython3Packages = p: [ ];

# Extra luaPackages which may be needed by plugins
extraLuaPackages = _: [ ];

```

### Full usage examples

[Mine](https://github.com/Gerg-L/nvim-flake)

[NotAShelf](https://github.com/notashelf/nvf)

If you would like your example here PR it
