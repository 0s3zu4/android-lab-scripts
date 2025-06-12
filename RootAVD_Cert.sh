#!/bin/bash
# ============================
#  rootAVD-certify.sh v1.1.50
#  Author: Osezua
# ============================

clear

# Define colors
RED='\033[1;31m'
GREEN='\033[1;32m'
CYAN='\033[1;36m'
YELLOW='\033[1;33m'
MAGENTA='\033[1;35m'
BOLD='\033[1m'
RESET='\033[0m'

echo ""
echo -e "${MAGENTA}┌──────────────────────────────────────────────────────┐"
echo -e "${MAGENTA}│${CYAN}  ${BOLD}rootAVD-certify.sh${RESET} ${YELLOW}v1.1.50${MAGENTA}                          │"
echo -e "${MAGENTA}│${CYAN}  Author: ${BOLD}Osezua${MAGENTA}                    		       │"
echo -e "${MAGENTA}├──────────────────────────────────────────────────────┤"
echo -e "${MAGENTA}│${GREEN}  This script roots an Android Virtual Device (AVD)   ${MAGENTA}│"
echo -e "${MAGENTA}│${GREEN}  and installs a custom CA certificate for testing.   ${MAGENTA}│"
echo -e "${MAGENTA}└──────────────────────────────────────────────────────┘${RESET}"
echo ""
set -e

EMULATOR_CMD="emulator"
ROOT_AVD_PATH="./rootAVD"
MAGISK_VERSION_OPTION="1"

# ==== CHECK DEPENDENCY: expect ====
if ! command -v expect &>/dev/null; then
  echo "[*] 'expect' is not installed. Installing..."

  if command -v apt &>/dev/null; then
    sudo apt update && sudo apt install -y expect
  elif command -v pacman &>/dev/null; then
    sudo pacman -Sy --noconfirm expect
  elif command -v dnf &>/dev/null; then
    sudo dnf install -y expect
  else
    echo "[!] Unsupported package manager. Please install 'expect' manually."
    exit 1
  fi

  echo "[+] 'expect' installed successfully."
else
  echo "[+] 'expect' is already installed."
fi

# ==== CHECK: ADB available ====
if ! command -v adb &> /dev/null; then
  echo "[!] 'adb' is not installed or not in PATH."
  exit 1
fi

# ==== CHECK: rootAVD folder exists ====
if [ ! -d "$ROOT_AVD_PATH" ]; then
  echo "[*] rootAVD folder not found. Downloading from GitLab..."
  if ! command -v git &> /dev/null; then
    echo "[!] Git is not installed. Please install git and try again."
    exit 1
  fi

  git clone https://gitlab.com/newbit/rootAVD.git "$ROOT_AVD_PATH"
  
  if [ $? -ne 0 ]; then
    echo "[!] Failed to clone rootAVD. Check your internet connection or GitLab availability."
    exit 1
  fi

  echo "[+] rootAVD successfully cloned."
fi

# ==== CHECK: AlwaysTrustUserCerts ZIP ====
CERT_MODULE=$(ls AlwaysTrustUserCerts_*.zip 2>/dev/null | head -n 1)

if [ -z "$CERT_MODULE" ]; then
  echo "[!] No AlwaysTrustUserCerts_*.zip found in current directory."
  echo "[*] Attempting to download the latest AlwaysTrustUserCerts release from GitHub..."

  # Fetch the latest release URL using GitHub API
  LATEST_URL=$(curl -s https://api.github.com/repos/NVISOsecurity/AlwaysTrustUserCerts/releases/latest \
    | grep "browser_download_url" \
    | grep "AlwaysTrustUserCerts_.*\.zip" \
    | cut -d '"' -f 4)

  if [[ -z "$LATEST_URL" ]]; then
    echo "[!] Failed to find the latest release URL. Please download manually from:"
    echo "    https://github.com/NVISOsecurity/AlwaysTrustUserCerts/releases"
    exit 1
  fi

  # Extract filename
  CERT_MODULE=$(basename "$LATEST_URL")

  # Download the zip
  echo "[*] Downloading $CERT_MODULE ..."
  curl -L "$LATEST_URL" -o "$CERT_MODULE"

  if [[ $? -ne 0 || ! -f "$CERT_MODULE" ]]; then
    echo "[!] Download failed. Please download manually from:"
    echo "    https://github.com/NVISOsecurity/AlwaysTrustUserCerts/releases"
    exit 1
  fi

  echo "[+] Downloaded $CERT_MODULE successfully."
else
  echo "[+] Found $CERT_MODULE in current directory."
fi

# ==== CHECK: .crt certificate ====
# Check for available .crt files
CRT_FILES=(*.crt)
CRT_COUNT=$(ls *.crt 2>/dev/null | wc -l)

