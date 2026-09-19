{ pkgs, ... }:

pkgs.vimUtils.buildVimPlugin {
  pname = "VimFStar";
  version = "2022-05-04";
  src = pkgs.fetchFromGitHub {
    owner = "FStarLang";
    repo = "VimFStar";
    rev = "dedefcfe0041ad5af4afe1ac4230e3404311bfdb";
    hash = "sha256-tTAjbBIKBYkYzUmqbMycSvuPEmuLLG8LQL1WVMwzd7c=";
  };
  # ftplugin has Python 2 code that crashes under Python 3
  postInstall = "rm -rf $out/ftplugin $out/syntax_checkers";
}
