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

    ccAA64 = pkgs.pkgsCross.ucrtAarch64.buildPackages.clang;
    ccX64 = pkgs.pkgsCross.mingwW64.buildPackages.gcc;
    ccX86 = pkgs.pkgsCross.mingw32.buildPackages.gcc;

    wineBuildCfg = {
      inherit supportFlags;
      configureFlags = [
        "--disable-tests"
        "--enable-archs=aarch64,i386,x86_64"
        "--with-mingw=clang"
        "--enable-win64"
      ];
      mingwGccs = [
        ccAA64
        ccX64
        ccX86
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
        version = wineSources.stable.version;
        src = wineSources.stable;
      }
    );
  in {
    packages.aarch64-linux = rec {
      inherit wineHangover;
      default = wineHangover;
    };
  };
}
