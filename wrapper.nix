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
    splitPlugins =
      let
        partitioned = lib.partition (x: x.optional or false) plugins;
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
              plugin: [ plugin ] ++ lib.concatMap transitiveClosure plugin.dependencies or [ ];
          in
          lib.concatMap transitiveClosure;
      in
      (findDependenciesRecursively splitPlugins.start)
      ++ (lib.subtractLists splitPlugins.opt (findDependenciesRecursively splitPlugins.opt));

    allPython3Dependencies =
      ps:
      lib.pipe allPlugins [
        (lib.concatMap (plugin: (plugin.python3Dependencies or (_: [ ])) ps))
        lib.unique
      ];

    userConfig = writeTextDir "pack/generated/start/user/plugin/init.lua" (
      (lib.concatMapStringsSep "\n" (x: "vim.cmd('source ${x}')") (
        vimlFiles ++ lib.optional (initViml != "") (writeText "init.vim" initViml)
      ))
      +

        (lib.concatMapStringsSep "\n" (x: "dofile('${x}')") (
          lib.optional (initLua != "") (writeText "init.lua" initLua) ++ luaFiles
        ))
    );

    genConfig = writeTextDir "pack/generated/start/gen/plugin/init.lua" (
      lib.concatLines (
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
      )
    );

    configDir = buildEnv {
      name = "neovim-pack-dir";
      paths =
        let
          packPath = "pack/user";
          vimFarm =
            name: plugins:
            linkFarm "${name}-packdir" (
              map (drv: {
                name = "${packPath}/${name}/${
                  if (drv ? pname && (builtins.tryEval drv.pname).success) then drv.pname else drv.name
                }";
                path = drv;
              }) plugins
            );
        in
        [
          userConfig
          genConfig
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

        # Semi-cursed helptag generation
        mkdir -p $out/doc
        pushd $out/doc
        for ppath in ../pack/*/*/*/doc
        do
        PLUGIN_DIR=$(basename ''${ppath::-4})
        ln -snf "$ppath" "$PLUGIN_DIR"
        done
        ${lib.getExe neovim} -N -u NONE -i NONE -n -E -s -V1 -c "helptags $out/doc" -c "qa!"
        popd
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
      ]
      ++ (lib.optionals (!loadDefaultRC) [
        "--add-flags"
        "-u NORC"
      ])
      ++ (lib.optionals (plugins != [ ]) [
        "--add-flags"
        "--cmd 'set packpath^=${configDir} | set rtp^=${configDir}'"
      ])
      ++ wrapperArgs
    );

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

      echo "Looking for lua dependencies..."
      source ${neovim.lua}/nix-support/utils.sh

      _addToLuaPath "${configDir}"

      echo "LUA_PATH towards the end of packdir: $LUA_PATH"

      wrapProgram $out/bin/nvim ${wrapperArgsStr} \
        --prefix LUA_PATH ';' "$LUA_PATH" \
        --prefix LUA_CPATH ';' "$LUA_CPATH"

      ${lib.optionalString vimAlias "ln -s $out/bin/nvim $out/bin/vim"}

      ${lib.optionalString viAlias "ln -s $out/bin/nvim $out/bin/vi"}

      runHook postInstall
    '';

    passthru = {
      inherit configDir;
    };

    meta =
      (builtins.removeAttrs neovim.meta [
        "position"
        "outputsToInstall"
      ])
      // {
        # To prevent builds on hydra
        hydraPlatforms = [ ];
        # prefer wrapper over the package
        priority = (neovim.meta.priority or 0) - 1;
      };
  }
)
