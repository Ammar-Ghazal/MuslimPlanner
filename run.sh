#!/bin/zsh
set -e

PROJECT="MuslimPlanner.xcodeproj"
SCHEME="MuslimPlanner"
CONFIG="Debug"
DERIVED_DATA="$HOME/Library/Developer/Xcode/DerivedData"

echo "Building..."
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -sdk macosx \
  -destination "platform=macOS,variant=Mac Catalyst" \
  -configuration "$CONFIG" \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=YES \
  build 2>&1 | grep -E "error:|warning:|\*\* BUILD"

APP_PATH=$(find "$DERIVED_DATA" -path "*/Debug-maccatalyst/MuslimPlanner.app" | head -1)

if [[ -z "$APP_PATH" ]]; then
  echo "Error: Could not find built app"
  exit 1
fi

pkill -x MuslimPlanner 2>/dev/null || true
sleep 1

echo "Launching $APP_PATH"
open "$APP_PATH"
