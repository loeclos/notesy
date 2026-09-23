{
  description = "Nix packaging for notesy — plain markdown notes in a fast native app";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
  };

  outputs =
    { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
    in
    {
      packages.${system} = rec {
        notesy = pkgs.callPackage ./notesy.nix { };
        default = notesy;
      };

      overlays.default = _final: prev: { notesy = prev.callPackage ./notesy.nix { }; };

      formatter.${system} = pkgs.nixfmt-rfc-style;
    };
}
