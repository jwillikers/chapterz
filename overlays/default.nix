_: {
  chapterz = _final: prev: {
    chapterz = prev.callPackage ./chapterz/package.nix { };
  };
}