if [ "$CRT_COUNT" -eq 0 ]; then
  echo "[!] No .crt certificate file found in the current directory."
  echo "    Please export the Burp certificate as 'burp.crt' in DER format and place it here."
  exit 1
elif [ "$CRT_COUNT" -eq 1 ]; then
  CRT_FILE="${CRT_FILES[0]}"
  echo "[+] Found certificate: $CRT_FILE"
else
  echo "[*] Multiple .crt files found:"
  select FILE in "${CRT_FILES[@]}"; do
    if [ -n "$FILE" ]; then
      CRT_FILE="$FILE"
      echo "[+] Selected certificate: $CRT_FILE"
      break
    else
      echo "[!] Invalid selection. Try again."
    fi
  done
fi

# ==== SELECT EMULATOR ====
echo "[+] Detecting available emulators..."
available_avds=$($EMULATOR_CMD -list-avds)
if [[ -z "$available_avds" ]]; then
  echo "[!] No AVDs found. Create one via Android Studio first."
  exit 1
fi

select AVD_NAME in $available_avds; do
  if [[ -n "$AVD_NAME" ]]; then
    echo "[+] Selected emulator: $AVD_NAME"
    break
  else
    echo "[!] Invalid selection. Try again."
  fi
done

# ==== DETECT AVD IMAGE PATH AND API LEVEL ====

INI_PATH="$HOME/.android/avd/${AVD_NAME}.ini"
ALT_INI_PATH="$HOME/.config/.android/avd/${AVD_NAME}.ini"
ANDROID_API_LEVEL=""

# Determine which .ini path to use
if [[ -f "$INI_PATH" ]]; then
  echo "[*] Found AVD ini at: $INI_PATH"
  INI_FILE="$INI_PATH"
elif [[ -f "$ALT_INI_PATH" ]]; then
  echo "[*] Found AVD ini at: $ALT_INI_PATH"
  INI_FILE="$ALT_INI_PATH"
else
  echo "[!] Could not find .ini file for AVD $AVD_NAME in expected locations."
  exit 1
fi

# Extract API level from target field
ANDROID_API_LEVEL=$(grep -iE '^target[[:space:]]*=[[:space:]]*android-[0-9]+' "$INI_FILE" | grep -oE '[0-9]+' | tr -d '[:space:]')
if [[ -z "$ANDROID_API_LEVEL" ]]; then
  echo "[!] Failed to detect Android API level from $INI_FILE"
  exit 1
fi

echo "[+] Detected Android API level: $ANDROID_API_LEVEL"

# ==== DETECT ARCHITECTURE ====
echo "[+] Detecting system image architecture..."

ARCH=""

# Try to get from running emulator
if adb get-state 1>/dev/null 2>&1; then
  ARCH=$(adb shell getprop ro.product.cpu.abi 2>/dev/null | tr -d '\r' | xargs)
  echo "[+] Emulator is running. ARCH from adb: $ARCH"
else
  # Try to get from hardware-qemu.ini file
  CONFIG_DIR="$HOME/.config/.android/avd/${AVD_NAME}.avd"
  HARDWARE_QEMU_INI="$CONFIG_DIR/hardware-qemu.ini"

  if [[ -f "$HARDWARE_QEMU_INI" ]]; then
    ARCH=$(grep -i "hw.cpu.arch" "$HARDWARE_QEMU_INI" | cut -d'=' -f2 | tr -d '\r' | xargs)
    echo "[+] Emulator not running. ARCH from hardware-qemu.ini: $ARCH"
  else
    echo "[!] Could not find $HARDWARE_QEMU_INI. Falling back to default arch."
    ARCH="x86_64"
  fi
fi

ARCH=${ARCH:-x86_64}  # Final safety fallback
echo "[+] Detected ARCH: $ARCH"

# ==== LAUNCH EMULATOR ====
echo "[+] Launching emulator..."
nohup $EMULATOR_CMD -avd "$AVD_NAME" -writable-system -no-snapshot-save -netdelay none -netspeed full > /dev/null 2>&1 &
sleep 30

# Wait for boot
echo "[+] Waiting for emulator to boot..."
adb wait-for-device
until [[ "$(adb shell getprop sys.boot_completed | tr -d '\r')" == "1" ]]; do
  sleep 30
done
echo "[+] Emulator booted."

# ==== ROOT USING rootAVD ====
cd "$ROOT_AVD_PATH"
echo "[🪛] Starting interactive rootAVD.sh. Follow the on-screen prompts to patch Magisk."
echo "    When done, press ENTER to continue the script."
./rootAVD.sh system-images/android-$ANDROID_API_LEVEL/google_apis_playstore/$ARCH/ramdisk.img
read -p "[✔] Press ENTER after rootAVD.sh has finished and emulator has shut down..."

# Go back to original directory
cd - >/dev/null

