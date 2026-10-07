{
  description = "Crafting Apps by storytold (PhotoCraft, LightCraft, VectorCraft, ...) for NixOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # App sources track each repo's default branch; `nix flake update` moves them forward,
    # flake.lock pins the exact commits.
    photocraft = { url = "github:storytold/photocraft"; flake = false; };
    lightcraft = { url = "github:storytold/lightcraft"; flake = false; };
    vectorcraft = { url = "github:storytold/vectorcraft"; flake = false; };
    filmcraft = { url = "github:storytold/filmcraft"; flake = false; };
    printcraft = { url = "github:storytold/printcraft"; flake = false; };
    soundcraft = { url = "github:storytold/soundcraft"; flake = false; };
    wordcraft = { url = "github:storytold/wordcraft"; flake = false; };
    gridcraft = { url = "github:storytold/gridcraft"; flake = false; };
    deckcraft = { url = "github:storytold/deckcraft"; flake = false; };
    cadcraft = { url = "github:storytold/cadcraft"; flake = false; };
    effectcraft = { url = "github:storytold/effectcraft"; flake = false; };
    designcraft = { url = "github:storytold/designcraft"; flake = false; };
    craft-fonts = { url = "github:storytold/craft-fonts"; flake = false; };
  };

  outputs =
    { self, nixpkgs, ... }@inputs:
    let
      lib = nixpkgs.lib;
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = f: lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});

      apps = {
        photocraft = {
          displayName = "PhotoCraft";
          description = "Image editor, clean-room reimplementation of Adobe Photoshop";
          features = [ "heif" ];
        };
        lightcraft = {
          displayName = "LightCraft";
          description = "Photo developer and library, clean-room reimplementation of Adobe Lightroom";
        };
        vectorcraft = {
          displayName = "VectorCraft";
          description = "Vector graphics editor, clean-room reimplementation of Adobe Illustrator";
        };
        filmcraft = {
          displayName = "FilmCraft";
          description = "Video editor, clean-room reimplementation of Adobe Premiere Pro";
          needsAlsa = true;
          needsGtk = true;
        };
        printcraft = {
          displayName = "PrintCraft";
          description = "PDF editor, clean-room reimplementation of Adobe Acrobat";
        };
        soundcraft = {
          displayName = "SoundCraft";
          description = "Digital audio workstation, clean-room reimplementation of Avid Pro Tools";
          needsAlsa = true;
        };
        wordcraft = {
          displayName = "WordCraft";
          description = "Word processor, clean-room reimplementation of Microsoft Word";
        };
        gridcraft = {
          displayName = "GridCraft";
          description = "Spreadsheet, clean-room reimplementation of Microsoft Excel";
        };
        deckcraft = {
          displayName = "DeckCraft";
          description = "Presentations, clean-room reimplementation of Microsoft PowerPoint";
          needsAlsa = true;
        };
        cadcraft = {
          displayName = "CADCraft";
          description = "Computer-aided design and drafting, AutoCAD-style";
        };
        effectcraft = {
          displayName = "EffectCraft";
          description = "Motion graphics and visual effects";
          needsAlsa = true;
        };
        designcraft = {
          displayName = "DesignCraft";
          description = "Page layout and design";
          useCraftFonts = true;
        };
      };

      mkApps =
        pkgs:
        lib.mapAttrs (
          pname: args:
          pkgs.callPackage ./nix/package.nix (
            args
            // {
              inherit pname;
              src = inputs.${pname};
              craft-fonts = inputs.craft-fonts;
            }
          )
        ) apps;
    in
    {
      packages = forAllSystems (
        pkgs:
        let
          craftApps = mkApps pkgs;
        in
        craftApps
        // {
          craft-fonts = pkgs.runCommand "craft-fonts" { } ''
            mkdir -p $out/share/fonts
            cp -R ${inputs.craft-fonts}/fonts $out/share/fonts/craft-fonts
          '';
          all = pkgs.symlinkJoin {
            name = "crafting-apps";
            paths = lib.attrValues craftApps;
          };
          default = self.packages.${pkgs.stdenv.hostPlatform.system}.photocraft;
        }
      );

      overlays.default = final: _prev: {
        craftApps = removeAttrs self.packages.${final.stdenv.hostPlatform.system} [ "default" ];
      };

      nixosModules.default =
        { config, lib, pkgs, ... }:
        let
          cfg = config.programs.crafting-apps;
          pkgsFor = self.packages.${pkgs.stdenv.hostPlatform.system};
        in
        {
          options.programs.crafting-apps = {
            enable = lib.mkEnableOption "the Crafting Apps by storytold";
            apps = lib.mkOption {
              type = lib.types.listOf (lib.types.enum (lib.attrNames apps));
              default = lib.attrNames apps;
              example = [ "photocraft" "lightcraft" "vectorcraft" ];
              description = "Which Crafting Apps to install (all of them by default).";
            };
            fonts = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Install the craft-fonts collection system-wide.";
            };
          };

          config = lib.mkIf cfg.enable {
            environment.systemPackages = map (name: pkgsFor.${name}) cfg.apps;
            fonts.packages = lib.optional cfg.fonts pkgsFor.craft-fonts;
            # Open/Save dialogs go through the XDG file-chooser portal (rfd).
            xdg.portal.enable = lib.mkDefault true;
            xdg.portal.extraPortals = lib.mkDefault [ pkgs.xdg-desktop-portal-gtk ];
            xdg.portal.config.common.default = lib.mkDefault "*";
            hardware.graphics.enable = lib.mkDefault true;
          };
        };
    };
}
