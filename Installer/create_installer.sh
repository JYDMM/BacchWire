#!/bin/bash
set -euo pipefail

# Creates a signed (and optionally notarized) BACCH Router installer for each channel variant.
# Run this script from the repo root:
#   ./Installer/create_installer.sh
#
# Distribution builds need both Developer ID certificates for the team in the login keychain
# (Xcode > Settings > Apple Accounts > Manage Certificates):
#   - Developer ID Application  (signs the driver)
#   - Developer ID Installer    (signs the .pkg)
# and a notarytool keychain profile:
#   xcrun notarytool store-credentials notarize --team-id AYM3TY69AP --apple-id <apple id>
#
# Every setting below can be overridden from the environment. For a local test build without
# Developer ID certificates:
#   APP_IDENTITY="Apple Development" INSTALLER_IDENTITY="" NOTARIZE=false ./Installer/create_installer.sh
# If several certificates share a name, set the identity to the SHA-1 hash from `security find-identity -v`.

driverName="BACCH Router"   # Shown in Audio MIDI Setup, the bundle name and the installer
driverID="BACCHRouter"      # Used where spaces are not allowed (bundle IDs)
bundleIDPrefix="audio.TAP"
devTeamID="${DEV_TEAM_ID:-AYM3TY69AP}"
appIdentity="${APP_IDENTITY-Developer ID Application}"          # Empty string = don't sign the driver
installerIdentity="${INSTALLER_IDENTITY-Developer ID Installer}" # Empty string = unsigned .pkg
notarize="${NOTARIZE:-true}"
notarizeProfile="${NOTARIZE_PROFILE:-notarize}"
channelVariants="${CHANNELS:-2 16}"
minOSVersion="12.4"         # Matches MACOSX_DEPLOYMENT_TARGET of the BlackHole target

############################################################################

# Basic Validation
if [ ! -d BlackHole.xcodeproj ]; then
    echo "This script must be run from the repo root folder."
    echo "For example:"
    echo "  cd /path/to/Audio4Stratos"
    echo "  ./Installer/create_installer.sh"
    exit 1
fi

version=$(cat VERSION)

if [ -z "$version" ]; then
    echo "Could not find version number. VERSION file is missing from repo root or is empty."
    exit 1
fi

# Resolve a signing identity to exactly one certificate (preferring this team's), so a partial
# name like "Developer ID Application" can't silently pick the wrong one.
resolve_identity() { # $1 = name or SHA-1 hash, $2 = security policy args
    local matches
    if [[ "$1" =~ ^[0-9A-Fa-f]{40}$ ]]; then
        echo "$1"
        return
    fi
    matches=$(security find-identity -v $2 | grep "\"$1" | grep "($devTeamID)\"" || true)
    if [ -z "$matches" ]; then
        matches=$(security find-identity -v $2 | grep "\"$1" || true)
    fi
    if [ "$(printf '%s\n' "$matches" | grep -c .)" -ne 1 ]; then
        echo "❌ Expected exactly one \"$1\" signing identity for team $devTeamID, found:" >&2
        printf '%s\n' "${matches:-  (none)}" >&2
        echo "   Add the certificate in Xcode > Settings > Apple Accounts > Manage Certificates," >&2
        echo "   or set APP_IDENTITY / INSTALLER_IDENTITY to the certificate's SHA-1 hash." >&2
        exit 1
    fi
    printf '%s\n' "$matches" | awk '{print $2}'
}

appSignArgs=()
if [ -n "$appIdentity" ]; then
    appIdentityHash=$(resolve_identity "$appIdentity" "-p codesigning")
    appSignArgs=(--sign "$appIdentityHash")
fi

installerSignArgs=()
pkgSuffix=""
if [ -n "$installerIdentity" ]; then
    installerIdentityHash=$(resolve_identity "$installerIdentity" "")
    installerSignArgs=(--sign "$installerIdentityHash")
else
    echo "⚠️  INSTALLER_IDENTITY is empty: the installer packages will NOT be signed."
    pkgSuffix="-UNSIGNED"
    notarize=false
fi

