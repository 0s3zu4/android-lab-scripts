#!/bin/bash

# Burp Suite Certificate Installer for Android 9 (API 28) Emulator
# Author: d3f4ult


# -------------------------
# STEP 1: Dependency check & install
# -------------------------
install_if_missing() {
    local cmd=$1
    local pkg=$2

    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "[!] $cmd not found. Installing..."
        if command -v apt >/dev/null 2>&1; then
            sudo apt update
            sudo apt install -y "$pkg"
        else
            echo "[!] Unsupported OS. Please install '$pkg' manually."
            exit 1
        fi
    fi
}

install_if_missing openssl openssl
install_if_missing adb android-tools-adb
install_if_missing emulator android-sdk

# -------------------------
# STEP 2: Cert File Check
# -------------------------
# -------------------------
# STEP 2: Detect .der Cert Files
# -------------------------
DER_CERTS=($(find . -maxdepth 1 -type f -iname "*.der" | sed 's|^\./||'))

if [ ${#DER_CERTS[@]} -eq 0 ]; then
    echo "[!] No .der certificate files found in the current directory."
    echo "    Export your Burp certificate in DER format and place it here."
    exit 1
elif [ ${#DER_CERTS[@]} -eq 1 ]; then
    CERT_FILE="${DER_CERTS[0]}"
    echo "[+] Found certificate: $CERT_FILE"
else
    echo "[*] Multiple .der certificate files found:"
    for i in "${!DER_CERTS[@]}"; do
        echo "  [$i] ${DER_CERTS[$i]}"
    done
    echo -n "Select the certificate file to use [0-${#DER_CERTS[@]}]: "
    read CHOICE

    if ! [[ "$CHOICE" =~ ^[0-9]+$ ]] || [ "$CHOICE" -ge "${#DER_CERTS[@]}" ]; then
        echo "[!] Invalid selection."
        exit 1
    fi

    CERT_FILE="${DER_CERTS[$CHOICE]}"
    echo "[+] Selected certificate: $CERT_FILE"
fi

# -------------------------
# STEP 3: Check for running emulator or offer to start one
# -------------------------
EMULATORS=($(adb devices | grep -w emulator | awk '{print $1}'))

if [ ${#EMULATORS[@]} -eq 0 ]; then
    echo "[*] No running emulator found."
    echo "[*] Checking available AVDs..."
    AVD_LIST=($(emulator -list-avds))

    if [ ${#AVD_LIST[@]} -eq 0 ]; then
        echo "[!] No AVDs found. Please create one using AVD Manager or 'avdmanager'."
        exit 1
    fi

    echo "[*] Available AVDs:"
    for i in "${!AVD_LIST[@]}"; do
        echo "  [$i] ${AVD_LIST[$i]}"
    done

    echo -n "Select AVD to launch: "
    read CHOICE

    if ! [[ "$CHOICE" =~ ^[0-9]+$ ]] || [ "$CHOICE" -ge "${#AVD_LIST[@]}" ]; then
        echo "[!] Invalid selection."
        exit 1
    fi

    SELECTED_AVD="${AVD_LIST[$CHOICE]}"
    echo "[+] Launching AVD: $SELECTED_AVD"
    emulator -avd "$SELECTED_AVD" -writable-system &

    echo "[*] Waiting for emulator to boot..."
    adb wait-for-device
    sleep 30

    EMULATOR_SERIAL=$(adb devices | grep emulator | awk '{print $1}' | head -n1)
else
    if [ ${#EMULATORS[@]} -eq 1 ]; then
        EMULATOR_SERIAL="${EMULATORS[0]}"
        echo "[+] Using running emulator: $EMULATOR_SERIAL"
    else
        echo "[*] Multiple running emulators detected:"
        for i in "${!EMULATORS[@]}"; do
            echo "  [$i] ${EMULATORS[$i]}"
        done
        echo -n "Select emulator [0-${#EMULATORS[@]}]: "
        read CHOICE

        if ! [[ "$CHOICE" =~ ^[0-9]+$ ]] || [ "$CHOICE" -ge "${#EMULATORS[@]}" ]; then
            echo "[!] Invalid selection."
            exit 1
        fi

        EMULATOR_SERIAL="${EMULATORS[$CHOICE]}"
        echo "[+] Selected emulator: $EMULATOR_SERIAL"
    fi
fi

# -------------------------
# STEP 4: Convert certificate
# -------------------------
echo "[*] Converting DER to PEM..."
openssl x509 -inform DER -in "$CERT_FILE" -out burpcert.pem

echo "[*] Getting subject_hash_old..."
CERT_HASH=$(openssl x509 -inform PEM -subject_hash_old -in burpcert.pem | head -1)
CERT_DEST="$CERT_HASH.0"

echo "[*] Renaming PEM to $CERT_DEST"
cp burpcert.pem "$CERT_DEST"

# -------------------------
# STEP 5: Push cert to emulator
# -------------------------
echo "[*] Pushing certificate to /sdcard/..."
adb -s "$EMULATOR_SERIAL" push "$CERT_DEST" /sdcard/

echo "[*] Restarting adb as root..."
adb -s "$EMULATOR_SERIAL" root
sleep 2

echo "[*] Remounting /system..."
adb -s "$EMULATOR_SERIAL" remount
sleep 2

# -------------------------
# STEP 6: Move and chmod cert
# -------------------------
echo "[*] Installing cert inside emulator..."
adb -s "$EMULATOR_SERIAL" shell <<EOF
mv /sdcard/$CERT_DEST /system/etc/security/cacerts/
chmod 644 /system/etc/security/cacerts/$CERT_DEST
EOF

echo "[✔] Certificate $CERT_DEST installed successfully."
echo "🔁 Restart your emulator to apply the changes."

