# Generic builder for one Crafting App (https://github.com/storytold).
#
# Every app repo has the same layout: a Cargo workspace with apps/<name> (GUI, egui + wgpu) and
# apps/<name>-cli, plus packaging/linux/ai.storyteller.<name>.{desktop,mime.xml,metainfo.xml.in}
# and assets/app-icon/hicolor. This mirrors packaging/linux/package.sh from those repos.
{
  lib,
  rustPlatform,
  pkg-config,
  wrapGAppsHook3,
  alsa-lib,
  gtk3,
  libxkbcommon,
  wayland,
  libx11,
  libxcursor,
  libxi,
  libxrandr,
  libxcb,
  vulkan-loader,
  libGL,
  craft-fonts ? null,

  pname,
  src,
  displayName,
  description,
  homepage ? "https://getartcraft.com/apps/${pname}",
  features ? [ ],
  # Native libraries the workspace links against (e.g. alsa-sys needs alsa-lib).
  needsAlsa ? false,
  needsGtk ? false,
  # Embed fonts from craft-fonts at build time (only designcraft supports it today).
  useCraftFonts ? false,
}:

let
  cargoToml = lib.importTOML "${src}/Cargo.toml";
  version = cargoToml.workspace.package.version;
  appId = "ai.storyteller.${pname}";

  # winit and wgpu dlopen these at runtime, so they are not ELF NEEDED entries
  # (see packaging/linux/nfpm.yaml in each repo).
  runtimeLibs = [
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
in
rustPlatform.buildRustPackage {
  inherit pname version src;

  cargoLock = {
    lockFile = "${src}/Cargo.lock";
    # effectcraft pins filmcraft crates by git rev; fetch them without per-rev hashes.
    allowBuiltinFetchGit = true;
  };

  cargoBuildFlags = [
    "-p"
    pname
    "-p"
    "${pname}-cli"
  ];
  buildFeatures = features;

  # The test suites are large (golden images, corpora) and not needed to install the apps.
  doCheck = false;

  nativeBuildInputs = [ pkg-config ] ++ lib.optional needsGtk wrapGAppsHook3;
  buildInputs = lib.optional needsAlsa alsa-lib ++ lib.optional needsGtk gtk3;

  env = lib.optionalAttrs (useCraftFonts && craft-fonts != null) {
    CRAFT_FONTS_DIR = "${craft-fonts}";
    CRAFT_FONTS_REQUIRED = "1";
  };

  postInstall = ''
    install -Dm644 packaging/linux/${appId}.desktop $out/share/applications/${appId}.desktop
    install -Dm644 packaging/linux/${appId}.mime.xml $out/share/mime/packages/${appId}.xml
    mkdir -p $out/share/metainfo $out/share/icons
    sed -e 's/@VERSION@/${version}/g' -e 's/@DATE@/1970-01-01/g' \
      packaging/linux/${appId}.metainfo.xml.in > $out/share/metainfo/${appId}.metainfo.xml
    cp -R assets/app-icon/hicolor $out/share/icons/
  '';

  postFixup = ''
    for bin in $out/bin/${pname} $out/bin/${pname}-cli; do
      patchelf --add-rpath ${lib.makeLibraryPath runtimeLibs} "$bin"
    done
  '';

  meta = {
    inherit description homepage;
    longDescription = "${displayName}: ${description}";
    license = with lib.licenses; [
      mit
      asl20
    ];
    mainProgram = pname;
    platforms = lib.platforms.linux;
  };
}
