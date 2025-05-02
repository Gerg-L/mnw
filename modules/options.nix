docs:
{
  lib,
  pkgs,
  config,
  ...
}:
let
  inherit (lib) types;
in
{
  imports = [
    (lib.mkRemovedOptionModule [ "viAlias" ] ''
      Use 'aliases = ["vi"];' instead
    '')
    (lib.mkRemovedOptionModule [ "vimAlias" ] ''
      Use 'aliases = ["vim"];' instead
    '')
    (lib.mkRemovedOptionModule [ "devExcludedPlugins" ] ''
      Use 'plugins.dev.<name>.pure' instead
    '')
    (lib.mkRemovedOptionModule [ "devPluginPaths" ] ''
      Use 'plugins.dev.<name>.impure' instead
    '')
    (lib.mkRenamedOptionModule [ "withRuby" ] [ "providers" "ruby" "enable" ])
    (lib.mkRenamedOptionModule [ "withNodeJs" ] [ "providers" "nodeJs" "enable" ])
    (lib.mkRenamedOptionModule [ "withPerl" ] [ "providers" "perl" "enable" ])
    (lib.mkRenamedOptionModule [ "withPython3" ] [ "providers" "python3" "enable" ])
    (lib.mkRenamedOptionModule [ "extraPython3Packages" ] [ "providers" "python3" "extraPackages" ])

    (pkgs.path + "/nixos/modules/misc/assertions.nix")
  ];

  options = {
    enable = lib.mkEnableOption "mnw (Minimal Neovim Wrapper)";
    finalPackage = lib.mkOption {
      type = types.package;
      readOnly = true;
      description = "The final package to be consumed by the user";
    };

    neovim = lib.mkOption {
      type = types.package;
      default = pkgs.neovim-unwrapped;
      defaultText = lib.literalExpression "pkgs.neovim-unwrapped";
      description = "The neovim package to use. Must be unwrapped";
      example = lib.literalExpression "inputs.neovim-nightly-overlay.packages.\${pkgs.stdenv.system}.default";
    };

    appName = lib.mkOption {
      type = types.str;
      default = "mnw";
      description = "What to set $NVIM_APPNAME to";
      example = "gerg";
    };

    luaFiles = lib.mkOption {
      type = types.listOf types.pathInStore;
      default = [ ];
      description = "lua config files to load at startup";
      example = lib.literalExpression ''
        [
          (pkgs.writeText "init.lua" '''
            print('hello world')
          ''')
        ]
      '';
    };

    initLua = lib.mkOption {
      type = types.lines;
      default = "";
      description = "lua config text to load at startup";
      example = ''
        require("myConfig")
      '';
    };

    vimlFiles = lib.mkOption {
      type = types.listOf types.pathInStore;
      default = [ ];
      description = "VimL config files to load at startup";
      example = lib.literalExpression ''
        [
          (pkgs.writeText "init.vim" '''
            echomsg 'hello world'
          ''')
        ]
      '';
    };

    initViml = lib.mkOption {
      type = types.lines;
      default = "";
      description = "VimL config text to load at startup";
      example = ''
        echomsg 'hello world'
      '';
    };

    aliases = lib.mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Aliases to symlink nvim to.";
      example = lib.literalExpression ''
        [
          "vi"
          "vim"
        ]
      '';
    };

    extraLuaPackages = lib.mkOption {
      type = types.functionTo (types.listOf types.package);
      default = _: [ ];
      defaultText = lib.literalExpression "ps: [ ]";
      description = "A function which returns a list of extra needed lua packages.";
      example = lib.literalExpression ''
        ps: [ ps.jsregexp ]
      '';
    };

    plugins =
      let
        pluginType = types.submodule (
          { config, options, ... }:
          {
            freeformType = lib.types.attrsOf lib.types.anything;

            options = {
              src = lib.mkOption {
                type = types.pathInStore;
                description = "Path in store to plugin";
                default = config.outPath;
              };

              outPath = lib.mkOption {
                type = types.pathInStore;
                description = "Path in store to plugin";
                default = config.src;
              };

              dependencies = lib.mkOption {
                type = types.listOf pluginType;
                description = "Dependencies of plugin";
                default = [ ];
              };

              python3Dependencies = lib.mkOption {
                type = types.functionTo (types.listOf types.package);
                description = "A function which returns a list of extra needed python3 packages";
                default = _: [ ];
              };
            };
          }
        );

        type = types.submodule {
          options = {
            start = lib.mkOption {
              type = types.listOf pluginType;
              default = [ ];
              description = ''
                Plugins to place in /start
                (automatically loaded)
              '';
              example = lib.literalExpression "[ pkgs.vimPlugins.lz-n ]";
            };
            opt = lib.mkOption {
              type = types.listOf pluginType;
              default = [ ];
              description = ''
                Plugins to place in /opt
                (not automatically loaded)
              '';
              example = lib.literalExpression "[ pkgs.vimPlugins.oil-nvim ]";
            };
            dev = lib.mkOption {
              type = types.attrsOf (
                types.submodule {
                  options = {
                    impure = lib.mkOption {
                      type = types.path;
                      description = ''
                        The impure absolute paths to the nvim plugin.
                      '';
                      example = lib.literalExpression "/home/user/nix-config/nvim";
                    };
                    pure = lib.mkOption {
                      type = pluginType;
                      description = ''
                        The pure path to the nvim plugin.
                      '';
                      example = lib.literalExpression "./nvim";
                    };
                  };
                }
              );
              default = { };
              description = ''
                Plugins for use with devMode.
                You most likely want to put your config here.
                (automatically loaded)
              '';
              example = lib.literalExpression ''
                {
                  myconfig = {
                    impure = "/home/user/nix-config/nvim";
                    pure = ./nvim;
                  };
                }
              '';
            };
          };
        };
      in

      lib.mkOption {
        # Hack for documentation until
        # full deprecation of plugins as a list
        type =
          if docs then
            type
          else
            types.oneOf [
              type
              (types.listOf pluginType)
            ];
        apply =
          x:
          if builtins.isList x then
            (
              let
                part = builtins.partition (x: x.optional or false) x;
              in
              lib.warn
                ''
                  mnw: plugins is being used as a list, please convert to the new format:
                  plugins = {
                    start = [];
                    opt = [];
                    dev = {};
                  }
                ''
                {
                  start = part.wrong;
                  opt = part.right;
                  dev = { };
                }
            )
          else
            x;
        default = { };
        description = ''
          neovim plugins.
        '';
        example = lib.literalExpression ''
          {
            plugins = {
              # Plugins which can be reloaded without rebuilding
              # see dev mode in the docs
              dev.myconfig = {
                # This is the recommended way of passing your config
                pure = ./nvim;
                impure = "/home/user/nix-config/nvim";
              };

              # List of plugins to load automatically
              start = [
                # you can pass vimPlugins from nixpkgs
                pkgs.vimPlugins.lz-n

                # To pass a directory
                # ('plugins.dev.<name>' is preferred for directories)
                {
                  name = "plugin";
                  src = ./plugin;
                }


                # Custom plugin example
                {
                  # "pname" and "version"
                  # or "name" is required
                  pname = "customPlugin";
                  version = "1";

                  name = "customPlugin-1";

                  src = pkgs.fetchFromGitHub {
                    owner = "";
                    repo = "";
                    ref = "";
                    hash = "";
                  };

                  # Plugins can have other plugins as dependencies
                  # this is mainly used in nixpkgs
                  # avoid it if possible
                  dependencies = [];
                }
              ];

              # List of plugins to not load automatically
              # (load with packadd or a lazy loading plugin )
              opt = [
                pkgs.vimPlugins.oil-nvim
              ];
            };
          }
        '';
      };

    extraBinPath = lib.mkOption {
      type = types.listOf types.package;
      default = [ ];
      description = "Extra packages to be put in neovim's PATH";
      example = lib.literalExpression ''
        [
          pkgs.rg
          pkgs.fzf
        ]
      '';
    };

    wrapperArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "A list of arguments to be passed to makeWrapper";
      example = lib.literalExpression ''
        [
          "--set-default"
          "FZF_DEFAULT_OPTS"
          "--layout=reverse --inline-info"
        ]
      '';
    };

    desktopEntry = lib.mkEnableOption "neovim's desktop entry" // {
      default = true;
      example = false;
    };

    providers = {
      nodeJs = {
        enable = lib.mkEnableOption "and configure the Node.js provider";
        package = lib.mkOption {
          type = types.package;
          default = pkgs.nodejs;
          defaultText = lib.literalExpression "pkgs.nodejs";
          description = "The Node.js package to use.";
          example = lib.literalExpression "pkgs.nodejs_23";
        };
        neovimClientPackage = lib.mkOption {
          type = types.package;
          default = pkgs.neovim-node-client;
          defaultText = lib.literalExpression "pkgs.neovim-node-client";
          description = "The neovim-node-client package to use.";
          example = lib.literalExpression "pkgs.neovim-node-client";
        };
      };

      perl = {
        enable = lib.mkEnableOption "and configure the perl provider";
        package = lib.mkOption {
          type = types.package;
          default = pkgs.perl;
          defaultText = lib.literalExpression "pkgs.perl";
          description = "The perl package to use.";
          example = lib.literalExpression "pkgs.perl";
        };
        extraPackages = lib.mkOption {
          type = types.functionTo (types.listOf types.package);
          default = p: [
            p.NeovimExt
            p.Appcpanminus
          ];
          defaultText = lib.literalExpression ''
            p: [
              p.NeovimExt
              p.Appcpanminus
            ]
          '';
          description = ''
            Extra packages to be included in the perl environment.

            Note: you probably want to include NeovimExt and Appcpanminus if you change this from it's default value.
          '';
          example = lib.literalExpression ''
            p: [
              p.NeovimExt
              p.Appcpanminus
            ]
          '';
        };
      };

      python3 = {
        enable = lib.mkEnableOption "and configure the python3 provider";
        package = lib.mkOption {
          type = types.package;
          default = pkgs.python3;
          defaultText = lib.literalExpression "pkgs.python3";
          description = "The python3 package to use.";
          example = lib.literalExpression "pkgs.python39";
        };
        extraPackages = lib.mkOption {
          type = types.functionTo (types.listOf types.package);
          default = p: [ p.pynvim ];
          defaultText = lib.literalExpression "p: [ ppynvim ]";
          description = ''
            Extra packages to be included in the python3 environment.

            Note: you probably want to include pynvim if you change this from it's default value.
          '';
          example = lib.literalExpression ''
            py: [
              py.pynvim
              py.pybtex
            ]
          '';
        };
      };

      ruby = {
        enable = lib.mkEnableOption "and configure the ruby provider";
        package = lib.mkOption {
          type = types.package;
          default = config.providers.ruby.env.ruby;
          defaultText = lib.literalExpression "programs.mnw.providers.ruby.env.ruby";
          description = "The ruby package to use.";
          example = lib.literalExpression "pkgs.ruby";
        };
        env = lib.mkOption {
          type = types.package;
          default = pkgs.bundlerEnv {
            name = "neovim-ruby-env";
            gemdir = ../ruby_provider;
            postBuild = ''
              rm $out/bin/{bundle,bundler}
            '';
          };
          defaultText = lib.literalExpression ''
            pkgs.bundlerEnv {
              name = "neovim-ruby-env";
              gemdir = ../ruby_provider;
              postBuild = ''''
                rm $out/bin/{bundle,bundler}
              '''';
            }
          '';
          description = "The ruby bundlerEnv to use.";
          example = lib.literalExpression ''
            pkgs.bundlerEnv {
              name = "neovim-ruby-env";
              gemdir = ../ruby_provider;
            }
          '';
        };
      };
    };
  };
}
