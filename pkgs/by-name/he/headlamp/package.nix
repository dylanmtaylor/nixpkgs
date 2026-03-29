{
  lib,
  stdenv,
  buildGoModule,
  buildNpmPackage,
  fetchFromGitHub,
  electron,
  makeWrapper,
  makeDesktopItem,
  copyDesktopItems,
}:

let
  version = "0.41.0";

  src = fetchFromGitHub {
    owner = "kubernetes-sigs";
    repo = "headlamp";
    tag = "v${version}";
    hash = "sha256-ZXyE4oPkwimnU2ArOiTCnLxzaI5z/7T/SHS9aqP2DGM=";
  };

  frontend = buildNpmPackage {
    pname = "headlamp-frontend";
    inherit version src;

    sourceRoot = "${src.name}/frontend";

    npmDepsHash = "sha256-cjar6j5Wzh5monp9YxrsrnGDxgjlT+YRFh5mgZcImKI=";

    postPatch = ''
      chmod -R u+w ../app
      cp ${src}/app/package.json ../app/package.json
      substituteInPlace package.json --replace-fail '"prebuild": "npm run make-version",' ""
    '';

    preBuild = ''
      cat > .env <<EOF
      REACT_APP_HEADLAMP_VERSION=${version}
      REACT_APP_HEADLAMP_GIT_VERSION=v${version}
      REACT_APP_HEADLAMP_PRODUCT_NAME=Headlamp
      REACT_APP_ENABLE_REACT_QUERY_DEVTOOLS=false
      REACT_APP_HEADLAMP_SIDEBAR_DEFAULT_OPEN=true
      EOF
    '';

    env.PUBLIC_URL = "./";
    env.NODE_OPTIONS = "--max-old-space-size=8096";

    installPhase = ''
      runHook preInstall
      cp -r build $out
      runHook postInstall
    '';
  };

  server = buildGoModule {
    pname = "headlamp-server";
    inherit version src;

    modRoot = "backend";

    vendorHash = "sha256-JjfB93C97yTbUTUbs7wEB/iFtuRzHzFXGyRHDAec7X8=";

    # Don't embed frontend - Electron serves it directly. This also prevents
    # the server from auto-opening a browser window.

    ldflags = [
      "-s"
      "-w"
      "-X github.com/kubernetes-sigs/headlamp/backend/pkg/kubeconfig.Version=${version}"
      "-X github.com/kubernetes-sigs/headlamp/backend/pkg/kubeconfig.AppName=Headlamp"
    ];

    subPackages = [ "cmd" ];

    postInstall = ''
      mv $out/bin/cmd $out/bin/headlamp-server
    '';
  };

  electronApp = buildNpmPackage {
    pname = "headlamp-electron";
    inherit version src;

    sourceRoot = "${src.name}/app";

    npmDepsHash = "sha256-FcV2ORs96Rj/OyCbBCBo/ZmcwvjDLPKkn0i4m+0gXIE=";

    env.ELECTRON_SKIP_BINARY_DOWNLOAD = "1";

    postUnpack = ''
      chmod -R u+w "$sourceRoot/.."
    '';

    buildPhase = ''
      runHook preBuild
      node scripts/build-electron.js
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p $out/lib/headlamp/app/build $out/lib/headlamp/app/node_modules

      cp package.json $out/lib/headlamp/app/
      cp build/main.js build/preload.js $out/lib/headlamp/app/build/

      # Production dependencies
      npm ci --omit=dev --ignore-scripts
      rm -rf node_modules/.bin
      cp -r node_modules $out/lib/headlamp/app/

      runHook postInstall
    '';
  };
in

stdenv.mkDerivation {
  pname = "headlamp";
  inherit version src;

  dontUnpack = true;
  dontBuild = true;
  strictDeps = true;
  __structuredAttrs = true;

  nativeBuildInputs = [
    makeWrapper
    copyDesktopItems
  ];

  desktopItems = [
    (makeDesktopItem {
      name = "headlamp";
      desktopName = "Headlamp";
      comment = "An easy-to-use and extensible Kubernetes web UI";
      exec = "headlamp";
      icon = "headlamp";
      categories = [
        "Network"
        "System"
      ];
      startupWMClass = "Headlamp";
    })
  ];

  installPhase = ''
    runHook preInstall

    # Copy the electron app
    mkdir -p $out/lib/headlamp
    cp -r ${electronApp}/lib/headlamp/app $out/lib/headlamp/
    chmod -R u+w $out/lib/headlamp/app

    # Create resources directory (where process.resourcesPath should point)
    mkdir -p $out/lib/headlamp/resources
    cp -r ${frontend} $out/lib/headlamp/resources/frontend
    chmod -R u+w $out/lib/headlamp/resources/frontend
    ln -s ${server}/bin/headlamp-server $out/lib/headlamp/resources/headlamp-server
    mkdir -p $out/lib/headlamp/resources/.plugins
    cp ${src}/app/app-build-manifest.json $out/lib/headlamp/resources/

    # i18n locales
    mkdir -p $out/lib/headlamp/resources/frontend/i18n
    cp -r ${src}/frontend/src/i18n/locales $out/lib/headlamp/resources/frontend/i18n/locales

    # Entry point that sets process.resourcesPath before loading the real main
    cat > $out/lib/headlamp/app/main.js <<ENTRY
    const path = require('path');
    const { app } = require('electron');
    const resourcesPath = path.resolve(__dirname, '..', 'resources');
    Object.defineProperty(process, 'resourcesPath', {
      get: () => resourcesPath,
      configurable: false,
    });
    app.setVersion('${version}');
    app.setName('Headlamp');
    require('./build/main.js');
    ENTRY

    # Point package.json main at our wrapper
    substituteInPlace $out/lib/headlamp/app/package.json \
      --replace-fail '"main": "build/main.js"' '"main": "main.js"'

    # Icons
    for size in 16 32; do
      mkdir -p $out/share/icons/hicolor/''${size}x''${size}/apps
      cp ${src}/frontend/public/favicon-''${size}x''${size}.png $out/share/icons/hicolor/''${size}x''${size}/apps/headlamp.png
    done
    mkdir -p $out/share/icons/hicolor/192x192/apps
    cp ${src}/frontend/public/android-chrome-192x192.png $out/share/icons/hicolor/192x192/apps/headlamp.png
    mkdir -p $out/share/icons/hicolor/512x512/apps
    cp ${src}/frontend/public/android-chrome-512x512.png $out/share/icons/hicolor/512x512/apps/headlamp.png

    # Wrapper
    mkdir -p $out/bin
    makeWrapper ${electron}/bin/electron $out/bin/headlamp \
      --add-flags $out/lib/headlamp/app \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--enable-features=WaylandWindowDecorations --enable-wayland-ime=true}}" \
      --prefix PATH : ${server}/bin

    # Also expose the server standalone
    ln -s ${server}/bin/headlamp-server $out/bin/headlamp-server

    runHook postInstall
  '';

  passthru = {
    inherit server frontend;
  };

  meta = {
    description = "An easy-to-use and extensible Kubernetes web UI";
    homepage = "https://headlamp.dev";
    changelog = "https://github.com/kubernetes-sigs/headlamp/releases/tag/v${version}";
    license = lib.licenses.asl20;
    maintainers = with lib.maintainers; [ dylanmtaylor ];
    mainProgram = "headlamp";
    platforms = lib.platforms.linux;
  };
}
