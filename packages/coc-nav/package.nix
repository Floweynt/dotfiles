{ pkgs, ... }:
pkgs.vimUtils.buildVimPlugin {
  pname = "coc-nav";
  version = "0.0.9";

  src = pkgs.fetchurl {
    url = "https://registry.npmjs.org/coc-nav/-/coc-nav-0.0.9.tgz";
    sha256 = "sha256-dTuyHFA14UjIe8Gh6sgx8PhP4zTYCQaJCImRAey6ebU=";
  };

  postPatch = ''
    substituteInPlace lib/index.js \
      --replace-fail '"CursorHold"' '["CursorMoved","CursorMovedI","TextChangedI"]'
  '';
}
