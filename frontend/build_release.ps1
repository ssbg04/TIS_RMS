param (
    [switch]$patch,
    [switch]$minor,
    [switch]$major,
    [switch]$buildOnly
)

$ErrorActionPreference = 'Stop'

Write-Host "Bumping release version..."
if ($major) {
    dart run cider bump major --bump-build
} elseif ($minor) {
    dart run cider bump minor --bump-build
} elseif ($buildOnly) {
    dart run cider bump build
} else {
    # Default to bumping patch version and build number on every release
    dart run cider bump patch --bump-build
}

# Read newly bumped version from pubspec.yaml
$versionLine = Get-Content pubspec.yaml | Select-String '^version:' | Select-Object -First 1
if (-not $versionLine) {
    throw "Could not find version: in pubspec.yaml"
}

$rawVer = ($versionLine.Line -split ':', 2)[1].Trim()
$verParts = $rawVer.Split('+')
$verName = $verParts[0]
$buildNumber = if ($verParts.Length -ge 2) { $verParts[1] } else { "1" }

Write-Host "New Version : $verName"
Write-Host "Build Number: $buildNumber"

# Sync msix_version in pubspec.yaml
$msixVer = "$verName.$buildNumber"
$pubspecContent = Get-Content pubspec.yaml
$updatedPubspec = $pubspecContent -replace '^\s*msix_version:.*', "  msix_version: $msixVer"
Set-Content -Path pubspec.yaml -Value $updatedPubspec -Encoding utf8

Write-Host "Version bumped successfully to $verName+$buildNumber!"

Write-Host "Building for Android..."
flutter build apk --release --obfuscate --split-debug-info=build/app/outputs/symbols --build-name=$verName --build-number=$buildNumber

Write-Host "Building for Windows..."
flutter build windows --release --obfuscate --split-debug-info=build/windows/symbols --build-name=$verName --build-number=$buildNumber

Write-Host "Building MSIX..."
dart run msix:create

Write-Host "Build complete for version $verName (Build $buildNumber)!"
