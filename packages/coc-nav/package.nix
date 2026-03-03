{ pkgs, ... }:
pkgs.buildNpmPackage rec {
  pname = "coc-nav";
  version = "0.0.9";

  src = pkgs.fetchurl {
    url = "https://registry.npmjs.org/${pname}/-/${pname}-${version}.tgz";
    sha256 = "sha256-dTuyHFA14UjIe8Gh6sgx8PhP4zTYCQaJCImRAey6ebU=";
  };

  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';
  npmDepsHash = "sha256-KCclUHACpzGicbdh8S5YlaIh9ltn4DD/1jHoUyQxBZY=";
}
