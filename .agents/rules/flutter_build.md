# Flutter Build Rules

When building releases for this repository, always follow these rules to ensure optimal file size, performance, and architecture compatibility.

## 1. Android APK Build Rules
Always build size-optimized APKs supporting both 32-bit and 64-bit architectures using ABI splitting, code obfuscation, and stripped debug info:

```bash
# Split per ABI (recommended for distribution to reduce download sizes to ~25-28MB)
flutter build apk --release --split-per-abi --obfuscate --split-debug-info=./build/symbols

# Output artifacts generated in build/app/outputs/flutter-apk/:
# - app-armeabi-v7a-release.apk (32-bit ARM devices)
# - app-arm64-v8a-release.apk (64-bit ARM devices)
# - app-x86_64-release.apk (64-bit x86 emulators/tablets)

# Universal all-in-one APK (fallback when single installer is needed):
flutter build apk --release --obfuscate --split-debug-info=./build/symbols
# Output artifact: app-release.apk
```

## 2. Windows Build Rules
Always build the Windows Desktop client in release mode with obfuscation and symbol splitting:

```bash
flutter build windows --release --obfuscate --split-debug-info=./build/symbols
# Output directory: build/windows/x64/runner/Release/
```

### Windows Packaging & Dependencies
- Include required Windows Visual C++ / .NET runtime libraries or bundled DLLs when creating standalone/portable zip archives or installers.
- Compress output archives with maximum deflate/LZMA compression for lightweight distribution.
