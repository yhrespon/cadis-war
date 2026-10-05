#!/usr/bin/env bash
set -euo pipefail

GODOT_VERSION="4.7.2"
CMDLINE_TOOLS_VERSION="11076708"
ANDROID_HOME="${ANDROID_HOME:-$HOME/android-sdk}"
JAVA_HOME="${JAVA_HOME:-/usr/lib/jvm/java-17-openjdk-amd64}"
export ANDROID_HOME ANDROID_SDK_ROOT="$ANDROID_HOME" JAVA_HOME
export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/build-tools/34.0.0:$PATH"

sudo apt update
sudo apt install -y openjdk-17-jdk wget unzip python3-pip

mkdir -p "$ANDROID_HOME/cmdline-tools"
if [ ! -x "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" ]; then
  tmp="$(mktemp -d)"
  wget -q "https://dl.google.com/android/repository/commandlinetools-linux-${CMDLINE_TOOLS_VERSION}_latest.zip" -O "$tmp/tools.zip"
  rm -rf "$ANDROID_HOME/cmdline-tools/latest" "$tmp/cmdline-tools"
  unzip -q "$tmp/tools.zip" -d "$tmp"
  mv "$tmp/cmdline-tools" "$ANDROID_HOME/cmdline-tools/latest"
  rm -rf "$tmp"
fi

yes | sdkmanager --licenses >/dev/null || true
sdkmanager "platform-tools" "build-tools;34.0.0" "platforms;android-34"

TEMPLATES="$HOME/.local/share/godot/export_templates/${GODOT_VERSION}.stable"
mkdir -p "$TEMPLATES"
if [ ! -f "$TEMPLATES/android_debug.apk" ]; then
  tmp="$(mktemp -d)"
  wget -q "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_export_templates.tpz" -O "$tmp/templates.tpz"
  unzip -q "$tmp/templates.tpz" -d "$tmp"
  cp "$tmp/templates"/* "$TEMPLATES"/
  rm -rf "$tmp"
fi

mkdir -p "$HOME/.config/godot"
settings="$HOME/.config/godot/editor_settings-4.7.tres"
if [ ! -f "$settings" ]; then
  cat > "$settings" <<SETTINGS
[gd_resource type="EditorSettings" format=3]

[resource]
export/android/java_sdk_path = "$JAVA_HOME"
export/android/android_sdk_path = "$ANDROID_HOME"
SETTINGS
else
  sed -i "s#^export/android/java_sdk_path = .*#export/android/java_sdk_path = \"$JAVA_HOME\"#" "$settings" || true
  sed -i "s#^export/android/android_sdk_path = .*#export/android/android_sdk_path = \"$ANDROID_HOME\"#" "$settings" || true
fi

cat > "$HOME/.cadis-android.env" <<ENV
export ANDROID_HOME="$ANDROID_HOME"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export JAVA_HOME="$JAVA_HOME"
export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/build-tools/34.0.0:\$PATH"
ENV

printf '\nEnvironment CADIS installé. Pour chaque nouveau terminal :\nsource "$HOME/.cadis-android.env"\n'
java -version
sdkmanager --list_installed | grep -E 'platform-tools|build-tools;34.0.0|platforms;android-34' || true
