{ lib
, pkgs
, stdenv
, fetchFromGitHub
, fetchpatch
, buildGo122Module

, nixosTests
, testers
, ollama
, ollama-rocm
, ollama-cuda

, config
  # one of `[ null false "rocm" "cuda" ]`
, acceleration ? null
}:

let
  pname = "ollama";
  # don't forget to invalidate all hashes each update and update `llamaCppPatches`
  version = "0.1.47";

  src = fetchFromGitHub {
    owner = "ollama";
    repo = "ollama";
    rev = "v${version}";
    hash = "sha256-gxai2ORHABchnmdzjr9oYzk9p21qQjSIxrKt5k356i4=";
    fetchSubmodules = true;
  };

  vendorHash = "sha256-LNH3mpxIrPMe5emfum1W10jvXIjKC6GkGcjq1HhpJQo=";

  # ollama's patches of llama.cpp's example server
  # `ollama/llm/generate/gen_common.sh` -> "apply temporary patches until fix is upstream"
  # each update, these patches should be synchronized with the contents of `ollama/llm/patches/`
  llamacppPatches = [
    {
      patch = "01-load-progress.diff";
      hash = "sha256-K4GryCH/1cl01cyxaMLX3m4mTE79UoGwLMMBUgov+ew=";
    }
    {
      patch = "02-clip-log.diff";
      hash = "sha256-rMWbl3QgrPlhisTeHwD7EnGRJyOhLB4UeS7rqa0tdXM=";
    }
    {
      patch = "03-load_exception.diff";
      hash = "sha256-0XfMtMyg17oihqSFDBakBtAF0JwhsR188D+cOodgvDk=";
    }
    {
      patch = "04-metal.diff";
      hash = "sha256-Ne8J9R8NndUosSK0qoMvFfKNwqV5xhhce1nSoYrZo7Y=";
    }
    {
      patch = "05-default-pretokenizer.diff";
      hash = "sha256-JnCmFzAkmuI1AqATG3jbX7nGIam4hdDKqqbG5oh7h70=";
    }
    {
      patch = "06-qwen2.diff";
      hash = "sha256-nMtoAQUsjYuJv45uTlz8r/K1oF5NUsc75SnhgfSkE30=";
    }
    {
      patch = "07-gemma.diff";
      hash = "sha256-dKJrRvg/XC6xtwxLHZ7lFkLNMwT8Ugmd5xRPuKQDXvU=";
    }
  ];


  accelIsValid = builtins.elem acceleration [ null false "rocm" "cuda" ];
  validateFallback = lib.warnIf (config.rocmSupport && config.cudaSupport)
    (lib.concatStrings [
      "both `nixpkgs.config.rocmSupport` and `nixpkgs.config.cudaSupport` are enabled, "
      "but they are mutually exclusive; falling back to cpu"
    ])
    (!(config.rocmSupport && config.cudaSupport));
  shouldEnable = assert accelIsValid;
    mode: fallback:
      (acceleration == mode)
      || (fallback && acceleration == null && validateFallback);

  rocmRequested = shouldEnable "rocm" config.rocmSupport;
  cudaRequested = shouldEnable "cuda" config.cudaSupport;

  enableRocm = rocmRequested && stdenv.isLinux;
  enableCuda = cudaRequested && stdenv.isLinux;


  preparePatch = { patch, hash }: fetchpatch {
    url = "file://${src}/llm/patches/${patch}";
    stripLen = 1;
    extraPrefix = "llm/llama.cpp/";
    inherit hash;
  };

  generated = pkgs.callPackage ./go-generate.nix {
    ollamaSrc = src;
    ollamaVersion = version;
    llamacppPatches = builtins.map preparePatch llamacppPatches;
    inherit enableRocm enableCuda;
  };

  inherit (lib) licenses platforms maintainers;
in
buildGo122Module {
  inherit pname version src vendorHash;

  postPatch = ''
    # replace inaccurate version number with actual release version
    substituteInPlace version/version.go --replace-fail 0.0.0 '${version}'
  '';
  postFixup = ''
    # the app doesn't appear functional at the moment, so hide it
    mv "$out/bin/app" "$out/bin/.ollama-app"
  '';

  ldflags = [
    "-s"
    "-w"
    "-X=github.com/ollama/ollama/version.Version=${version}"
    "-X=github.com/ollama/ollama/server.mode=release"
  ];

  passthru.tests = {
    inherit ollama;
    service = nixosTests.ollama;
    version = testers.testVersion {
      inherit version;
      package = ollama;
    };
  } // lib.optionalAttrs stdenv.isLinux {
    inherit ollama-rocm ollama-cuda;
  };

  meta = {
    description = "Get up and running with large language models locally"
      + lib.optionalString rocmRequested ", using ROCm for AMD GPU acceleration"
      + lib.optionalString cudaRequested ", using CUDA for NVIDIA GPU acceleration";
    homepage = "https://github.com/ollama/ollama";
    changelog = "https://github.com/ollama/ollama/releases/tag/v${version}";
    license = licenses.mit;
    platforms =
      if (rocmRequested || cudaRequested)
      then platforms.linux
      else platforms.unix;
    mainProgram = "ollama";
    maintainers = with maintainers; [ abysssol dit7ya elohmeier roydubnium ];
  };
}
