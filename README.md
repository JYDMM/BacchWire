# BACCH Router: Audio Loopback Driver

![Platform: macOS](https://img.shields.io/badge/platform-macOS-lightgrey)
[![License: GPL-3.0](https://img.shields.io/badge/license-GPL--3.0-blue)](LICENSE)

BACCH Router is a renamed fork of BlackHole, a modern macOS virtual audio loopback driver that allows applications to pass audio to other applications with zero additional latency.

BACCH Router is free, standalone software. It is not bundled with any commercially available software.

## Table of Contents

- [Features](#features)
- [Installation Instructions](#installation-instructions)
- [Uninstallation Instructions](#uninstallation-instructions)
- [Developer Guides](#developer-guides)
- [FAQ](#faq)
- [License and Attribution](#license-and-attribution)

## Features

- Builds 2, 16 ~~, 64, 128, and 256~~ audio channels versions
- Customizable channel count, latency, hidden devices
- Customizable mirror device to allow for a hidden input or output
- Supports ~~8kHz, 16kHz, 32k,~~ 44.1kHz, 48kHz, 88.2kHz, 96kHz, 176.4kHz, and 192kHz, ~~352.8kHz~~, 384kHz ~~, 705.6kHz and 768kHz~~ sample rates
- Zero additional driver latency
- Compatible with macOS 12.4 Monterey and newer
- Builds for Intel and Apple Silicon
- No kernel extensions or modifications to system security necessary

## Installation Instructions

BACCH Router comes in 2ch and 16ch versions.

1. Close all running audio applications
2. Open and install the package for the version you want
3. When prompted, choose **Restart Audio**. Audio stops for a moment in all applications while the macOS audio service restarts. If you choose **Not Now**, BACCH Router will appear after you restart your Mac.

Earlier versions installed as "BacchWire" or "BACCHRouter" are replaced by the installer with the same channel count.

## Uninstallation Instructions

### Option 1: Use Uninstaller

Open the BACCH Router uninstaller package for your version. When prompted, choose **Restart Audio**.

### Option 2: Manually Uninstall

1. Delete the driver with the terminal command:

    `sudo rm -R "/Library/Audio/Plug-Ins/HAL/BACCH Router Xch.driver"`

   Be sure to replace `X` with either `2` or `16`.

   Note that the directory is the root `/Library` not `/Users/user/Library`.

2. Restart CoreAudio with the terminal command:

    `sudo killall -9 coreaudiod`

## Developer Guides

### A license is required for all non-GPLv3 projects

BACCH Router is based on BlackHole, which requires a license for all non-GPLv3 projects. To request a license [contact Existential Audio](mailto:devinroth@existential.audio).

### Build & Install

The Xcode project and target are named `BlackHole`, so a plain Xcode build produces `BlackHole.driver`. To build the named 2ch and 16ch drivers and their installers, use [create_installer.sh](Installer/create_installer.sh). The uninstallers are built by [create_uninstaller.sh](Uninstaller/create_uninstaller.sh).

To install a build by hand:

1. Copy or move the built `.driver` bundle to `/Library/Audio/Plug-Ins/HAL`
2. Restart CoreAudio using `sudo killall -9 coreaudiod`

### Customizing BACCH Router

The following pre-compiler constants may be used to easily customize a build of BACCH Router.

```
kDriver_Name
kDriver_UID_Name
kPlugIn_BundleID
kPlugIn_Icon

kDevice_Name
kDevice_IsHidden
kDevice_HasInput
kDevice_HasOutput

kDevice2_Name
kDevice2_IsHidden
kDevice2_HasInput
kDevice2_HasOutput

kLatency_Frame_Size
kNumber_Of_Channels
kSampleRates
```

They can be specified at build time with `xcodebuild` using `GCC_PREPROCESSOR_DEFINITIONS`.

Example:

```bash
xcodebuild \
  -project BlackHole.xcodeproj \
  GCC_PREPROCESSOR_DEFINITIONS='$GCC_PREPROCESSOR_DEFINITIONS kSomeConstant=value'
```

Be sure to escape any quotation marks when using strings. `GCC_PREPROCESSOR_DEFINITIONS` is a space-separated list, so it's simplest to set values containing spaces in `BlackHole/BlackHole.c` instead. The default `kDriver_Name` of `BACCH Router` is set there for this reason.

### Renaming the Driver

To rename the driver it is required to change the following constants.
- `kDriver_Name`
- `kDriver_UID_Name` (the prefix for device UIDs, which apps use to remember a device)
- `kPlugIn_BundleID` (note that this must match the target bundleID, or the device logo won't appear)
- `kPlugIn_Icon`

These can specified as pre-compiler constants using ```xcodebuild```.

```bash
driverName="MyDriver"
bundleID="com.example.MyDriver"
icon="BlackHole.icns"

xcodebuild \
  -project BlackHole.xcodeproj \
  -configuration Release \
  PRODUCT_BUNDLE_IDENTIFIER=$bundleID \
  GCC_PREPROCESSOR_DEFINITIONS='$GCC_PREPROCESSOR_DEFINITIONS
  kDriver_Name=\"'$driverName'\"
  kDriver_UID_Name=\"'$driverName'\"
  kPlugIn_BundleID=\"'$bundleID'\"
  kPlugIn_Icon=\"'$icon'\"'
```

### Customizing Channels, Latency, and Sample Rates

`kNumber_Of_Channels` is used to set the number of channels. Be careful when specifying high channel counts. Although BACCH Router is designed to be extremely efficient at higher channel counts it's possible that your computer might not be able to keep up. Sample rates play a role as well. Don't use high sample rates with a high number of channels. Some applications don't know how to handle high channel counts. Proceed with caution.

`kLatency_Frame_Size` is how much time in frames that the driver has to process incoming and outgoing audio. It can be used to delay the audio inside of BACCH Router up to a maximum of 65536 frames. This may be helpful if using BACCH Router with a high channel count.

`kSampleRates` set the sample rate or sample rates of the audio device. If using multiple sample rates separate each with a comma (`,`). For example: `kSampleRates='44100,48000'`.

### Mirror Device

By default BACCH Router has a hidden mirrored audio device. The devices may be customized using the following constants.

```
// Original Device
kDevice_IsHidden
kDevice_HasInput
kDevice_HasOutput

// Mirrored Device
kDevice2_IsHidden
kDevice2_HasInput
kDevice2_HasOutput
```

When all are set to true a 2nd BACCH Router will show up that works exactly the same. The inputs and outputs are mirrored so the outputs from both devices go to the inputs of both devices.

This is useful if you need a separate device for input and output.

Example

```
// Original Device
kDevice_IsHidden=false
kDevice_HasInput=true
kDevice_HasOutput=false

// Mirrored Device
kDevice2_IsHidden=false
kDevice2_HasInput=false
kDevice2_HasOutput=true
```

In this situation we have two BACCH Router devices. One will have inputs only and the other will have outputs only.

One way to use this in projects is to hide the mirrored device and use it behind the scenes. That way the user will see an input only device while routing audio through to the output behind them scenes.

Hidden audio devices can be accessed using `kAudioHardwarePropertyTranslateUIDToDevice`.

### Continuous Integration / Continuous Deployment

BACCH Router can be integrated into your CI/CD. Take a look at the [create_installer.sh](Installer/create_installer.sh) shell script to see how the installer is built, signed and notarized.

## FAQ

### Why isn't BACCH Router showing up in the Applications folder?

BACCH Router is a virtual audio loopback driver. It only shows up in `Audio MIDI Setup`, `Sound Settings`, or other audio applications.

### How can I listen to the audio and use BACCH Router at the same time?

Set up a Multi-Output Device in `Audio MIDI Setup` that includes BACCH Router and your speakers or headphones.

### What bit depth does BACCH Router use, and can I change it?

BACCH Router uses 32-bit float bit depth since macOS Core Audio natively uses 32-bit at the system level. This provides the broadest compatibility and greatest audio headroom.

This format is lossless for up to 24-bit integer. All applications should be able to playback and record audio, and do not require adjusting bit depth at the BACCH Router driver level.

### How can I change the volume of a Multi-Output device?

Unfortunately macOS does not support changing the volume of a Multi-Output device but you can set the volume of individual devices in Audio MIDI Setup.

### Why is nothing playing through BACCH Router?

- Check `System Settings` → `Privacy & Security` → `Microphone` to make sure your digital audio workstation (DAW) application has microphone access.

- Check that the volume is all the way up on BACCH Router input and output in ``Audio MIDI Setup``.

- If you are using a multi-output device, due to issues with macOS the Built-in Output must be enabled and listed as the top device in the Multi-Output.

### Why is audio glitching after X minutes when using a multi-output or an aggregate?

- You need to enable drift correction for all devices except the Clock Source also known as Master Device or Primary Device.

### Why is the Installer failing?

- Certain versions of macOS have a known issue where install packages may fail to install when the install package is located in certain folders. If you downloaded the .pkg file to your Downloads folder, try moving it to the Desktop and open the .pkg again (or vice-versa).

### What Apps Don't Work with Multi-Outputs?

Unfortunately multi-outputs can be buggy and some apps won't work with them at all. Here is a list of known ones. If additional incompatible applications are found, please report them by opening an [issue](https://github.com/JYDMM/BacchWire/issues).

- Apple Podcasts
- Apple Messages
- HDHomeRun

### AirPods with an Aggregate/Multi-Output is not working.

The microphone from AirPods runs at a lower sample rate which means it should not be used as the primary/clock device in an Aggregate or Multi-Output device. The solution is to use your built-in speakers (and just mute them) or BACCH Router 2ch as the primary/clock device. BACCH Router 16ch will not work as the primary since the primary needs to have 2ch.

### Can I integrate BACCH Router into my app?

BACCH Router is licensed under GPL-3.0. You can use BACCH Router as long as your app is also licensed as GPL-3.0. For all other applications please [contact Existential Audio directly](mailto:devinroth@existential.audio).

## License and Attribution

BACCH Router is a modified version of [BlackHole](https://github.com/ExistentialAudio/BlackHole) by Existential Audio Inc. and is licensed under the [GNU General Public License v3.0](LICENSE).

The BlackHole name, logo and related branding are the property of Existential Audio Inc. and are not covered by this license. BACCH Router is not affiliated with or endorsed by Existential Audio Inc.

## Links and Resources

### [MultiSoundChanger](https://github.com/rlxone/MultiSoundChanger)
A small tool for changing sound volume even for aggregate devices cause native sound volume controller can't change volume of aggregate devices
### [BackgroundMusic](https://github.com/kyleneideck/BackgroundMusic)
Background Music, a macOS audio utility: automatically pause your music, set individual apps' volumes and record system audio.
