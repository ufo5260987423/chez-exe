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
        libpath = lib.makeLibraryPath ([pkgs.ncurses5 pkgs.ncurses6] ++ platformSpecificInputs);
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
        startScript = writeShellScript "compile-chez-program" ''
          export LD_LIBRARY_PATH "${libpath}:''${LD_LIBRARY_PATH}"
          cmd=(
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