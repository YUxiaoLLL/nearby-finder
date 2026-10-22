#!/bin/bash
set -eu
cd "$(dirname "$0")"
if ! xcrun --find swift >/dev/null 2>&1 || ! xcodebuild -version >/dev/null 2>&1; then
  echo '请先安装并打开完整版 Xcode，完成首次初始化。若提示开发目录错误，在 Xcode Settings > Locations 选择 Command Line Tools。'
  exit 1
fi
check_file=$(mktemp -t SuuntoSignalChecks)
trap 'rm -f "$check_file"' EXIT
cat SuuntoFinder/SignalWindow.swift SuuntoFinder/SignalGuideController.swift SuuntoFinder/DeviceLibrary.swift Checks/SignalWindowChecks.swift > "$check_file"
swift_check_file="${check_file}.swift"
mv "$check_file" "$swift_check_file"
trap 'rm -f "$swift_check_file"' EXIT
xcrun swift -module-cache-path /tmp/SuuntoFinderSwiftCache "$swift_check_file"
xcodebuild -project SuuntoFinder.xcodeproj -scheme SuuntoFinder -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath /tmp/SuuntoFinderBuild CODE_SIGNING_ALLOWED=NO build > BuildCheck.log 2>&1 || { tail -n 80 BuildCheck.log; exit 1; }
echo 'BUILD SUCCEEDED。此检查未签名、未安装到 iPhone。可将 BuildCheck.log 发回排查。'
