{
  lib,
  stdenv,
  fetchurl,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "jbigkit";
  version = "2.1";

  src = fetchurl {
    url = "https://www.cl.cam.ac.uk/~mgk25/jbigkit/download/jbigkit-${finalAttrs.version}.tar.gz";
    hash = "sha256-3nEGtr+vSV1oZcfdesbKE4G9EuDYFAXqgefyFnJj2TI=";
  };

  makeFlags = [
    "AR=${lib.getBin stdenv.cc.bintools.bintools}/bin/${stdenv.cc.targetPrefix}ar"
    "CC=${stdenv.cc}/bin/${stdenv.cc.targetPrefix}cc"
    "RANLIB=${lib.getBin stdenv.cc.bintools.bintools}/bin/${stdenv.cc.targetPrefix}ranlib"
  ];

  postPatch = ''
    sed -i 's/^\(CFLAGS.*\)$/\1 -fPIC/' Makefile

    for f in Makefile libjbig/Makefile pbmtools/Makefile; do
        sed -i -E 's/\bar /$(AR) /g;s/\branlib /$(RANLIB) /g' "$f"
    done
  '';

  installPhase = ''
    runHook preInstall

    install -D -m644 libjbig/libjbig.a $out/lib/libjbig.a
    install -D -m644 libjbig/libjbig85.a $out/lib/libjbig85.a
    install -D -m644 libjbig/jbig.h $out/include/jbig.h
    install -D -m644 libjbig/jbig_ar.h $out/include/jbig_ar.h
    install -D -m644 libjbig/jbig85.h $out/include/jbig85.h

    install -d -m755 $out/share/man/man1
    install -m644 pbmtools/*.1* $out/share/man/man1

    install -D -m755 pbmtools/jbgtopbm $out/bin/jbgtopbm
    install -D -m755 pbmtools/pbmtojbg $out/bin/pbmtojbg
    install -D -m755 pbmtools/jbgtopbm85 $out/bin/jbgtopbm85
    install -D -m755 pbmtools/pbmtojbg85 $out/bin/pbmtojbg85

    runHook postInstall
  '';

  meta = {
    description = "Software implementation of the JBIG1 data compression standard";
    homepage = "http://www.cl.cam.ac.uk/~mgk25/jbigkit/";
    license = lib.licenses.gpl2Plus;
    platforms = lib.platforms.all;
  };
})
