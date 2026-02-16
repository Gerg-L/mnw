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
      type = types.listOf types.str;
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
          defaultText = lib.literalExpression "p: [ pynvim ]";
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
    extraBuilderArgs = lib.mkOption {
      type = types.attrsOf types.anything;
      default = { };
      description = ''
        Extra attributes to pass to mkDerivation.
      '';
      example = lib.literalExpression ''
        {
          doInstallCheck = true;
          extraInstallCheckInputs = [ pkgs.hello ];
          installCheckPhase = '''
            hello
          ''';
        }
      '';
    };

    plugins =
      let
        pluginType = types.oneOf [
          types.pathInStore
          (lib.mkOptionType {
            name = "attrs with src";
            description = "attribute set with src";
            descriptionClass = "noun";
            check = x: x ? src && types.pathInStore.check x.src;
            merge = lib.mergeEqualOption;
          })
        ];

        attrsOpt = lib.mkOption {
          description = "";
          type = types.attrsOf (types.nullOr pluginType);
          default = { };
        };

        listOpt = lib.mkOption {
          description = "";
          type = types.listOf pluginType;
          default = [ ];

        };
      in
      {
        start = listOpt;
        opt = listOpt;
        startAttrs = attrsOpt;
        optAttrs = attrsOpt;

        dev = lib.mkOption {
          type = types.attrsOf (
            types.submodule {
              options = {
                impure = lib.mkOption {
                  type = types.path // {
                    check =
                      # a trimmed down version of
                      # https://github.com/NixOS/nixpkgs/blob/16762245d811fdd74b417cc922223dc8eb741e8b/lib/types.nix#L696
                      x:
                      let
                        # nixpkgs hashPrefix has a path check which will spit a warning
                        hasPrefix = pref: (builtins.substring 0 (builtins.stringLength pref) (toString x)) == pref;
                      in
                      hasPrefix "/" || hasPrefix "~/";
                  };
                  description = ''
                    The impure absolute paths to the nvim plugin.
                  '';
                  example = "/home/user/nix-config/nvim";
                };
                pure = lib.mkOption {
                  type = pluginType;

                  visible = "shallow";
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
                pure = ./nvim;
                impure = "/home/user/nix-config/nvim";
              };
            }
          '';
        };
      };
  };
  config =
    let
      transformPlugins =
        let
          recurse =
            parent: isDep:
            builtins.foldl'
              (
                acc: e:
                let
                  name = lib.removePrefix "vimplugin-" (
                    if builtins.isAttrs e then
                      lib.getName e
                    else
                      "${baseNameOf e}-${builtins.substring 0 7 (builtins.hashString "md5" "${e}")}"
                  );
                  item.${name} =
                    if builtins.isAttrs e then e // (lib.optionalAttrs isDep { __parent = parent; }) else e;
                in
                {
                  deps =
                    (if isDep then acc.deps // item else acc.deps)
                    // lib.optionalAttrs (e ? dependencies) (recurse name true e.dependencies).deps;
                  notDeps = if isDep then acc.notDeps else acc.notDeps // item;
                }
              )
              {
                deps = { };
                notDeps = { };
              };
        in
        recurse "" false;

      mkPrio = prio: builtins.mapAttrs (_: v: lib.mkOverride prio v);

      transformedOpt = transformPlugins config.plugins.opt;
      transformedStart = transformPlugins config.plugins.start;
    in
    {
      plugins = {
        /*
          optional plugin's dependencies are loaded non-optionally
          only nixpkgs plugins have dependencies though
          so it should be okay
        */
        startAttrs = lib.mkMerge [
          (mkPrio 1000 transformedStart.notDeps)
          (mkPrio 1001 transformedStart.deps)
          (mkPrio 1002 transformedOpt.deps)
        ];

        optAttrs = mkPrio 1000 transformedOpt.notDeps;
      };
      warnings = builtins.filter (x: x != null) (
        lib.mapAttrsToList (
          n: opt:
          let
            start = config.plugins.startAttrs.${n};
          in
          if start != null && (opt != null) then
            ''
              mnw: both startAttrs."${n}" and optAttrs."${n}" are defined and not null
              This will cause the plugin to be installed under /opt and /start.
              ${lib.optionalString (start ? __parent) ''startAttrs."${n}" is a dependency of ${start.__parent}''}
            ''
          else
            null
        ) (builtins.intersectAttrs config.plugins.startAttrs config.plugins.optAttrs)
      );
    };
}
