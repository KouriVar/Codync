#!/bin/sh
# Builds the Kotlin Multiplatform shared layer into an XCFramework for DSHKit.
#
# P1 does not link this yet (the first slice is Swift-only). P2 does, so the build path is
# kept here and exercised now. The output lives under Vendor/ and is git-ignored: it is a
# build product, not source.
#
# Toolchain notes (no system-wide changes):
#   - DEVELOPER_DIR points Kotlin/Native's xcrun at the full Xcode, without running
#     `xcode-select`. The machine's `xcode-select` stays on CommandLineTools.
#   - JAVA_HOME points at Homebrew's JDK 17, which is not on PATH by default.
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
DSH_MOBILE=${DSH_MOBILE:-/Users/halfsignal/Documents/配置目录/软件目录/默认文件-Codex/默认目录/dsh-mobile-setup/dsh-mobile}
OUT="$HERE/Vendor"

export DEVELOPER_DIR=${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}
export JAVA_HOME=${JAVA_HOME:-/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home}
export ANDROID_HOME=${ANDROID_HOME:-$HOME/Library/Android/sdk}

echo "== building the arm64 release framework =="
(cd "$DSH_MOBILE" && ./gradlew :shared:linkReleaseFrameworkIosArm64 --console=plain)

FRAMEWORKS="$DSH_MOBILE/shared/build/bin/iosArm64/releaseFramework/DeepSeekHarnessShared.framework"

# The simulator slice needs androidx.sqlite's simulator cinterop klib, which is not in the
# Gradle cache on this machine. Build it when the network allows and merge it in.
if [ "${WITH_SIMULATOR:-1}" = "1" ]; then
	echo "== building the simulator arm64 release framework (needs network) =="
	if (cd "$DSH_MOBILE" && ./gradlew :shared:linkReleaseFrameworkIosSimulatorArm64 --console=plain); then
		SIM="$DSH_MOBILE/shared/build/bin/iosSimulatorArm64/releaseFramework/DeepSeekHarnessShared.framework"
	else
		echo "  simulator slice unavailable; the XCFramework will hold the device slice only" >&2
		SIM=""
	fi
else
	SIM=""
fi

mkdir -p "$OUT"
rm -rf "$OUT/DeepSeekHarnessShared.xcframework"
if [ -n "$SIM" ] && [ -d "$SIM" ]; then
	xcodebuild -create-xcframework -framework "$FRAMEWORKS" -framework "$SIM" -output "$OUT/DeepSeekHarnessShared.xcframework"
else
	xcodebuild -create-xcframework -framework "$FRAMEWORKS" -output "$OUT/DeepSeekHarnessShared.xcframework"
fi

echo "== done =="
du -sh "$OUT/DeepSeekHarnessShared.xcframework"
