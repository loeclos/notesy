# notesy

Notesy is developed by [@toyz](https://github.com/Toyz). This is a nixos derivation meant to make the process of installing notesy on nixos easier.

## Installing

### Without flakes

```bash
# build only
nix-build -A notesy

# install into your profile
nix-env -i -f . -A notesy
```

### With flakes

```bash
# try it without installing
nix run github:loeclos/notesy

# install into your profile
nix profile install github:loeclos/notesy
```

### As a flake input (NixOS + home-manager)

```nix
# flake.nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    notesy = {
      url = "github:loeclos/notesy";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
}
```

```nix
# configuration.nix — via the overlay
{
  nixpkgs.overlays = [ inputs.notesy.overlays.default ];
  environment.systemPackages = [ pkgs.notesy ];
}
```

Or without the overlay, against your own `pkgs`:

```nix
environment.systemPackages = [
  inputs.notesy.packages.${pkgs.stdenv.hostPlatform.system}.notesy
];
```

## Updating

The derivation pins the beta release (`version`, `srcUrl`, `srcHash`, `programPath`, `programSha256` in `notesy.nix`, currently `0.1.13-beta.6`) so a given commit always builds the same binary and evaluates purely under flakes. To bump to a new beta, query the feed and copy the `linux-x86_64` `tar` and `program` fields:

```bash
curl -s https://cdn.notesy.ink/beta/latest.json | jq '{version, asset: .assets."linux-x86_64"}'
```

then update the defaults in `notesy.nix` and rebuild:

```bash
nix flake update # only updates the nixpkgs pin
nix build .#notesy
```

## Notes

- Linux only (`x86_64-linux`). The beta feed also ships macOS/Windows builds, but this derivation packages the `linux-x86_64` tarball/zip only.
- The upstream binary is `unfree` (`meta.license = licenses.unfree`), so you need `nixpkgs.config.allowUnfree = true`.
- The unpacked binary is verified against the feed's `program.sha256` when the feed provides one, and Wayland/X11/GL runtime libs are forced into `RPATH` because `winit` loads them with `dlopen()`.
