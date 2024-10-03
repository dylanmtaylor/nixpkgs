{
  stdenv,
  lib,
  makeWrapper,
  dpkg,
  fetchurl,
  autoPatchelfHook,
  curl,
  libkrb5,
  lttng-ust,
  libpulseaudio,
  gtk3,
  openssl,
  icu70,
  librsvg,
  gdk-pixbuf,
  libsoup,
  glib-networking,
  gsettings-desktop-schemas,
  graphicsmagick_q16,
  libva,
  libusb1,
  hiredis,
  pcsclite,
  jbigkit,
  libvdpau,
  libtiff,
  ffmpeg_6,
  lmdb,
  protobufc,
  zlib,
  cairo,
  pango,
  xorg,
  libfido2,
  webkitgtk_4_1,
  copyDesktopItems,
  glib,
  wrapGAppsHook,
  atk,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "aws-workspaces";
  version = "2024.5.5119";

  src = fetchurl {
    urls = [
      # Check new version at https://d3nt0h4h6pmmc4.cloudfront.net/ubuntu/dists/jammy/main/binary-amd64/Packages
      "https://d3nt0h4h6pmmc4.cloudfront.net/ubuntu/dists/jammy/main/binary-amd64/workspacesclient_${finalAttrs.version}_amd64.deb"
    ];
    hash = "sha256-qkQU9Z2d4T4JPq9iKAZAlROn21dN/9TeaA+9ysYlLzo=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    copyDesktopItems
    makeWrapper
    wrapGAppsHook
  ];

  # Crashes at startup when stripping:
  # "Failed to create CoreCLR, HRESULT: 0x80004005"
  dontStrip = true;

  buildInputs = [
    atk
    cairo
    curl
    ffmpeg_6.lib
    gdk-pixbuf
    glib-networking
    gsettings-desktop-schemas
    graphicsmagick_q16
    gtk3
    hiredis
    icu70
    jbigkit
    libfido2
    libkrb5
    libpulseaudio
    librsvg
    libsoup
    libtiff
    libusb1
    libva
    libvdpau
    lmdb
    lttng-ust
    openssl
    pango
    pcsclite
    protobufc
    stdenv.cc.cc.lib
    webkitgtk_4_1
    xorg.libxcb
    zlib
  ];

  unpackPhase = ''
    runHook preUnpack
    ${dpkg}/bin/dpkg -x $src $out
    mv $out/usr/share $out/share
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin $out/lib
    rm -rf $out/opt

    wrapProgram $out/usr/bin/workspacesclient \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath finalAttrs.buildInputs}" \
      --set GDK_PIXBUF_MODULE_FILE "${librsvg.out}/lib/gdk-pixbuf-2.0/2.10.0/loaders.cache" \
      --set GIO_EXTRA_MODULES "${glib-networking.out}/lib/gio/modules"

    mv $out/usr/bin/workspacesclient $out/bin/workspacesclient
    runHook postInstall
  '';

  postInstall = ''
    glib-compile-schemas $out/share/glib-2.0/schemas
  '';

  meta = with lib; {
    description = "Client for Amazon WorkSpaces, a managed, secure Desktop-as-a-Service (DaaS) solution";
    homepage = "https://clients.amazonworkspaces.com";
    license = licenses.unfree;
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    mainProgram = "workspacesclient";
    maintainers = with maintainers; [
      mausch
      dylanmtaylor
    ];
    platforms = [ "x86_64-linux" ]; # TODO Mac support
  };
})
