{
  lib,
  makeWrapper,
  nushell,
  stdenvNoCC,
  tone,
}:
if lib.versionOlder nushell.version "0.99" then
  throw "chapterz is not available for Nushell ${nushell.version}"
else
  stdenvNoCC.mkDerivation {
    pname = "chapterz";
    version = "0.1.0";

    src = ./../..;

    nativeBuildInputs = [ makeWrapper ];

    doCheck = true;

    buildInputs = [
      nushell
      tone
    ];

    checkPhase = ''
      runHook preCheck
      nu chapterz-tests.nu
      runHook postCheck
    '';

    installPhase = ''
      runHook preInstall
      install -D --mode=0755 --target-directory=$out/bin chapterz.nu embed-chapterz.nu
      runHook postInstall
    '';

    postFixup = ''
      for f in $out/bin/* ; do
        wrapProgram $f \
          --prefix PATH : ${
            lib.makeBinPath [
              tone
            ]
          }
      done
    '';

    meta = {
      description = "A script to help with creating audiobook chapters for MusicBrainz";
      homepage = "https://github.com/jwillikers/chapterz";
      # changelog = "https://github.com/jwillikers/chapterz/releases/tag/v${version}";
      license = with lib.licenses; [ mit ];
      # platforms = lib.platforms.linux;
      maintainers = with lib.maintainers; [ jwillikers ];
      mainProgram = "chapterz.nu";
    };
  }
