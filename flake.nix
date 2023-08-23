{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    crane = {
      url = "github:ipetkov/crane";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flake-utils.url = "github:numtide/flake-utils";

    advisory-db = {
      url = "github:rustsec/advisory-db";
      flake = false;
    };
  };

  outputs = {
    self,
    nixpkgs,
    crane,
    flake-utils,
    advisory-db,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {
        inherit system;
      };

      inherit (pkgs) lib;

      craneLib = crane.lib.${system};
      src = lib.cleanSourceWith {
        src = ./.;
        filter = path: type:
          (lib.hasInfix "/rsc/" path)
          || (craneLib.filterCargoSources path type);
      };

      commonArgs = {
        inherit src;
        buildInputs = with pkgs;
          [
            pkg-config
          ]
          ++ lib.optionals pkgs.stdenv.isDarwin [];
      };

      cargoArtifacts = craneLib.buildDepsOnly commonArgs;

      anyrun-symbols = craneLib.buildPackage (commonArgs
        // {
          inherit cargoArtifacts;
        });
    in {
      checks = {
        inherit anyrun-symbols;

        anyrun-symbols-clippy = craneLib.cargoClippy (commonArgs
          // {
            inherit cargoArtifacts;
            cargoClippyExtraArgs = "--all-targets -- --deny warnings";
          });

        anyrun-symbols-doc = craneLib.cargoDoc (commonArgs
          // {
            inherit cargoArtifacts;
          });

        anyrun-symbols-fmt = craneLib.cargoFmt {
          inherit src;
        };

        anyrun-symbols-audit = craneLib.cargoAudit {
          inherit src advisory-db;
        };
      };

      packages.default = anyrun-symbols;

      formatter = pkgs.alejandra;

      devShells.default = pkgs.mkShell {
        inputsFrom = builtins.attrValues self.checks.${system};

        nativeBuildInputs = with pkgs; [
          cargo # rust package manager
          clippy # opinionated rust formatter
          deadnix # clean up unused nix code
          gcc # GNU Compiler Collection
          lldb # software debugger
          rustc # rust compiler
          rustfmt # rust formatter
          rust-analyzer # rust analyzer
          statix # lints and suggestions
        ];
      };
    });
}
