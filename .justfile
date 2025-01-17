default: build

alias b := build

build derivation="chapterz":
    nix build ".#{{ derivation }}"

alias c := check

check: && format
    yamllint .
    asciidoctor **/*.adoc
    lychee --cache **/*.html
    nix flake check

alias f := format
alias fmt := format

format:
    treefmt

alias r := run

run derivation="chapterz":
    nix run ".#{{ derivation }}"

alias t := test

test:
    nu packages/chapterz/chapterz-tests.nu

alias u := update
alias up := update

update:
    nix run ".#update-nix-direnv"
    nix run ".#update-nixos-release"
    nix flake update
