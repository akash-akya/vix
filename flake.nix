{
  description = "Elixir Development Environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        inherit (nixpkgs.lib) optional;
        pkgs = import nixpkgs { inherit system; };

        sdk = with pkgs;
          lib.optionals stdenv.isDarwin
            (with darwin.apple_sdk.frameworks; [
              # needed for compilation
              pkgs.libiconv
              AppKit
              Foundation
              CoreFoundation
              CoreServices
            ]);

      in {
        devShell = pkgs.mkShell {
          buildInputs =
            [ pkgs.elixir sdk ];
        };
      });

}
