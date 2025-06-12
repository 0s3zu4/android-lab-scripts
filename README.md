# android-lab-scripts
Scripts to automate Android emulator setup for security testing (Burp cert install, Magisk root, AVD fixes)

- rootAVD-certify.sh ---> works on andriod 10 and above (with playstore image)
- Android_Cert_Installer.sh--> works on andriod 9 and below (No_PlayStore Image)
- fix_android_avd.sh--> fixes avd issues eg `emulator -list-avds` is not working

# rootAVD-certify.sh (v1.1.50)

**Author**: Osezua
**Purpose**: Automatically root an Android Emulator using `Magisk` and install a trusted CA certificate (such as Burp Suite’s) into the system trust store.

---

## 🔧 Features

* Detects and selects AVDs dynamically
* Automatically extracts API level and CPU architecture
* Patches the emulator’s ramdisk using `Magisk`
* Prompts user with checklists to complete the rooting steps
* Pushes and installs a user-supplied certificate into the system trust store

---

## 🚀 Usage

### 1. Clone Repo
```bash
git clone https://github.com/0s3zu4/android-lab-scripts.git
```

### 2. Make the script executable

```bash
chmod +x rootAVD-certify.sh
```

### 2. Run the script

```bash
./rootAVD-certify.sh
```

You will be prompted to:

* Select your emulator (if none is running)
* Follow instructions to patch Magisk via `rootAVD.sh`
* Install a certificate file into the emulator

---

## 📝 Requirements

* AVD with writable system image (`-writable-system`)
* `adb`, `openssl`, and `emulator` CLI tools installed
* Android emulator image with API level 24+ (tested with API 28–32)
* a proxy certificate in .crt format in the same directory (eg. burpcert.crt)

---

# Android_Cert_Installer.sh
**Author**: Osezua
**Purpose**: Automatically installs Certificates in `DER` formats in android studio emulators running `android open source`


## 🚀 Usage

### 1. Clone Repo
```bash
git clone https://github.com/0s3zu4/android-lab-scripts.git
```

### 2. Make the script executable

```bash
chmod +x Android_Cert_Installer.sh
```

### 2. Run the script

```bash
./Android_Cert_Installer.sh
```

You will be prompted to:

* Select your emulator (if none is running)
* Install a certificate file into the emulator

---

## 📝 Requirements

* AVD with writable system image (`-writable-system`)
* `adb`, `openssl`, and `emulator` CLI tools installed
* Android emulator image with API level 24+ (tested with API 28)
* a proxy certificate in .der format in the same directory (eg. burpcert.der)

---


## 📌 Notes

* Magisk patching is a manual step — wait for full boot and complete all prompts.
* Certificate must be in **DER format**.
* You’ll be prompted to select the `.der` file if multiple are present.
* This modifies `/system/etc/security/cacerts` inside the emulator.

---

## 🛡️ Legal Notice

This script is for educational and testing purposes only. Do not use it to modify production devices or violate any terms of use. Use responsibly.
