param (
    [switch]$patch,
    [switch]$minor,
    [switch]$major
)

Write-Host "Bumping release version..."
if ($major) {
    dart run cider bump major
} elseif ($minor) {
    dart run cider bump minor
} elseif ($patch) {
    dart run cider bump patch
} else {
    dart run cider bump build
}

Write-Host "Version bumped successfully!"
Write-Host "Building for Android..."
flutter build apk --release

Write-Host "Building for Windows..."
flutter build windows --release

Write-Host "Building MSIX..."
dart run msix:create

Write-Host "Build complete!"
