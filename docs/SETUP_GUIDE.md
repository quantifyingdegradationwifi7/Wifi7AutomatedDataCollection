# Testbed Setup Guide

This document outlines how to prepare the hardware and operating system to run the Wi-Fi 7 experiments. Because early Wi-Fi 7 hardware lacks mature Linux driver support—specifically regarding Multi-Link Operation (MLO) and the 6 GHz band—careful setup is required.

## 1. Preparing the Router
Ensure only the power cable is connected to the router. Start by factory resetting the router if it has been previously used.

1. Connect the **recording laptop** (the one running the iPerf3 server and Wireshark) to the router via Ethernet.
2. Navigate to the router's admin panel (typically `192.168.50.1`).
3. Set the operation mode to **Access Point (NOT Router)**.
4. **Separate the 2.4 GHz, 5 GHz, and 6 GHz channels** with distinct names (e.g., `ASUS_B0`, `ASUS_B0_5G`, `ASUS_B0_6G`). Do *not* enable an IoT channel.
5. Manually assign a static IP to the recording laptop's ethernet connection: `192.168.50.5`.
6. Configure the bands as follows (Hardware limitations may apply):
    *   **2.4GHz:** 40MHz, Channel 6 (or Below)
    *   **5GHz:** 160MHz (or 80MHz if limited), Channel 40, Auto
    *   **6GHz:** 160MHz, Channel 5, Auto

## 2. Preparing the Client Laptop (Kali Linux)
The client laptop will run the automated bash scripts to collect data. You will need **two** Wi-Fi 7 USB 3.0 adapters plugged in.

1. Connect the laptop to the internet via an alternative connection (e.g., built-in Wi-Fi or Ethernet) to download dependencies.
2. Plug in both Wi-Fi 7 USB adapters. Ensure they are using USB 3.0 (You can verify this by running `lsusb -t` and checking for `5000M` speeds).
3. Navigate to the `/scripts/` directory in this repository and run the setup script:
   ```bash
   chmod +x setup_client.sh
   ./setup_client.sh
   ```

### What `setup_client.sh` does automatically:
* Updates `apt` and installs `iperf3` and `wireshark`.
* Downloads and compiles `wpa_supplicant 2.11` from source with specific flags (`CONFIG_IEEE80211BE=y`, `CONFIG_CTRL_IFACE_DBUS_NEW=y`, etc.) required to enable MLO status reporting.
* Clones and compiles the `rtw89` driver via DKMS, sets the regulatory domain, and loads the kernel module.
* Disables the internal `wlan0` to prevent conflicts, bringing up `wlan1` (managed mode for traffic) and `wlan2` (monitor mode for Wireshark).
* Generates and launches `diagnostics.sh` in a detached terminal to monitor the real-time frequency and channel center of your connection.