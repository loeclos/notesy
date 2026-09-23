{
  description = "Nix packaging for notesy — plain markdown notes in a fast native app";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
  };

  outputs =
    { self, nixpkgs }:
    let
      # Systems this flake exposes. Nix selects the user's system
      # dynamically via `packages.${system}` lookup (e.g.
      # `inputs.notesy.packages.${pkgs.stdenv.hostPlatform.system}`),
      # so add new entries here as upstream ships more binaries.
      # Currently upstream only publishes a linux-x86_64 binary —
      # other entries evaluate to a clear `throw` in notesy.nix.
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      pkgsFor =
        system:
        import nixpkgs {
          inherit system;
          # This flake ships only the (unfree) notesy binary, so allow it
          # in this flake's own pkgs instance. Otherwise `nix run
          # github:loeclos/notesy` fails evaluation even when the user
          # has allowUnfree=true in their system config, because flakes
          # evaluate purely and don't see NIXPKGS_ALLOW_UNFREE without
          # --impure.
          config.allowUnfree = true;
        };
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
        in
        rec {
          notesy = pkgs.callPackage ./notesy.nix { };
          default = notesy;
        }
      );

      overlays.default = _final: prev: { notesy = prev.callPackage ./notesy.nix { }; };

      formatter = forAllSystems (system: (pkgsFor system).nixfmt);
    };
}
