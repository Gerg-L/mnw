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
  writeTextDir,
  lndir,
  stdenvNoCC,
  callPackage,
}@callPackageArgs:
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
    appName,

    devExcludedPlugins,
    devPluginPaths,
    dev ? false,
  }@mnwWrapperArgs:
  let
    splitPlugins = lib.partition (x: x.optional or false) (
      plugins ++ lib.optionals (!dev) devExcludedPlugins
    );

    optPlugins = splitPlugins.right;

    startPlugins =
      let
        findDependenciesRecursively =
          let
            transitiveClosure =
              plugin: [ plugin ] ++ lib.concatMap transitiveClosure plugin.dependencies or [ ];
          in
          lib.concatMap transitiveClosure;
      in
      /*
        Gross edge case of optional plugin's
        dependency being loaded non-optionally
        only nixpkgs plugins have dependencies though
        so it should be okay
      */
      lib.subtractLists optPlugins (
        (findDependenciesRecursively splitPlugins.wrong) ++ (findDependenciesRecursively optPlugins)
      );

    allPython3Dependencies =
      ps:
      lib.pipe startPlugins [
        (lib.concatMap (plugin: (plugin.python3Dependencies or (_: [ ])) ps))
        lib.unique
      ];
    generatedInitLua =
      let
        providerLua =
          lib.pipe
            {
              node = withNodeJs;
              python = false;
              python3 = withPython3;
              ruby = withRuby;
              perl = withPerl;
            }
            [
              (lib.mapAttrsToList (
                prog: withProg:
                if withProg then
                  "vim.g.${prog}_host_prog='${providers}/bin/neovim-${prog}-host'"
                else
                  "vim.g.loaded_${prog}_provider=0"
              ))
              lib.concatLines
              (writeText "providers.lua")
            ];
      in
      lib.pipe
        [
          [ providerLua ]
          vimlFiles
          luaFiles
          (lib.optional (initViml != "") (writeText "init.vim" initViml))
          (lib.optional (initLua != "") (writeText "init.lua" initLua))
        ]
        [
          lib.concatLists
          (map (x: "vim.cmd('source ${x}')"))
          lib.concatLines
          (writeTextDir "init.lua")
        ];

    builtConfigDir = buildEnv {
      name = "neovim-pack-dir";
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
          generatedInitLua
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

        if [ ! -e "$out/init.lua" ]; then
          touch "$out/init.lua"
        fi
      '';
    };

    providers =
      let
        pythonEnv = python3Packages.python.withPackages (
          ps: [ ps.pynvim ] ++ (extraPython3Packages ps) ++ (allPython3Dependencies ps)
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
        devAfterRtp =
          lib.optionalString (dev && devPluginPaths != [ ])
            "| set rtp+=${lib.concatMapStringsSep "," (p: "${p}/after") devPluginPaths}";
        rtp = lib.concatStringsSep "," ([ builtConfigDir ] ++ lib.optionals dev devPluginPaths);

      in
      [
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

        "--add-flags"
        "--cmd 'set packpath^=${builtConfigDir} | set rtp^=${rtp} ${devAfterRtp}'"

        "--add-flags"
        "-u '${builtConfigDir}/init.lua'"
      ]
      ++ wrapperArgs
    );

  in

  stdenvNoCC.mkDerivation {
    pname = "mnw";
    version = "${appName}-${lib.getVersion neovim}";

    nativeBuildInputs = [
      makeWrapper
      lndir
    ];

    dontUnpack = true;
    strictDeps = true;

    installPhase = ''
      runHook preInstall

      # symlinkJoin
      mkdir -p $out
      lndir -silent ${neovim} $out

      # Add too LUA_PATH/LUA_CPATH using nixpkgs thing
      source '${neovim.lua}/nix-support/utils.sh'
      if declare -f -F "_addToLuaPath" > /dev/null; then
        _addToLuaPath "${builtConfigDir}"
      fi

      wrapProgram $out/bin/nvim ${wrapperArgsStr} \
        --prefix LUA_PATH ';' "$LUA_PATH" \
        --prefix LUA_CPATH ';' "$LUA_CPATH"

      ${lib.optionalString vimAlias "ln -s $out/bin/nvim $out/bin/vim"}
      ${lib.optionalString viAlias "ln -s $out/bin/nvim $out/bin/vi"}

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
