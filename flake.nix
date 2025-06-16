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
          else if system == "aarch64-darwin"
          then "${pkgs.chez}/lib/csv${pkgs.chez.version}/tarm64osx"
          else "${pkgs.chez}/lib/csv${pkgs.chez.version}/ta6le";
        platformSpecificInputs = if (system == "x86_64-darwin" || system == "aarch64-darwin")
          then [ pkgs.darwin.libiconv ]
          else [ pkgs.libuuid ];
        writeShellScript = pkgs.writeShellScript;
        lib = pkgs.lib;
        libPath = lib.makeLibraryPath ([pkgs.ncurses5 pkgs.ncurses6] ++ platformSpecificInputs);
        execPath = lib.makeBinPath ([ pkgs.libtool ]);
        isDarwin = lib.strings.hasSuffix "darwin" system;
        pre-chez-exe = pkgs.stdenv.mkDerivation {
          name = "chez-exe";
          version = "0.0.1";
          src = ./.;

          buildInputs = with pkgs; [
            chez
            ncurses5
            ncurses6
          ] ++ platformSpecificInputs;

          nativeBuildInputs = with pkgs; [
            pkg-config
          ];

          NIX_LDFLAGS = if isDarwin 
            then "-liconv -lncurses"
            else "";

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
        startScript = if isDarwin
          then writeShellScript "compile-chez-program" ''
            export PATH="${execPath}:''${PATH}"
            export LIBRARY_PATH="${libPath}:''${LIBRARY_PATH}"
            export LDFLAGS="-liconv -lncurses"
            export NIX_LDFLAGS="-liconv -lncurses"
            exec ${pre-chez-exe}/bin/compile-chez-program "$@"
          ''
          else writeShellScript "compile-chez-program" ''
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
              ${pkgs.bubblewrap}/bin/bwrap
              --dev-bind /dev /dev
              --chdir "$(pwd)"
              --die-with-parent
              --ro-bind /nix /nix
              --proc /proc
              --setenv PATH "${execPath}:''${PATH}"
              --setenv LIBRARY_PATH "${libPath}:''${LIBRARY_PATH}"
              "''${auto_mounts[@]}"
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