# Safe shutdown
echo "[+] Attempting to shut down emulator (if still running)..."
if adb get-state 2>/dev/null | grep -q "device"; then
  adb emu kill || echo "[!] Failed to kill emulator. It may already be off."
else
  echo "[*] No running emulator detected. Continuing..."
fi
sleep 5

# Ask user if they want to restart
read -p "[?] Do you want to restart the emulator now? (y/N): " restart_choice
restart_choice=${restart_choice,,}  # convert to lowercase

if [[ "$restart_choice" == "y" || "$restart_choice" == "yes" ]]; then
  echo "[+] Restarting emulator..."
  nohup $EMULATOR_CMD -avd "$AVD_NAME" -writable-system -no-snapshot-save -netdelay none -netspeed full > /dev/null 2>&1 &
  sleep 20

  echo "[+] Waiting for emulator to boot..."
  adb wait-for-device
  until [[ "$(adb shell getprop sys.boot_completed | tr -d '\r')" == "1" ]]; do
    sleep 20
  done
  echo "[+] Emulator restarted. Checking root access..."
  adb shell "su -c id" || echo "[!] Manual Magisk confirmation may be required on device."
else
  echo "[*] Emulator restart skipped. You can start it manually later using:"
  echo "    emulator -avd $AVD_NAME -writable-system -no-snapshot-save"
  exit 0
fi

echo "[+] Emulator restarted. Checking root access..."
adb shell "su -c id" || echo "[!] Manual Magisk confirmation may be required on device."

echo "[!] ACTION REQUIRED: Complete Magisk setup manually on the emulator."
sleep 5

adb shell monkey -p com.topjohnwu.magisk -c android.intent.category.LAUNCHER 1

RED='\033[0;31m'
NC='\033[0m' # No Color (reset)

echo ""
echo -e "${RED}🕐  Grant Permission, and Magisk will Reboot.${NC}"
echo ""
echo -e "${RED}✅  Follow the checklist below:${NC}"
echo -e "${RED}   ┌──────────────────────────────────────────────────────────────┐${NC}"
echo -e "${RED}   │ [ ]  Wait for the emulator to fully reboot                   │${NC}"
echo -e "${RED}   │ [ ]  Grant Magisk superuser access when prompted             │${NC}"
echo -e "${RED}   │ [ ]  Let the system reboot (Magisk may auto-reboot)          │${NC}"
echo -e "${RED}   │ [ ]  Wait an additional 10 seconds after the reboot          │${NC}"
echo -e "${RED}   │ [ ]  Don't press ENTER until Emulator has fully rebooted	│${NC}"
echo -e "${RED}   └──────────────────────────────────────────────────────────────┘${NC}"
echo ""
read -p $'\033[0;31m✔️  Press ENTER only after all steps above have completed...\033[0m '
sleep 3

# ==== INSTALL MAGISK MODULE ====
echo ""
echo "[+] Installing Magisk module: $CERT_MODULE"
adb push "$CERT_MODULE" /sdcard/

sleep 2

# ✅ Improved expect script with better error handling
expect <<EOF
set timeout 30
spawn adb shell
expect {
    "*$ " { send "su\n" }
    timeout { puts "\n[!] Timeout waiting for shell prompt"; exit 1 }
}

expect {
    "Permission denied" { puts "\n[!] Root access denied (did you grant SU in Magisk?)"; exit 1 }
    "*# " { send "magisk --install-module /sdcard/${CERT_MODULE}\n" }
    timeout { puts "\n[!] Timeout waiting for root prompt"; exit 1 }
}

expect {
    "Success" { puts "\n[✔] Module installed successfully" }
    "*# " { send "exit\n" }
    timeout { puts "\n[!] Timeout after module install"; exit 1 }
}

expect {
    "*$ " { send "exit\n" }
    timeout { puts "\n[!] Timeout exiting shell"; exit 1 }
}
EOF

# ✅ Continue to install Burp certificate...
echo ""
echo "[🚀] Proceeding with Burp certificate installation..."
# (Your Burp cert install logic continues here)

# ==== PUSH BURP CERT ====
echo "[+] Pushing Burp certificate: $CRT_FILE"
adb push "$CRT_FILE" /sdcard/

# ==== CA CERT INSTALLATION ====
echo "[!] ACTION REQUIRED: Install the CA certificate manually."
echo "    Go to: Settings → Security → Encryption & Credentials → Install from storage → CA Certificate"
adb shell am start -a android.settings.SECURITY_SETTINGS

read -p "Press [Enter] after installing the CA certificate on the emulator..."

# ==== FINAL REBOOT ====
echo "[+] Rebooting to trigger AlwaysTrustUserCerts module..."
adb reboot
adb wait-for-device
until [[ "$(adb shell getprop sys.boot_completed | tr -d '\r')" == "1" ]]; do
  sleep 2
done

echo "[✅] Setup complete. Emulator is rooted and Burp certificate is trusted as a system CA."

