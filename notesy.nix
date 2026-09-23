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
  # Pinned beta release. Bump these when a new beta ships — query
  # https://cdn.notesy.ink/beta/latest.json and copy the `linux-x86_64`
  # `tar` (or top-level `url`) and `program` fields. Pinned instead of
  # fetching latest.json at eval time so the derivation evaluates purely
  # (required for flakes) and a given commit always builds the same binary.
  version ? "0.1.13-beta.6",
  srcUrl ? "https://cdn.notesy.ink/beta/0.1.13-beta.6/notesy-0.1.13-beta.6-linux-x86_64.tar.gz",
  srcHash ? "a5f9000f3ecabced354af7e3664bb836be9c0e91d5730b955f974f2cd1e00560",
  programPath ? "notesy",
  programSha256 ? "41c5f3c946699fb4e7bc60465601cbc909b0008c07dd54ee161b70424f5f4fa6",
}:
let
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
    url = srcUrl;
    sha256 = srcHash;
  };

  nativeBuildInputs = [ autoPatchelfHook ] ++ lib.optional (lib.hasSuffix ".zip" srcUrl) unzip;

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

    ${lib.optionalString (programSha256 != null) ''
      echo "checking unpacked program against pinned programSha256..."
      echo "${programSha256}  ${programPath}" | sha256sum -c -
    ''}

    install -Dm755 ${programPath} $out/bin/notesy
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
