{ stdenv, fetchurl, system, makeWrapper, makeDesktopItem,
  alsaLib, dbus, glib, gstreamer, fontconfig, freetype, libpulseaudio, libxml2,
  libxslt, libGLU_combined, nspr, nss, sqlite, utillinux, zlib, xorg, udev, expat, libv4l }:

let

  version = "2.0.106600.0904";
  srcs = {
    x86_64-linux = fetchurl {
      url = "https://zoom.us/client/${version}/zoom_x86_64.tar.xz";
      sha256 = "1dcr0rqgjingjqbqv37hqjhhwy8axnjyirrnmjk44b5xnh239w9s";
    };
  };

in stdenv.mkDerivation {
  name = "zoom-us-${version}";

  src = srcs.${system};

  buildInputs = [ makeWrapper ];

  libPath = stdenv.lib.makeLibraryPath [
    alsaLib
    dbus
    glib
    gstreamer
    fontconfig
    freetype
    libpulseaudio
    libxml2
    libxslt
    nspr
    nss
    sqlite
    utillinux
    zlib
    udev
    expat

    xorg.libX11
    xorg.libSM
    xorg.libICE
    xorg.libxcb
    xorg.xcbutilimage
    xorg.xcbutilkeysyms
    xorg.libXcursor
    xorg.libXext
    xorg.libXfixes
    xorg.libXdamage
    xorg.libXtst
    xorg.libxshmfence
    xorg.libXi
    xorg.libXrender
    xorg.libXcomposite
    xorg.libXScrnSaver
    xorg.libXrandr

    stdenv.cc.cc
  ];

  installPhase = ''
    runHook preInstall

    packagePath=$out/share/zoom-us
    mkdir -p $packagePath
    mkdir -p $out/bin
    cp -ar * $packagePath

    patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)"  $packagePath/zoom
    patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)"  $packagePath/QtWebEngineProcess
    patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)"  $packagePath/qtdiag
    patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)"  $packagePath/zopen
    # included from https://github.com/NixOS/nixpkgs/commit/fc218766333a05c9352b386e0cbb16e1ae84bf53
    # it works for me without it, but, well...
    paxmark m $packagePath/zoom
    #paxmark m $packagePath/QtWebEngineProcess # is this what dtzWill talked about?

    # RUNPATH set via patchelf is used only for half of libraries (why?), so wrap it
    makeWrapper $packagePath/zoom $out/bin/zoom-us \
        --prefix LD_LIBRARY_PATH : "$packagePath:$libPath" \
        --prefix LD_PRELOAD : "${libv4l}/lib/v4l1compat.so" \
        --set QT_PLUGIN_PATH "$packagePath/platforms" \
        --set QT_XKB_CONFIG_ROOT "${xorg.xkeyboardconfig}/share/X11/xkb" \
        --set QTCOMPOSE "${xorg.libX11.out}/share/X11/locale"

    cat > $packagePath/qt.conf <<EOF
    [Paths]
    Prefix = $packagePath
    EOF

    runHook postInstall
  '';

  postInstall = (makeDesktopItem {
    name = "zoom-us";
    exec = "$out/bin/zoom-us %U";
    icon = "$out/share/zoom-us/application-x-zoom.png";
    desktopName = "Zoom";
    genericName = "Video Conference";
    categories = "Network;Application;";
    mimeType = "x-scheme-handler/zoommtg;";
  }).buildCommand;

  meta = {
    homepage = https://zoom.us/;
    description = "zoom.us video conferencing application";
    license = stdenv.lib.licenses.unfree;
    platforms = builtins.attrNames srcs;
    maintainers = with stdenv.lib.maintainers; [ danbst ];
  };

}
