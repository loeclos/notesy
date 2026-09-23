# default.nix — non-flake entry point. `system` defaults to the
# caller's machine (dynamic), but can be overridden, e.g.
# `nix-build -A notesy --argstr system aarch64-linux`.
# All other args are forwarded to notesy.nix; null means "derived default".
# `nixpkgs` accepts a path/tarball so users can build against their own
# channel instead of the pinned 26.05 below.
{
  system ? builtins.currentSystem,
  nixpkgs ? fetchTarball "https://github.com/NixOS/nixpkgs/tarball/nixos-26.05",
  channel ? null,
  baseUrl ? null,
  version ? null,
  assetKind ? null,
  srcUrl ? null,
  srcHash ? null,
  programPath ? null,
  programSha256 ? null,
}:
let
  pkgs = import nixpkgs {
    inherit system;
    config.allowUnfree = true;
    overlays = [ ];
  };
  overrides = pkgs.lib.filterAttrs (_: v: v != null) {
    inherit
      channel
      baseUrl
      version
      assetKind
      srcUrl
      srcHash
      programPath
      programSha256
      ;
  };
in
{
  notesy = pkgs.callPackage ./notesy.nix overrides;
}
