{ lib
, buildNpmPackage
, fetchFromGitHub
}:
let
  version = "0.5.2";
in
buildNpmPackage {
  pname = "ollama";
  inherit version;

  src = fetchFromGitHub {
    owner = "ollama";
    repo = "ollama-js";
    rev = "v${version}";
    hash = "sha256-aw5KPsGxCN0ZUWiKcxwfTgOrtZBH8AUaA9tnXrMr/PE=";
  };

  npmDepsHash = "sha256-zehMM/tU0tSEKkSSVdJF3hhRiJU3qCyteuUuU3FRLyg=";

  meta = {
    description = "Ollama JavaScript library";
    homepage = "https://github.com/ollama/ollama-js";
    changelog = "https://github.com/ollama/ollama-js/releases/tag/v${version}";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ abysssol ];
  };
}
