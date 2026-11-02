#!/bin/bash
set -euo pipefail

# Creates a signed and notarized BACCH Router uninstaller for each channel variant.
# Run this script from the repo root:
#   ./Uninstaller/create_uninstaller.sh
#
# Signing and notarization work the same way as Installer/create_installer.sh, and use the same
# settings from Installer/signing.sh.

# Basic Validation
if [ ! -d BlackHole.xcodeproj ]; then
    echo "This script must be run from the repo root folder."
    echo "For example:"
    echo "  cd /path/to/bacch-router"
    echo "  ./Uninstaller/create_uninstaller.sh"
    exit 1
fi

version=$(cat VERSION)

if [ -z "$version" ]; then
    echo "Could not find version number. VERSION file is missing from repo root or is empty."
    exit 1
fi

source Installer/signing.sh

for channels in $channelVariants; do
    # Env
    ch=$channels"ch"
    bundleID="$bundleIDPrefix.$driverID$ch"
    driverBundleName="$driverName $ch.driver"
    workDir=$(mktemp -d)

    mkdir "$workDir/scripts"
    cat > "$workDir/scripts/postinstall" <<EOF
#!/bin/sh
driverPath="/Library/Audio/Plug-Ins/HAL/$driverBundleName"
restartAction="finish uninstalling"

if [ ! -d "\$driverPath" ]; then
    exit 0
fi

rm -rf "\$driverPath"
pkgutil --forget "$bundleID" > /dev/null 2>&1 || true

EOF
    cat Installer/restart_coreaudio.sh >> "$workDir/scripts/postinstall"
    chmod 755 "$workDir/scripts/postinstall"

    # Build .pkg
    uninstallerPkg="Uninstaller/$driverName $ch Uninstaller $version$pkgSuffix.pkg"
    rm -f "$uninstallerPkg"
    pkgbuild \
      ${installerSignArgs[@]+"${installerSignArgs[@]}"} \
      --nopayload \
      --scripts "$workDir/scripts" \
      --identifier "$bundleID.Uninstaller" \
      --version "$version" \
      "$uninstallerPkg"
    rm -rf "$workDir"

    notarize_and_staple "$uninstallerPkg"

    echo "✅ $uninstallerPkg"
done
