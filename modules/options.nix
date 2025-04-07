{
  lib,
  pkgs,
  config,
  ...
}:
let
  inherit (lib) types;
  enabledOption =
    x:
    lib.mkEnableOption x
    // {
      default = true;
      example = false;
    };
  pluginsOption =
    let
      pluginType = types.submodule (
        { config, options, ... }:
        {
          freeformType = lib.types.attrsOf lib.types.anything;

          options = {
            pname = lib.mkOption {
              type = types.str;
              description = "Versionless name of plugin";
            };
            version = lib.mkOption {
              type = types.str;
              description = "Version of plugin";
            };

            name = lib.mkOption {
              type = types.str;
              description = "Name of plugin";
            };

            src = lib.mkOption {
              type = types.pathInStore;
              description = "Path in store to plugin";
            };

            outPath = lib.mkOption {
              type = types.pathInStore;
              description = "Path in store to plugin";
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

            optional = lib.mkOption {
              type = types.bool;
              description = "Wether to not load plugin automatically at startup";
              default = false;
            };

            plugin = lib.mkOption {
              apply = _: ''
                The "plugin" attribute of plugins is not supported by mnw
                please remove it from plugin: ${config.name}
              '';
            };
            config = lib.mkOption {
              apply = _: ''
                The "config" attribute of plugins is not supported by mnw
                please remove it from plugin: ${config.name}
              '';
            };
          };

          config = {
            name = lib.mkIf (options.pname.isDefined && options.version.isDefined) (
              lib.mkDefault "${config.pname}-${config.version}"
            );

            outPath = lib.mkIf options.src.isDefined (lib.mkDefault config.src);
          };
        }
      );
    in
    lib.mkOption {
      type = types.listOf (
        types.oneOf [
          (lib.mkOptionType {
            name = "path";
            description = "literal path";
            descriptionClass = "noun";
            check = builtins.isPath;
            merge = lib.mergeEqualOption;
          })
          pluginType
        ]
      );
      default = [ ];
      description = "A list of plugins to load";
      example = lib.literalExpression ''
        [
          # you can pass vimPlugins from nixpkgs
          pkgs.vimPlugins.fzf-lua

          # You can pass a directory
          # this is recommend for using your own
          # ftplugins and treesitter queries
          ./myNeovimConfig

          {
            pname = "customPlugin";
            version = "1";

            src = pkgs.fetchFromGitHub {
            owner = "";
            repo = "";
            ref = "";
            hash = "";
            };

            # Whether to place plugin in /start or /opt
            optional = false;

            # Plugins can have other plugins as dependencies
            # this is mainly used in nixpkgs
            # avoid it if possible
            dependencies = [];
          }
        ]
      '';
      apply = map (
        x:
        if builtins.isPath x then
          {
            name = "path-plugin-${builtins.substring 0 7 (builtins.hashString "md5" (toString x))}";
            python3Dependencies = _: [ ];
            outPath = x;
          }
        else
          x
      );
    };

in
{
  imports = [
    (lib.mkRemovedOptionModule [ "viAlias" ] ''
      Use 'aliases = ["vi"];' instead
    '')
    (lib.mkRemovedOptionModule [ "vimAlias" ] ''
      Use 'aliases = ["vim"];' instead
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
      description = "A function which returns a list of extra needed lua packages";
      example = lib.literalExpression ''
        ps: [ ps.jsregexp ]
      '';
    };

    devExcludedPlugins = pluginsOption // {
      description = ''
        The same as 'plugins' except for when running in dev mode
        add the absolute paths to 'devPluginPaths'
      '';
      example = lib.literalExpression ''
        [ ./gerg ]
      '';
    };

    devPluginPaths = lib.mkOption {
      type = types.listOf types.str;
      default = "";
      description = ''
        The impure absolute paths to nvim plugins
        the relative paths of which should be in devExcludedPlugins
      '';
      example = lib.literalExpression ''
        [
          "~/Projects/nvim-flake/gerg"
        ]
      '';
    };
    plugins = pluginsOption;

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

    desktopEntry = enabledOption "neovim's desktop entry";

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
        enable = enabledOption "and configure the python3 provider";
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
        enable = enabledOption "and configure the ruby provider";
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
