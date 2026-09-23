# notesy

Notesy is an amazing, fast, and modern alternative to Obsidian. It is developed and maintened by [@toyz](https://github.com/Toyz). This is a nixos derivation meant to make the process of installing notesy on nixos easier.

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

The download URL is derived from `channel`/`version`/`assetKind` in `notesy.nix`
(`https://cdn.notesy.ink/beta/<version>/notesy-<version>-linux-x86_64.tar.gz`),
so a bump only needs new hashes. We will be doing this on our end as new versions of notesy drop, so you will most likely never need to worry about this.

If you want to update stuff manually: Hashes live in `versions.json` (kept out of
the `.nix` so the updater never edits Nix code) and eval stays pure — no
network at `nix build`/`nix eval` time. To pin the feed's latest beta:

```bash
./update.sh # or: ./update.sh beta
```

then rebuild:

```bash
nix build .#packages.x86_64-linux.notesy
```

Manual equivalent (what the script does):

```bash
curl -s https://cdn.notesy.ink/beta/latest.json | jq '{version, asset: .assets."linux-x86_64"}'
```

One-off builds without editing files, flakes or not:

```bash
# flakes: overlay + callPackage with overrides
nix build --impure --expr '(import <nixpkgs> {}).callPackage ./notesy.nix { version = "0.1.14-beta.1"; srcHash = "<tar-sha>"; programSha256 = "<program-sha>"; }'
# legacy: top-level args are forwarded to notesy.nix
nix-build -A notesy --argstr version 0.1.14-beta.1 --argstr srcHash '<tar-sha>' --argstr programSha256 '<program-sha>'
```

## Notes

- Linux only. `x86_64-linux` is pinned in `versions.json`; the flake also
  exposes `aarch64-linux`, which fails with a clear "no pinned hashes"
  error until upstream ships a `linux-aarch64` binary (the beta feed
  already ships macOS/Windows builds, but this derivation packages Linux only).
- The upstream binary is `unfree` (`meta.license = licenses.unfree`), so you need `nixpkgs.config.allowUnfree = true`.
- The unpacked binary is verified against the feed's `program.sha256` when the feed provides one, and Wayland/X11/GL runtime libs are forced into `RPATH` because `winit` loads them with `dlopen()`.
