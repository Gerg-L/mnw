{
  lib,
  makeBinaryWrapper,
  linkFarm,
  runCommand,
  buildEnv,
  writeText,
  lndir,
  stdenvNoCC,
  envsubst,
  callPackage,
  makeSetupHook,
  writeShellScriptBin,
}@callPackageArgs:
lib.makeOverridable (
  {
    neovim,
    extraLuaPackages,
    plugins,
    aliases,
    extraBinPath,
    wrapperArgs,
    vimlFiles,
    luaFiles,
    initViml,
    initLua,
    appName,
    desktopEntry,
    providers,
    devExcludedPlugins,
    devPluginPaths,
    dev ? false,
    extraCheckHooks,
    ...
  # ^This is needed because of the renamed options
  # remove when they are removed
  }@mnwWrapperArgs:
  let
    python3 = providers.python3.package;

    splitPlugins = lib.partition (x: x.optional or false) (
      plugins ++ lib.optionals (!dev) devExcludedPlugins
    );

    optPlugins = splitPlugins.right;

    startPlugins =
      let
        /*
          Stolen from viperML

          Can't call lib.unique here because of module system errors
          about the same speed as using concatMap but removes a let in
        */
        findDeps = builtins.foldl' (
          x: y:
          builtins.concatLists [
            x
            [
              y
            ]
            (findDeps (y.dependencies or [ ]))
          ]
        ) [ ];
      in
      /*
        Gross edge case of optional plugin's
        dependency being loaded non-optionally
        only nixpkgs plugins have dependencies though
        so it should be okay
      */
      lib.subtractLists optPlugins ((findDeps splitPlugins.wrong) ++ (findDeps optPlugins));

    allPython3Dependencies =
      ps:
      lib.pipe startPlugins [
        (lib.concatMap (plugin: (plugin.python3Dependencies or (_: [ ])) ps))
        lib.unique
      ];
    generatedInitLua =
      let
        luaEnv = neovim.lua.withPackages extraLuaPackages;
        inherit (neovim.lua.pkgs) luaLib;

        devRtp = lib.optionalString (dev && devPluginPaths != [ ]) ''
          vim.opt.runtimepath:prepend('${lib.concatStringsSep "," devPluginPaths}')
          vim.opt.runtimepath:append('${lib.concatMapStringsSep "," (p: "${p}/after") devPluginPaths}')
        '';

        providerLua =
          lib.pipe
            {
              node = providers.nodeJs.enable;
              python = false;
              python3 = providers.python3.enable;
              ruby = providers.ruby.enable;
              perl = providers.perl.enable;
            }
            [
              (builtins.mapAttrs (
                prog: withProg:
                if withProg then
                  "vim.g.${prog}_host_prog='${providersEnv}/bin/neovim-${prog}-host'"
                else
                  "vim.g.loaded_${prog}_provider=0"
              ))
              builtins.attrValues
              lib.concatLines
            ];

        sourceLua = lib.concatMapStringsSep "\n" (x: "dofile('${x}')") (
          (lib.optional (initLua != "") (writeText "init.lua" initLua)) ++ luaFiles
        );
        sourceVimL = lib.concatMapStringsSep "\n" (x: "vim.cmd('source ${x}')") (
          (lib.optional (initViml != "") (writeText "init.vim" initViml)) ++ vimlFiles
        );
      in
      writeText "init.lua" ''
        vim.env.PATH =  vim.env.PATH .. ":${lib.makeBinPath ([ providersEnv ] ++ extraBinPath)}"
        package.path = "${luaLib.genLuaPathAbsStr luaEnv};$LUA_PATH" .. package.path
        package.cpath = "${luaLib.genLuaCPathAbsStr luaEnv};$LUA_CPATH" .. package.cpath
        vim.opt.packpath:append('$out')
        vim.opt.runtimepath:append('$out')
        ${devRtp}
        ${providerLua}
        ${sourceLua}
        ${sourceVimL}
      '';

    builtConfigDir = buildEnv {
      name = "neovim-pack-dir";

      nativeBuildInputs = [ envsubst ];

      paths =
        let
          vimFarm =
            name: plugins:
            linkFarm "${name}-configdir" (
              map (drv: {
                name = "pack/mnw/${name}/${
                  if (drv ? pname && (builtins.tryEval drv.pname).success) then drv.pname else drv.name
                }";
                path = drv;
              }) plugins
            );
        in
        [
          (vimFarm "start" startPlugins)
          (vimFarm "opt" optPlugins)
        ]
        ++ lib.optional (allPython3Dependencies python3.pkgs != [ ]) (
          runCommand "vim-python3-deps" { } ''
            mkdir -p $out/pack/mnw/start/__python3_dependencies
            ln -s ${python3.withPackages allPython3Dependencies}/${python3.sitePackages} $out/pack/mnw/start/__python3_dependencies/python3
          ''
        );
      postBuild = ''
        mkdir $out/nix-support
        for i in $(find -L $out -name propagated-build-inputs ); do
          cat "$i" >> $out/nix-support/propagated-build-inputs
        done

        # Semi-cursed helptag generation
        mkdir -p $out/doc
        pushd $out/doc
        for ppath in ../pack/mnw/*/*/doc
        do
        if [ ! -e "$ppath/tags" ]; then
          PLUGIN_DIR=$(basename ''${ppath::-4})
          ln -snf "$ppath" "$PLUGIN_DIR"
        fi
        done
        if [ -n "$(ls $out/doc)" ]; then
          ${lib.getExe neovim} -es --headless -N -u NONE -i NONE -n -V1 \
            -c "helptags $out/doc" -c "quit!"
        fi
        popd

        source '${neovim.lua}/nix-support/utils.sh'
        if declare -f -F "_addToLuaPath" > /dev/null; then
          _addToLuaPath "$out"
          if [[ -v LUA_PATH ]]; then
            LUA_PATH="$LUA_PATH;"
          fi
          if [[ -v LUA_CPATH ]]; then
            LUA_CPATH="$LUA_CPATH;"
          fi
        fi
        envsubst < '${generatedInitLua}' > "$out/init.lua"
      '';
    };

    providersEnv =
      let
        pythonEnv = python3.withPackages (
          ps: providers.python3.extraPackages ps ++ allPython3Dependencies ps
        );

        perlEnv = providers.perl.package.withPackages providers.perl.extraPackages;
      in
      buildEnv {
        name = "neovim-providers";

        paths =
          lib.optionals providers.nodeJs.enable [
            providers.nodeJs.package
            providers.nodeJs.neovimClientPackage
          ]
          ++ lib.optionals providers.ruby.enable [
            providers.ruby.env
            providers.ruby.package
          ];

        nativeBuildInputs = [ makeBinaryWrapper ];

        postBuild = ''
          ${lib.optionalString providers.python3.enable ''
            makeWrapper ${lib.getExe pythonEnv} $out/bin/neovim-python3-host \
                --unset PYTHONPATH \
                --unset PYTHONSAFEPATH
          ''}

          ${lib.optionalString providers.perl.enable "ln -s ${lib.getExe perlEnv} $out/bin/neovim-perl-host"}
        '';
      };

    wrapperArgsStr = lib.escapeShellArgs (
      [
        "--set-default"
        "NVIM_APPNAME"
        appName

        "--add-flags"
        "-u ${builtConfigDir}/init.lua"
      ]
      ++ wrapperArgs
    );
  in
  stdenvNoCC.mkDerivation {
    pname = "mnw";
    version = lib.getVersion neovim;

    buildInputs =
      let
        mkExtraCheckHook =
          hook:
          callPackage (
            { neovim }:
            makeSetupHook {
              name = "mnw-extra-check-hook";
              propagatedBuildInputs = [ neovim ];
            } hook
          ) { };
      in
      map (x: mkExtraCheckHook (lib.getExe (writeShellScriptBin "mnw-check-hook" x))) extraCheckHooks;
    nativeBuildInputs = [
      makeBinaryWrapper
      lndir
    ];

    dontUnpack = true;
    strictDeps = true;
    dontRewriteSymlinks = true;

    installPhase = ''
      runHook preInstall

      # symlinkJoin
      mkdir -p $out
      lndir -silent ${neovim} $out

      wrapProgram $out/bin/nvim ${wrapperArgsStr}

      ${lib.concatMapStringsSep "\n" (x: "ln -s $out/bin/nvim $out/bin/'${x}'") aliases}

      ${lib.optionalString (!desktopEntry) "rm -rf $out/share/applications"}

      runHook postInstall
    '';

    # For debugging
    passthru =
      {
        inherit builtConfigDir;
      }
      // lib.optionalAttrs (!dev) {
        devMode = (callPackage ./wrapper.nix callPackageArgs) (mnwWrapperArgs // { dev = true; });
      };

    # From nixpkgs
    meta = {
      inherit (neovim.meta)
        description
        longDescription
        homepage
        mainProgram
        license
        maintainers
        platforms
        ;
      # To prevent builds on hydra
      hydraPlatforms = [ ];
      # prefer wrapper over the package
      priority = (neovim.meta.priority or 0) - 2;
    };
  }
)
