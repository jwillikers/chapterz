{ pkgs, ... }:
{
  chapterz = pkgs.unstable.callPackage ./chapterz/package.nix { };
}
