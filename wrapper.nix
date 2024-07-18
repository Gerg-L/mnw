{
  lib,
  makeWrapper,
  nodePackages,
  python3,
  perl,
  bundlerEnv,
  ruby,
  python3Packages,
  nodejs,
  linkFarm,
  runCommand,
  buildEnv,
  writeText,
  lndir,
  stdenvNoCC,
}:
lib.makeOverridable (
  {
    neovim,
    withPython3,
    extraPython3Packages,
    withNodeJs,
    withRuby,
    withPerl,
    extraLuaPackages,
    plugins,
    viAlias,
    vimAlias,
    extraBinPath,
    wrapperArgs,
    vimlFiles,
    luaFiles,
    initViml,
    initLua,
    loadDefaultRC,
    appName,
  }:
  let
    checkedPlugins = map (
      x:
      if builtins.isPath x then
        {
          name = "plugin-${builtins.baseNameOf x}";
          outPath = x;
        }
      else
        let
          name = x.pname or x.name or "unknown";
        in
        assert lib.assertMsg (x ? name || (x ? pname && x ? version)) ''
          Either name or pname and version have to be defined for all plugins
        '';
        assert lib.assertMsg (!x ? plugin) ''
          The "plugin" attribute of plugins are not supported by mnw
          please remove it from plugin: ${name}
        '';
        assert lib.assertMsg (!x ? config) ''
          The "config" attribute of plugins is not supported by mnw
          please remove it from plugin: ${name}
        '';

        x
    ) plugins;

    splitPlugins =
      let
        partitioned = lib.partition (x: x.optional or false) checkedPlugins;
      in
      {
        start = partitioned.wrong;
        opt = partitioned.right;
      };

    allPlugins =
      let
        findDependenciesRecursively =
          let
            transitiveClosure =
              plugin: [ plugin ] ++ (lib.unique (lib.concatMap transitiveClosure plugin.dependencies or [ ]));
          in
          lib.concatMap transitiveClosure;
      in
      lib.unique (
        (findDependenciesRecursively splitPlugins.start)
        ++ (lib.subtractLists splitPlugins.opt (findDependenciesRecursively splitPlugins.opt))
      );

    allPython3Dependencies =
      ps:
      lib.pipe allPlugins [
        (lib.concatMap (plugin: (plugin.python3Dependencies or (_: [ ])) ps))
        lib.unique
      ];

    packedDir = buildEnv {
      name = "neovim-pack-dir";
      paths =
        let
          packPath = "pack/gerg-wrapper";
          vimFarm =
            name: plugins:
            linkFarm "${name}-packdir" (
              map (drv: {
                name = "${packPath}/${name}/${lib.getName drv}";
                path = drv;
              }) plugins
            );
        in
        [
          (vimFarm "start" allPlugins)
          (vimFarm "opt" splitPlugins.opt)
        ]

        ++ lib.optional (allPython3Dependencies python3.pkgs != [ ]) (
          runCommand "vim-python3-deps" { } ''
            mkdir -p $out/${packPath}/start/__python3_dependencies
            ln -s ${python3.withPackages allPython3Dependencies}/${python3.sitePackages} $out/${packPath}/start/__python3_dependencies/python3
          ''

        );
      postBuild = ''
        mkdir $out/nix-support
        for i in $(find -L $out -name propagated-build-inputs ); do
          cat "$i" >> $out/nix-support/propagated-build-inputs
        done
      '';
    };

    providers =
      let
        pythonEnv = python3Packages.python.withPackages (
          ps: lib.unique ([ ps.pynvim ] ++ (extraPython3Packages ps) ++ (allPython3Dependencies ps))
        );

        perlEnv = perl.withPackages (p: [
          p.NeovimExt
          p.Appcpanminus
        ]);
      in
      buildEnv {
        name = "neovim-providers";

        paths =
          lib.optionals withNodeJs [
            nodejs
            nodePackages.neovim
          ]
          ++ lib.optionals withRuby [
            (bundlerEnv {
              name = "neovim-ruby-env";
              gemdir = ./ruby_provider;
              postBuild = ''
                rm $out/bin/{bundle,bundler}
              '';
            })
            ruby
          ];

        nativeBuildInputs = [ makeWrapper ];

        postBuild = ''
          ${lib.optionalString withPython3 ''
            makeWrapper ${lib.getExe pythonEnv} $out/bin/neovim-python3-host \
                --unset PYTHONPATH \
                --unset PYTHONSAFEPATH
          ''}

          ${lib.optionalString withPerl "ln -s ${lib.getExe perlEnv} $out/bin/neovim-perl-host"}
        '';
      };

    wrapperArgsStr = lib.escapeShellArgs (
      let
        luaEnv = neovim.lua.withPackages extraLuaPackages;
        inherit (neovim.lua.pkgs.luaLib) genLuaPathAbsStr genLuaCPathAbsStr;
      in
      [
        "--add-flags"
        "--cmd \"luafile ${placeholder "out"}/init.lua\""

        "--prefix"
        "LUA_PATH"
        ";"
        (genLuaPathAbsStr luaEnv)

        "--prefix"
        "LUA_CPATH"
        ";"
        (genLuaCPathAbsStr luaEnv)

        "--suffix"
        "PATH"
        ":"
        (lib.makeBinPath ([ providers ] ++ extraBinPath))

        "--set-default"
        "NVIM_APPNAME"
        appName
      ]
      ++ wrapperArgs
    );

    luaConfig = writeText "init.lua" ''
      ${lib.optionalString (!loadDefaultRC)
        #Stolen from nixvim
        ''
          vim.opt.runtimepath:remove(vim.fn.stdpath('config'))              -- ~/.config/nvim
          vim.opt.runtimepath:remove(vim.fn.stdpath('config') .. "/after")  -- ~/.config/nvim/after
          vim.opt.runtimepath:remove(vim.fn.stdpath('data') .. "/site")     -- ~/.local/share/nvim/site
        ''
      }

      ${lib.concatLines (
        lib.mapAttrsToList
          (
            prog: withProg:
            if withProg then
              "vim.g.${prog}_host_prog='${providers}/bin/neovim-${prog}-host'"
            else
              "vim.g.loaded_${prog}_provider=0"
          )
          {
            node = withNodeJs;
            python = false;
            python3 = withPython3;
            ruby = withRuby;
            perl = withPerl;
          }
      )}

      ${lib.optionalString (allPlugins != [ ]) ''
        vim.opt.packpath:append('${packedDir}')
      ''}

      ${lib.concatMapStringsSep "\n" (x: "vim.cmd('source ${x}')") (
        vimlFiles ++ lib.optional (initViml != "") (writeText "init.vim" initViml)
      )}

      ${lib.concatMapStringsSep "\n" (x: "dofile('${x}')") (
        lib.optional (initLua != "") (writeText "init.lua" initLua) ++ luaFiles
      )}
    '';
  in

  stdenvNoCC.mkDerivation {
    pname = "neovim";
    version = lib.getVersion neovim;

    nativeBuildInputs = [
      makeWrapper
      lndir
    ];

    dontUnpack = true;
    strictDeps = true;

    installPhase = ''
      runHook preInstall

      mkdir -p $out

      lndir -silent ${neovim} $out

      ln -s ${luaConfig} $out/init.lua

      wrapProgram $out/bin/nvim ${wrapperArgsStr}

      ${lib.optionalString vimAlias "ln -s $out/bin/nvim $out/bin/vim"}

      ${lib.optionalString viAlias "ln -s $out/bin/nvim $out/bin/vi"}

      runHook postInstall
    '';

    meta = (builtins.removeAttrs neovim.meta [ "position" ]) // {
      # To prevent builds on hydra
      hydraPlatforms = [ ];
      # prefer wrapper over the package
      priority = (neovim.meta.priority or 0) - 1;
    };
  }
)
