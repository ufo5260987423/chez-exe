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
        libpath = lib.makeLibraryPath platformSpecificInputs;
        pre-chez-exe = pkgs.stdenv.mkDerivation {
          name = "chez-exe";
          version = "0.0.1";
          src = ./.;

          buildInputs = with pkgs; [
            chez
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
          cmd=(
            export LD_LIBRARY_PATH "${libpath}:''${LD_LIBRARY_PATH}"
            ${pre-chez-exe}/bin/compile-chez-program "$@"
          )
          exec "''${cmd[@]}"
        '';
      in {
        packages.default = pkg.stdenv.mkDerivation {
            pname = "chez-exe";
            inherit (pre-chez-exe) version;
            phases = [ "installPhase" ];
            installPhase = ''
                mkdir $out/bin
                ln -s ${startScript} $out/bin/compile-chez-program
        '';
        };
      }
    );
}