for channels in $channelVariants; do
    # Env
    ch=$channels"ch"
    bundleID="$bundleIDPrefix.$driverID$ch"
    driverBundleName="$driverName $ch.driver"
    workDir=$(mktemp -d)

    # Build
    xcodebuild \
      -project BlackHole.xcodeproj \
      -configuration Release \
      -target BlackHole CONFIGURATION_BUILD_DIR="$workDir/build" \
      SYMROOT="$workDir/sym" OBJROOT="$workDir/obj" \
      PRODUCT_NAME="$driverName" \
      PRODUCT_BUNDLE_IDENTIFIER=$bundleID \
      CODE_SIGNING_ALLOWED=NO \
      GCC_PREPROCESSOR_DEFINITIONS='$GCC_PREPROCESSOR_DEFINITIONS
      kNumber_Of_Channels='$channels'
      kPlugIn_BundleID=\"'$bundleID'\"'

    # Generate a new UUID so different channel variants can be installed side by side
    uuid=$(uuidgen)
    builtDriver="$workDir/build/$driverName.driver"
    awk '{sub(/e395c745-4eea-4d94-bb92-46224221047c/,"'$uuid'")}1' "$builtDriver/Contents/Info.plist" > "$workDir/Temp.plist"
    mv "$workDir/Temp.plist" "$builtDriver/Contents/Info.plist"

    mkdir "$workDir/root"
    mv "$builtDriver" "$workDir/root/$driverBundleName"

    # Sign
    if [ ${#appSignArgs[@]} -gt 0 ]; then
        codesign \
          --force \
          --deep \
          --options runtime \
          --timestamp \
          "${appSignArgs[@]}" \
          "$workDir/root/$driverBundleName"
        codesign --verify --strict --verbose=2 "$workDir/root/$driverBundleName"
    fi

    # Install scripts. Earlier builds were named "BacchWire<n>ch" and "BACCHRouter <n>Ch" and publish
    # the same device UIDs, so remove them before installing this variant.
    mkdir "$workDir/scripts"
    cat > "$workDir/scripts/preinstall" <<EOF
#!/bin/sh
halDir="/Library/Audio/Plug-Ins/HAL"
mkdir -p "\$halDir"
chown root:wheel "\$halDir"
chmod 755 "\$halDir"
rm -rf "\$halDir/BacchWire$ch.driver" "\$halDir/BACCHRouter ${channels}Ch.driver" "\$halDir/$driverBundleName"
EOF
    cat > "$workDir/scripts/postinstall" <<EOF
#!/bin/sh
driverPath="/Library/Audio/Plug-Ins/HAL/$driverBundleName"
chown -R root:wheel "\$driverPath"
find "\$driverPath" -type d -exec chmod 755 {} \;
find "\$driverPath" -type f -exec chmod 644 {} \;
find "\$driverPath/Contents/MacOS" -type f -exec chmod 755 {} \;

EOF
    cat Installer/restart_coreaudio.sh >> "$workDir/scripts/postinstall"
    chmod 755 "$workDir/scripts/preinstall" "$workDir/scripts/postinstall"

    # Don't let Installer "relocate" the driver into another copy with the same bundle ID
    # (e.g. an Xcode build in DerivedData) instead of the HAL folder. Version checking is off
    # because preinstall removes the existing driver, so a skipped bundle would leave none.
    pkgbuild --analyze --root "$workDir/root" "$workDir/component.plist"
    plutil -replace 0.BundleIsRelocatable -bool NO "$workDir/component.plist"
    plutil -replace 0.BundleIsVersionChecked -bool NO "$workDir/component.plist"

    # Create package with pkgbuild
    pkgbuild \
      ${installerSignArgs[@]+"${installerSignArgs[@]}"} \
      --root "$workDir/root" \
      --component-plist "$workDir/component.plist" \
      --scripts "$workDir/scripts" \
      --identifier "$bundleID" \
      --version "$version" \
      --install-location /Library/Audio/Plug-Ins/HAL \
      "$workDir/$driverID.pkg"

    # Create installer with productbuild
    cat > "$workDir/distribution.xml" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<installer-gui-script minSpecVersion="2">
    <title>$driverName ($ch) $version</title>
    <welcome file="welcome.html"/>
    <license file="LICENSE"/>
    <conclusion file="conclusion.html"/>
    <domains enable_anywhere="false" enable_currentUserHome="false" enable_localSystem="true"/>
    <pkg-ref id="$bundleID"/>
    <options customize="never" require-scripts="false" hostArchitectures="x86_64,arm64"/>
    <volume-check>
        <allowed-os-versions>
            <os-version min="$minOSVersion"/>
        </allowed-os-versions>
    </volume-check>
    <choices-outline>
        <line choice="$bundleID"/>
    </choices-outline>
    <choice id="$bundleID" visible="true" title="$driverName $ch" start_selected="true">
        <pkg-ref id="$bundleID"/>
    </choice>
    <pkg-ref id="$bundleID" version="$version" onConclusion="None">$driverID.pkg</pkg-ref>
</installer-gui-script>
EOF

    mkdir "$workDir/resources"
    cp Installer/welcome.html Installer/conclusion.html LICENSE "$workDir/resources/"

    installerPkg="Installer/$driverName $ch $version$pkgSuffix.pkg"
    rm -f "$installerPkg"
    productbuild \
      ${installerSignArgs[@]+"${installerSignArgs[@]}"} \
      --distribution "$workDir/distribution.xml" \
      --resources "$workDir/resources" \
      --package-path "$workDir" \
      "$installerPkg"
    rm -rf "$workDir"

    # Notarize and Staple
    if [ "$notarize" = true ]; then
        xcrun \
          notarytool submit "$installerPkg" \
          --progress \
          --wait \
          --keychain-profile "$notarizeProfile"

        xcrun stapler staple "$installerPkg"
    fi

    echo "✅ $installerPkg"
done
