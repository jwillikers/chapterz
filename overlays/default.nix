{ inputs }:
{
  unstablePackages = final: _prev: {
    unstable = import inputs.nixpkgs-unstable { inherit (final) system; };
  };
}
