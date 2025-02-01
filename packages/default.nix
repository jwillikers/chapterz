{ pkgs, ... }:
{
  chapterz = pkgs.callPackage ./chapterz/package.nix { };
}
