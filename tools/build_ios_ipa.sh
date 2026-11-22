#!/usr/bin/env bash
# Build the exported device app and wrap the .app in an IPA without Apple signing.
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
    printf 'Usage: bash %s XCODE_EXPORT_DIRECTORY [OUTPUT.ipa]\n' "$0" >&2
    exit 2
fi

if [[ "$(uname -s)" != Darwin ]] || ! xcrun --sdk iphoneos --show-sdk-path >/dev/null; then
    printf 'This build requires macOS with Xcode and the iPhoneOS SDK.\n' >&2
    exit 1
fi

project_dir="$(cd -- "$1" && pwd)"
project_name="GTA_MAZEIKIAI"
project="$project_dir/$project_name.xcodeproj"
output="${2:-$PWD/$project_name.ipa}"

if [[ ! -f "$project/project.pbxproj" || ! -f "$project_dir/$project_name.pck" ]]; then
    printf 'Extract the entire iOS Xcode ZIP and pass its directory.\n' >&2
    exit 1
fi

if [[ "$output" != *.ipa || -e "$output" ]]; then
    printf 'The output must be a new .ipa file.\n' >&2
    exit 1
fi

work_dir="$(mktemp -d)"
trap 'rm -rf -- "$work_dir"' EXIT

xcodebuild -project "$project" -scheme "$project_name" -configuration Debug \
    -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath "$work_dir/build" \
    CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= ARCHS=arm64 build

app="$work_dir/build/Build/Products/Debug-iphoneos/$project_name.app"
executable="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$app/Info.plist")"
minimum="$(/usr/libexec/PlistBuddy -c 'Print :MinimumOSVersion' "$app/Info.plist")"
if [[ "$minimum" != 15.0 || ! -f "$app/$project_name.pck" ]]; then
    printf 'The app must target iOS 15.0 and contain its game pack.\n' >&2
    exit 1
fi
xcrun lipo -verify_arch arm64 "$app/$executable"

mkdir "$work_dir/Payload"
ditto "$app" "$work_dir/Payload/$project_name.app"
ditto -c -k --norsrc --keepParent "$work_dir/Payload" "$work_dir/$project_name.ipa"
mv -n "$work_dir/$project_name.ipa" "$output"
if [[ -e "$work_dir/$project_name.ipa" ]]; then
    printf 'The output already exists. Choose a new path.\n' >&2
    exit 1
fi
printf 'Built %s\n' "$output"

