{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    nix-gaming = {
      url = "github:fufexan/nix-gaming";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    nix-gaming,
  }: let 
    pkgs = import nixpkgs { 
      system = "aarch64-linux";
    };
    lib = nixpkgs.lib;

    # these next parts are essentially taken from fufexan/nix-gaming
    nixpkgs-wine = builtins.path {
      path = nixpkgs;
      name = "source";
      filter = path: type: let
        wineDir = "${nixpkgs}/pkgs/applications/emulators/wine/";
      in (
        (type == "directory" && (lib.hasPrefix path wineDir))
        || (type != "directory" && (lib.hasPrefix wineDir path))
      );
    };

    # good enough
    supportFlags = (import "${nix-gaming}/pkgs/wine/supportFlags.nix").full;

    wineSources = import "${nixpkgs-wine}/pkgs/applications/emulators/wine/sources.nix" {inherit pkgs;};

    gccAA64 = pkgs.pkgsCross.ucrtAarch64.buildPackages.clang;
    gccX64 = pkgs.pkgsCross.ucrt64.buildPackages.clang;
    gccX86 = pkgs.pkgsCross.mingw32.buildPackages.gcc;

    wineBuildCfg = {
      inherit supportFlags;
      configureFlags = [
        "--disable-tests"
        "--enable-archs=aarch64,i386"
      ];
      mingwGccs = [
        gccAA64
        gccX64
        gccX86
      ];
      platforms = ["aarch64-linux"];
      pkgArches = [pkgs];
      geckos = [];
      monos = [];
      patches = [];
      wineRelease = "unstable";
      mainProgram = "wine";
    };

    wineHangover = pkgs.callPackage "${nixpkgs-wine}/pkgs/applications/emulators/wine/base.nix" (
      lib.recursiveUpdate wineBuildCfg {
        pname = "wineHangover";
        version = wineSources.unstable.version;
        src = wineSources.unstable;
      }
    );
  in {
    packages.aarch64-linux = rec {
      inherit wineHangover;
      default = wineHangover;
    };
  };
}
