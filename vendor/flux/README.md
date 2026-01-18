# Synheart Flux Native Libraries

This directory contains vendored Flux native binaries for each platform.

**Source:** https://github.com/synheart-ai/synheart-flux

## Structure

```
vendor/flux/
├── VERSION                    # Pinned Flux version (e.g., v0.1.0)
├── README.md                  # This file
├── android/
│   └── jniLibs/
│       ├── arm64-v8a/         # libsynheart_flux.so (ARM64)
│       ├── armeabi-v7a/       # libsynheart_flux.so (ARMv7)
│       └── x86_64/            # libsynheart_flux.so (x86_64)
├── ios/
│   └── SynheartFlux.xcframework
└── desktop/
    ├── mac/                   # libsynheart_flux.dylib
    ├── win/                   # synheart_flux.dll
    └── linux/                 # libsynheart_flux.so
```

## Release Artifacts

The following artifacts are available from [Flux releases](https://github.com/synheart-ai/synheart-flux/releases):

| Artifact | Platform | Contents |
|----------|----------|----------|
| `synheart-flux-android-jniLibs.tar.gz` | Android | JNI libs for arm64-v8a, armeabi-v7a, x86_64 |
| `synheart-flux-ios-xcframework.zip` | iOS | Universal XCFramework |
| `synheart-flux-desktop-macos-arm64.tar.gz` | macOS | ARM64 dylib |
| `synheart-flux-desktop-linux-x86_64.tar.gz` | Linux | x86_64 shared lib |
| `synheart-flux-desktop-windows-x86_64.zip` | Windows | x86_64 DLL |

## CI/CD Integration

On Wear release, CI should:

1. Read the Flux version from `VERSION`
2. Download Flux artifacts from GitHub Releases by tag
3. Place them into the appropriate directories
4. Build Wear artifacts
5. Publish Wear

### Example CI Script

```bash
FLUX_VERSION=$(cat vendor/flux/VERSION)
FLUX_BASE_URL="https://github.com/synheart-ai/synheart-flux/releases/download/${FLUX_VERSION}"

# Download and extract Android JNI libs
curl -L "${FLUX_BASE_URL}/synheart-flux-android-jniLibs.tar.gz" -o /tmp/flux-android.tar.gz
tar -xzf /tmp/flux-android.tar.gz -C vendor/flux/android/

# Download and extract iOS xcframework
curl -L "${FLUX_BASE_URL}/synheart-flux-ios-xcframework.zip" -o /tmp/flux-ios.zip
unzip -o /tmp/flux-ios.zip -d vendor/flux/ios/

# Download desktop libraries (optional)
curl -L "${FLUX_BASE_URL}/synheart-flux-desktop-macos-arm64.tar.gz" -o /tmp/flux-mac.tar.gz
tar -xzf /tmp/flux-mac.tar.gz -C vendor/flux/desktop/mac/

curl -L "${FLUX_BASE_URL}/synheart-flux-desktop-linux-x86_64.tar.gz" -o /tmp/flux-linux.tar.gz
tar -xzf /tmp/flux-linux.tar.gz -C vendor/flux/desktop/linux/

curl -L "${FLUX_BASE_URL}/synheart-flux-desktop-windows-x86_64.zip" -o /tmp/flux-win.zip
unzip -o /tmp/flux-win.zip -d vendor/flux/desktop/win/
```

## Versioning

When updating Flux:

1. Update the `VERSION` file with the new tag (e.g., `v0.2.0`)
2. CI will automatically fetch the new binaries on next release
3. Add to release notes: "Bundled Flux: vX.Y.Z"

## Current Implementation Note

The current Dart implementation in `lib/src/flux/` is a pure Dart port of the Flux pipeline.
This allows development and testing without native binaries. When native libraries are available,
FFI bindings can be added to call the Rust implementation for improved performance.
