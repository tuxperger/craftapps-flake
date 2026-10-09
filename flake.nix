{
  description = "Crafting Apps by storytold (PhotoCraft, LightCraft, VectorCraft, ...) for NixOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # The apps themselves are fetched as upstream .deb releases (see nix/sources.json);
    # craft-fonts has no releases, so it tracks the default branch.
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
        };
        printcraft = {
          displayName = "PrintCraft";
          description = "PDF editor, clean-room reimplementation of Adobe Acrobat";
        };
        soundcraft = {
          displayName = "SoundCraft";
          description = "Digital audio workstation, clean-room reimplementation of Avid Pro Tools";
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
        };
        cadcraft = {
          displayName = "CADCraft";
          description = "Computer-aided design and drafting, AutoCAD-style";
        };
        effectcraft = {
          displayName = "EffectCraft";
          description = "Motion graphics and visual effects";
        };
        designcraft = {
          displayName = "DesignCraft";
          description = "Page layout and design";
        };
      };

      # Versions and hashes of the upstream debs; refresh with `nix run .#update`.
      sources = lib.importJSON ./nix/sources.json;

      mkApps =
        pkgs:
        lib.mapAttrs (
          pname: args:
          pkgs.callPackage ./nix/package.nix (
            args
            // {
              inherit pname;
              source = sources.${pname};
            }
          )
        ) apps;

      # A single package holding only the chosen apps, e.g. withApps pkgs [ "photocraft" "wordcraft" ].
      withApps =
        pkgs: names:
        pkgs.symlinkJoin {
          name = "crafting-apps";
          paths = map (name: (mkApps pkgs).${name}) names;
        };
    in
    {
      packages = forAllSystems (
        pkgs:
        mkApps pkgs
        // {
          craft-fonts = pkgs.runCommand "craft-fonts" { } ''
            mkdir -p $out/share/fonts
            cp -R ${inputs.craft-fonts}/fonts $out/share/fonts/craft-fonts
          '';
          all = withApps pkgs (lib.attrNames apps);
          default = self.packages.${pkgs.stdenv.hostPlatform.system}.photocraft;
        }
      );

      lib = { inherit withApps; };

      apps = forAllSystems (pkgs: {
        update = {
          type = "app";
          program = lib.getExe (
            pkgs.writeShellApplication {
              name = "update-crafting-apps";
              runtimeInputs = [ pkgs.curl pkgs.jq ];
              text = "APPS='${lib.concatStringsSep " " (lib.attrNames apps)}'\n" + builtins.readFile ./nix/update.sh;
            }
          );
        };
      });

      overlays.default = final: _prev: {
        craftApps = removeAttrs self.packages.${final.stdenv.hostPlatform.system} [ "default" ];
      };

      nixosModules.default =
        { config, lib, pkgs, ... }:
        let
          cfg = config.programs.crafting-apps;
          pkgsFor = self.packages.${pkgs.stdenv.hostPlatform.system};
          enabled = lib.filter (name: cfg.${name}.enable) (lib.attrNames apps);
        in
        {
          # One switch per app: programs.crafting-apps.photocraft.enable = true;
          options.programs.crafting-apps =
            lib.mapAttrs (_: app: { enable = lib.mkEnableOption app.displayName; }) apps
            // {
              fonts = lib.mkOption {
                type = lib.types.bool;
                default = true;
                description = "Install the craft-fonts collection system-wide when any app is enabled.";
              };
            };

          config = lib.mkIf (enabled != [ ]) {
            environment.systemPackages = map (name: pkgsFor.${name}) enabled;
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
