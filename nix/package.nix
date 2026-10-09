# Generic package for one Crafting App (https://github.com/storytold), repacked from the upstream
# .deb published on the app's GitHub releases page.
#
# Every deb has the same layout: usr/bin/<name> (GUI, egui + wgpu) and usr/bin/<name>-cli, plus
# usr/share/{applications,mime,metainfo,icons,doc}. Versions and hashes live in sources.json,
# refreshed by `nix run .#update`.
{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  alsa-lib,
  libxkbcommon,
  wayland,
  libx11,
  libxcursor,
  libxi,
  libxrandr,
  libxcb,
  vulkan-loader,
  libGL,

  pname,
  displayName,
  description,
  # Entry from sources.json: { version, debName, sha256.<system> }.
  source,
}:

let
  inherit (source) version debName;
  system = stdenv.hostPlatform.system;
  arch = stdenv.hostPlatform.parsed.cpu.name;
in
stdenv.mkDerivation {
  inherit pname version;

  src = fetchurl {
    url = "https://github.com/storytold/${pname}/releases/download/v${version}/${debName}-${version}-linux-${arch}.deb";
    sha256 = source.sha256.${system} or (throw "${pname}: no upstream deb for ${system}");
  };

  nativeBuildInputs = [
    dpkg
    autoPatchelfHook
  ];

  # ELF NEEDED entries; autoPatchelf only adds the ones a binary actually links against
  # (alsa-lib is used by the apps with audio).
  buildInputs = [
    stdenv.cc.cc.lib
    alsa-lib
  ];

  # winit and wgpu dlopen these at runtime, so they are not ELF NEEDED entries
  # (the deb lists them under Depends/Recommends).
  runtimeDependencies = [
    libxkbcommon
    wayland
    libx11
    libxcursor
    libxi
    libxrandr
    libxcb
    vulkan-loader
    libGL
  ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp -R usr/. $out/
    runHook postInstall
  '';

  meta = {
    inherit description;
    homepage = "https://getartcraft.com/apps/${debName}";
    longDescription = "${displayName}: ${description}";
    license = with lib.licenses; [
      mit
      asl20
    ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = debName;
    platforms = lib.attrNames source.sha256;
  };
}
