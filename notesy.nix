{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  dbus,
  libcap,
  libgcrypt,
  libgpg-error,
  lz4,
  xz,
  zstd,
  systemd,
  unzip,
  gcc,
  wayland,
  libxkbcommon,
  libGL,
  vulkan-loader,
  fontconfig,
  freetype,
  expat,
  glib,
  xorg,
}:
let
  latest = builtins.fromJSON (
    builtins.readFile (
      builtins.fetchurl {
        url = "https://cdn.notesy.ink/beta/latest.json";
      }
    )
  );
  # New schema lists both naming styles; prefer the `linux-x86_64` key,
  # fall back to the legacy `x86_64-linux` key.
  asset = latest.assets."linux-x86_64" or latest.assets."x86_64-linux";
  version = latest.version;
  # New schema names the tarball beside the zip: prefer it when present,
  # otherwise fall back to the zip itself. Both carry their own sha256.
  source = asset.tar or asset;
  # New schema describes the program inside the archive with its own
  # SHA-256 (the archive hash never matches the unpacked file).
  program = asset.program or {
    path = "notesy";
    sha256 = null;
  };
  # winit-0.30 dlopen()s these at runtime (Wayland/X11/GL);
  # invisible to ldd, so they must also be in runtimeDependencies.
  guiRuntime = [
    wayland
    libxkbcommon
    libGL
    vulkan-loader
    fontconfig
    freetype
    expat
    glib
    xorg.libX11
    xorg.libXcursor
    xorg.libXi
    xorg.libXrandr
    xorg.libXext
    xorg.libXfixes
    xorg.libXrender
    xorg.libxcb
  ];
in
stdenv.mkDerivation {
  pname = "notesy";
  inherit version;

  src = fetchurl {
    url = source.url;
    inherit (source) sha256;
  };

  nativeBuildInputs =
    [
      autoPatchelfHook
    ]
    ++ lib.optional (!(asset ? tar)) unzip;

  buildInputs = [
    stdenv.cc.cc.lib
    dbus
    libcap
    libgcrypt
    libgpg-error
    lz4
    xz
    zstd
    systemd
    gcc
  ] ++ guiRuntime;

  # autoPatchelfHook only patches DT_NEEDED; winit uses dlopen(),
  # so force these into RPATH unconditionally.
  runtimeDependencies = guiRuntime;

  # The zip needs an explicit unzip; the tarball unpacks with tar.
  # Dispatch on extension so both old (zip-only) and new (tar+zip)
  # schemas work.
  unpackPhase = ''
    runHook preUnpack

    if [[ "$src" == *.zip ]]; then
      unzip -q "$src"
    else
      tar xzf "$src"
    fi

    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    ${lib.optionalString (program.sha256 != null) ''
      echo "checking unpacked program against latest.json program.sha256..."
      echo "${program.sha256}  ${program.path}" | sha256sum -c -
    ''}

    install -Dm755 ${program.path} $out/bin/notesy
    install -Dm644 notesy.desktop $out/share/applications/notesy.desktop

    mkdir -p $out/share/icons
    cp -r hicolor $out/share/icons/

    runHook postInstall
  '';

  meta = with lib; {
    description = "Plain markdown notes in a fast native app";
    homepage = "https://notesy.ink/";
    license = licenses.unfree;
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
  };
}
