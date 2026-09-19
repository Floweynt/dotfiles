{ lib, pkgs, ... }:

pkgs.buildNpmPackage rec {
  pname = "fstar-vsca-lsp-server";
  version = "0.1.2";

  src = pkgs.fetchurl {
    url = "https://registry.npmjs.org/@smheidrich/fstar-vsca-lsp-server/-/fstar-vsca-lsp-server-${version}.tgz";
    hash = "sha256-HbN9iC58I1XBViWycjBGzcHJNthL9fiajxeRcIt70uI=";
  };

  npmDepsHash = "sha256-RsVWMPllqDexaEANdbT5+X0SAFvSMgsoauHsDccJSSc=";

  nativeBuildInputs = [ pkgs.jq ];
  postPatch = ''
    cp ${./fstar-lsp-package-lock.json} package-lock.json
    jq 'del(.scripts.prepare)' package.json > package.json.new
    mv package.json.new package.json
  '';
  dontNpmBuild = true;
  npmInstallFlags = [ "--ignore-scripts" ];
  meta = with lib; {
    description = "Standalone LSP server extracted from the F* VS Code Assistant";
    homepage = "https://www.npmjs.com/package/@smheidrich/fstar-vsca-lsp-server";
    license = licenses.mit;
  };
}
