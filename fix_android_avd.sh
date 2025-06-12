#!/bin/bash

# -------------------------------
# Android Emulator Fix Script
# Author: d3f4ult (for XFCE + DockLike + Android Studio setup)
# -------------------------------

CONFIG_AVD_PATH="$HOME/.config/.android/avd"
DEFAULT_AVD_PATH="$HOME/.android/avd"
SDK_PATH="$HOME/Android/Sdk"

echo "[*] Checking if AVD directory exists at $CONFIG_AVD_PATH..."
if [ ! -d "$CONFIG_AVD_PATH" ]; then
    echo "[!] No AVDs found at $CONFIG_AVD_PATH"
    exit 1
fi

echo "[*] Ensuring ~/.android exists..."
mkdir -p "$HOME/.android"

if [ -L "$DEFAULT_AVD_PATH" ]; then
    echo "[*] ~/.android/avd is already a symlink."
elif [ -d "$DEFAULT_AVD_PATH" ]; then
    echo "[!] ~/.android/avd exists as a directory. Backing it up..."
    mv "$DEFAULT_AVD_PATH" "${DEFAULT_AVD_PATH}_backup_$(date +%s)"
    ln -s "$CONFIG_AVD_PATH" "$DEFAULT_AVD_PATH"
    echo "[+] Symlink created."
else
    echo "[*] Creating symlink: $DEFAULT_AVD_PATH → $CONFIG_AVD_PATH"
    ln -s "$CONFIG_AVD_PATH" "$DEFAULT_AVD_PATH"
    echo "[+] Symlink created."
fi

# Files to update with environment variables
RC_FILES=("$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile")

echo "[*] Updating shell config files with ANDROID_SDK_ROOT and emulator PATH..."
for rc_file in "${RC_FILES[@]}"; do
    if [ -f "$rc_file" ]; then
        if ! grep -q "ANDROID_SDK_ROOT=" "$rc_file"; then
            echo -e "\n# Android SDK environment variables" >> "$rc_file"
            echo "export ANDROID_SDK_ROOT=\"$SDK_PATH\"" >> "$rc_file"
            echo "export PATH=\$ANDROID_SDK_ROOT/emulator:\$ANDROID_SDK_ROOT/tools:\$ANDROID_SDK_ROOT/tools/bin:\$PATH" >> "$rc_file"
            echo "[+] Added to $rc_file"
        else
            echo "[*] ANDROID_SDK_ROOT already defined in $rc_file"
        fi
    fi
done

# Also export for current session
export ANDROID_SDK_ROOT="$SDK_PATH"
export PATH="$ANDROID_SDK_ROOT/emulator:$ANDROID_SDK_ROOT/tools:$ANDROID_SDK_ROOT/tools/bin:$PATH"

echo "[*] Reloading current shell..."
exec "$SHELL"

echo "[✔] Done!"
echo "✅ You can now run: emulator -list-avds && emulator -avd Pixel_3"
echo "📌 If you launch emulator from GUI or XFCE dock, it will now work persistently."

