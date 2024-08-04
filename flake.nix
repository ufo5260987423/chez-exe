{
  inputs = {
    utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, utils, ... }:
    utils.lib.eachDefaultSystem (
      system: let
        pkgs = nixpkgs.legacyPackages.${system};
        bootpath = if system == "x86_64-darwin"
          then "${pkgs.chez}/lib/csv${pkgs.chez.version}/ta6osx"
          else "${pkgs.chez}/lib/csv${pkgs.chez.version}/ta6le";
        platformSpecificInputs = if system == "x86_64-darwin"
          then [ pkgs.darwin.libiconv ]
          else [ pkgs.libuuid ];
        writeShellScript = pkgs.writeShellScript;
        lib = pkgs.lib;
        libPath = lib.makeLibraryPath ([pkgs.ncurses5 pkgs.ncurses6] ++ platformSpecificInputs);
          execPath = lib.makeBinPath ([ pkgs.libtool ]);
        bubblewrap = pkgs.bubblewrap;
        pre-chez-exe = pkgs.stdenv.mkDerivation {
          name = "chez-exe";
          version = "0.0.1";
          src = ./.;

          buildInputs = with pkgs; [
            chez
            ncurses5
            ncurses6
          ] ++ platformSpecificInputs;

          buildPhase = ''
            mkdir -p $out/{bin,lib}
            scheme --script gen-config.ss \
            --prefix $out \
            --bindir $out/bin \
            --libdir $out/lib \
            --bootpath ${bootpath} \
            --scheme scheme
          '';
        };
        #   export LD_LIBRARY_PATH="${libpath}:''${LD_LIBRARY_PATH}"
        #   ${pre-chez-exe}/bin/compile-chez-program "$@"
        # '';
        # startScript = writeShellScript "SVPManager" ''
        startScript = writeShellScript "compile-chez-program" ''
          # 除了这些路径以外，其它的根目录下的路径都映射进虚拟环境
          # 这里的有些路径不是完全不映射，而是在下面有更细粒度的映射配置
          blacklist=(/nix /dev /usr /lib /lib64 /proc)

          declare -a auto_mounts
          # loop through all directories in the root
          for dir in /*; do
            # if it is a directory and it is not in the blacklist
            if [[ -d "$dir" ]] && [[ ! "''${blacklist[@]}" =~ "$dir" ]]; then
              # add it to the mount list
              auto_mounts+=(--bind "$dir" "$dir")
            fi
          done

          # Bubblewrap 启动脚本
          cmd=(
            ${bubblewrap}/bin/bwrap
            # /dev 需要特殊的映射方式
            --dev-bind /dev /dev
            # 在虚拟环境中也切换到当前文件夹
            --chdir "$(pwd)"
            # Bubblewrap 退出时杀掉虚拟环境里的所有进程
            --die-with-parent
            # /nix 目录只读
            --ro-bind /nix /nix
            # /proc 需要特殊的映射方式
            --proc /proc
            # 配置环境变量，包括查找命令和库的路径
            --setenv PATH "${execPath}:''${PATH}"
            --setenv LD_LIBRARY_PATH "${libPath}:''${LD_LIBRARY_PATH}"
            # 映射其它根目录下的路径
            "''${auto_mounts[@]}"
            # 虚拟环境启动后运行主程序
            ${pre-chez-exe}/bin/compile-chez-program "$@"
          )
          exec "''${cmd[@]}"
        '';
      in {
        packages.default = pkgs.stdenv.mkDerivation {
            pname = "chez-exe";
            inherit (pre-chez-exe) version;
            phases = [ "installPhase" ];
            installPhase = ''
                mkdir -p $out/bin
                ln -s ${startScript} $out/bin/compile-chez-program
        '';
        };
      }
    );
}