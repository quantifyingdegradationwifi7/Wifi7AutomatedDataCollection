#!/bin/bash

# Prevent concurrent executions using file descriptor 9 and flock
exec 9> "/tmp/wifi7_setup.lock"
if ! flock -n 9; then
    echo "[$(date +'%H:%M:%S')] ERROR: Setup is already running in another window. Quitting."
    exit 1
fi

# Define a logging function for clear, timestamped output
log() {
    echo -e "\n[$(date +'%H:%M:%S')] >>> $1"
}

# Define an error function that exits immediately
fail() {
    echo -e "\n[$(date +'%H:%M:%S')] !!! ERROR: $1"
    echo "Exiting script to prevent further issues."
    exit 1
}

clear
echo "============================================="
echo "       WIFI 7 TESTBED SETUP SCRIPT           "
echo "============================================="
echo "Press 'Enter' to begin the setup process..."
read -r

echo -e "\nWaiting for two 802.11be USB Wi-Fi adapters to be plugged in..."
while true; do
    # Check lsusb for instances of '802.11be'
    ADAPTER_COUNT=$(lsusb | grep -i "802.11be" | wc -l)
    if [ "$ADAPTER_COUNT" -ge 2 ]; then
        echo "[$(date +'%H:%M:%S')] Two 802.11be adapters detected! Proceeding..."
        break
    fi
    sleep 1
done

log "Starting WiFi 7 testbed setup with strict error checking."

# Request and maintain sudo privileges for the duration of the script
log "Requesting administrative privileges."
sudo -v || fail "Sudo is required to continue."
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

# Define exact absolute paths
DOWNLOAD_DIR="$HOME/Downloads"
WPA_TAR="$DOWNLOAD_DIR/wpa_supplicant-2.11.tar.gz"
WPA_SRC_DIR="$DOWNLOAD_DIR/wpa_supplicant-2.11/wpa_supplicant"
RTW89_DIR="$DOWNLOAD_DIR/rtw89"

# Ensure the Downloads folder exists
if [ ! -d "$DOWNLOAD_DIR" ]; then
    log "Downloads folder not found. Creating $DOWNLOAD_DIR..."
    mkdir -p "$DOWNLOAD_DIR" || fail "Could not create $DOWNLOAD_DIR."
fi

log "Updating apt package repositories."
sudo apt-get update || fail "apt-get update failed. Check your internet connection."

log "Installing iPerf3 and Wireshark."
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y iperf3 wireshark tshark || fail "Failed to install iPerf3/Wireshark."

log "Installing dependencies for MLO support."
sudo apt-get install -y build-essential pkg-config libnl-3-dev libnl-route-3-dev \
    libnl-genl-3-dev libdbus-1-dev libssl-dev libreadline-dev libpcsclite-dev git || fail "Failed to install MLO dependencies."

# ==========================================
# WPA_SUPPLICANT SETUP
# ==========================================
log "Navigating to $DOWNLOAD_DIR."
cd "$DOWNLOAD_DIR" || fail "Could not cd to $DOWNLOAD_DIR."

if [ -d "$WPA_SRC_DIR" ]; then
    log "wpa_supplicant source directory already exists. Skipping download and extraction."
else
    if [ ! -f "$WPA_TAR" ]; then
        log "Downloading wpa_supplicant 2.11."
        wget --show-progress -O "$WPA_TAR" https://w1.fi/releases/wpa_supplicant-2.11.tar.gz || fail "Failed to download wpa_supplicant."
    else
        log "wpa_supplicant tarball already exists. Skipping download."
    fi

    log "Extracting wpa_supplicant."
    tar xf "$WPA_TAR" || fail "Failed to extract $WPA_TAR."

    if [ ! -d "$WPA_SRC_DIR" ]; then
        fail "Expected extracted directory not found at $WPA_SRC_DIR."
    fi
fi

cd "$WPA_SRC_DIR" || fail "Could not cd to $WPA_SRC_DIR."

log "Applying MLO configuration settings to wpa_supplicant."
[ -f "defconfig" ] || fail "defconfig not found in $WPA_SRC_DIR."
cp defconfig .config || fail "Failed to copy defconfig to .config."

{
    echo "CONFIG_IEEE80211AX=y"
    echo "CONFIG_IEEE80211BE=y"
    echo "CONFIG_DRIVER_NL80211=y"
    echo "CONFIG_CTRL_IFACE=y"
    echo "CONFIG_DBUS=y"
    echo "CONFIG_CTRL_IFACE_DBUS_NEW=y"
} >> .config || fail "Failed to append configurations to .config."

log "Compiling wpa_supplicant (this might take a few minutes)..."
make -j$(nproc) || fail "Compilation of wpa_supplicant failed."

log "Backing up old wpa_supplicant/wpa_cli and installing the compiled MLO version."
[ -f "wpa_supplicant" ] || fail "Compiled wpa_supplicant binary not found!"
[ -f "wpa_cli" ] || fail "Compiled wpa_cli binary not found!"

# Replace system binaries
sudo mv /usr/sbin/wpa_supplicant /usr/sbin/wpa_supplicant.bak 2>/dev/null || true
sudo cp wpa_supplicant /usr/sbin/wpa_supplicant || fail "Failed to copy wpa_supplicant to /usr/sbin/."

sudo mv /usr/bin/wpa_cli /usr/bin/wpa_cli.bak 2>/dev/null || true
sudo cp wpa_cli /usr/bin/wpa_cli || fail "Failed to copy wpa_cli to /usr/bin/."
sudo cp wpa_cli /usr/local/bin/ 2>/dev/null || true

# Refresh shell execution cache
hash -r 2>/dev/null || true

log "Restarting wpa_supplicant background service."
sudo systemctl restart wpa_supplicant || fail "Failed to restart wpa_supplicant service."

log "Verifying MLO is installed properly..."
WPA_VER=$(/usr/sbin/wpa_supplicant -v 2>&1)
if ! echo "$WPA_VER" | grep -q "2.11"; then
    fail "wpa_supplicant version mismatch (got: $WPA_VER)."
fi

CLI_VER=$(/usr/bin/wpa_cli -v 2>&1)
if ! echo "$CLI_VER" | grep -q "2.11"; then
    fail "wpa_cli version mismatch (got: $CLI_VER)."
fi

if ! grep -a -q "mlo_status" /usr/bin/wpa_cli; then
    fail "mlo_status symbol not found in wpa_cli binary. MLO compilation failed."
fi
log "MLO installation verified successfully!"

# ==========================================
# RTW89 DRIVER SETUP
# ==========================================
log "Installing Wi-Fi 7 driver dependencies."
sudo apt-get install -y build-essential git linux-headers-$(uname -r) bc dkms mokutil || fail "Failed to install rtw89 dependencies."

cd "$DOWNLOAD_DIR" || fail "Could not cd to $DOWNLOAD_DIR."

if [ -d "$RTW89_DIR" ]; then
    log "rtw89 repository already exists. Skipping git clone."
else
    log "Cloning the rtw89 driver repository..."
    git clone https://github.com/morrownr/rtw89.git "$RTW89_DIR" || fail "Failed to clone rtw89 repository."

    if [ ! -d "$RTW89_DIR" ]; then
        fail "The directory $RTW89_DIR does not exist after git clone."
    fi
fi

cd "$RTW89_DIR" || fail "Could not cd into $RTW89_DIR."

if [ ! -f "Makefile" ]; then
    fail "Makefile not found in $RTW89_DIR. The repository may be corrupted or changed."
fi

# Disconnect the built-in wlan0 to prevent conflicts during install
log "Disconnecting wlan0 from the internet prior to driver install."
sudo ip link set wlan0 down 2>/dev/null || true

if ! sudo dkms status | grep -q "rtw89"; then
    log "Installing rtw89 driver via dkms..."
    sudo dkms install . || fail "DKMS install failed for rtw89."
else
    log "rtw89 DKMS module is already installed. Skipping dkms install."
fi

log "Installing rtw89 driver firmware..."
sudo make install_fw || fail "Firmware installation (make install_fw) failed."

log "Setting Wi-Fi regulatory domain to NZ."
sudo iw reg set NZ || fail "Failed to set regulatory domain to NZ."

log "Loading the rtw89 driver module (modprobe)..."
sudo modprobe rtw89_8922au_git || fail "Failed to load the rtw89 kernel module. Ensure Secure Boot is disabled in your BIOS."

log "Bringing wlan1 interface up and unblocking hardware restrictions."
sudo rfkill unblock all || fail "Failed to unblock rfkill."
sudo ip link set wlan1 up || log "WARNING: wlan1 interface not found. Ensure the adapter is plugged in."

# ==========================================
# NETWORK & MONITOR MODE SETUP
# ==========================================
log "Configuring test networks (ASUS_B0, ASUS_B0_5G, ASUS_B0_6G) using WPA3."
WIFI_PASS='?7am4ynn2e'

for ssid in ASUS_B0 ASUS_B0_5G ASUS_B0_6G; do
    log "Creating saved network profile for $ssid."
    sudo nmcli connection delete "$ssid" >/dev/null 2>&1 || true
    # SAE ensures WPA3 Personal is used; wifi-sec.psk-flags 0 prevents key prompts
    sudo nmcli connection add \
        type wifi \
        ifname wlan1 \
        con-name "$ssid" \
        ssid "$ssid" \
        autoconnect no \
        wifi-sec.key-mgmt sae \
        wifi-sec.psk "$WIFI_PASS" \
        wifi-sec.psk-flags 0 \
        ipv4.method manual \
        ipv4.addresses 192.168.50.68/24 \
        ipv4.gateway 192.168.50.1 >/dev/null 2>&1 || fail "Failed to create nmcli profile for $ssid."
    
    # Save secrets persistently and disable MAC Randomization to prevent breaking WPA3/MLO reconnects
    sudo nmcli connection modify "$ssid" wifi-sec.psk-flags 0 >/dev/null 2>&1 || true
    sudo nmcli connection modify "$ssid" wifi.cloned-mac-address permanent >/dev/null 2>&1 || true
done

log "Clearing preferred channel settings for test networks (no preset channel)..."
for ssid in ASUS_B0 ASUS_B0_5G ASUS_B0_6G; do
    sudo nmcli connection modify "$ssid" 802-11-wireless.band "" >/dev/null 2>&1 || true
    sudo nmcli connection modify "$ssid" 802-11-wireless.channel "" >/dev/null 2>&1 || true
done

log "Checking for wlan2 and preparing monitor mode..."
if ip link show wlan2 > /dev/null 2>&1; then
    sudo ip link set wlan2 down || true
    sudo iw dev wlan2 set type monitor || fail "Failed to set wlan2 to monitor mode."
    sudo nmcli device set wlan2 managed no || true
    log "SUCCESS: wlan2 monitor mode configured (interface set to idle/down until wlan1 connects)."
else
    log "WARNING: wlan2 interface not found. Ensure the second adapter is plugged in."
fi

# ==========================================
# DIAGNOSTICS SCRIPT GENERATION & LAUNCH
# ==========================================
log "Generating diagnostics loop script..."
DIAG_FILE="$DOWNLOAD_DIR/diagnostics.sh"

cat << 'EOF' > "$DIAG_FILE"
#!/bin/bash
while true; do
    clear
    echo "=========================================="
    echo "          WIFI 7 DIAGNOSTICS LOG          "
    echo "=========================================="
    echo "Time: $(date +'%H:%M:%S')"
    echo ""
    
    WLAN1_FREQ=""
    WLAN1_WIDTH=""
    WLAN1_CENTER=""
    
    # --- WLAN1 PROCESSING ---
    iface="wlan1"
    if ip link show $iface >/dev/null 2>&1; then
        MODE=$(iw dev $iface info 2>/dev/null | grep type | awk '{print $2}')
        echo "[$iface] Mode: $MODE"
        
        if [ "$MODE" = "managed" ]; then
            INFO=$(iw dev $iface info 2>/dev/null)
            LINK=$(iw dev $iface link 2>/dev/null)
            
            SSID=$(echo "$LINK" | grep -i "SSID:" | cut -d ' ' -f 2-)
            if [ -n "$SSID" ]; then
                echo "  -> Connected Wi-Fi : $SSID"
                CHAN_LINE=$(echo "$INFO" | grep "channel ")
                
                CHAN=$(echo "$CHAN_LINE" | awk '{print $2}')
                FREQ=$(echo "$CHAN_LINE" | grep -oE '\([0-9]+ MHz\)' | head -n1 | tr -d '() MHz')
                WIDTH=$(echo "$CHAN_LINE" | grep -oE 'width: [0-9]+' | awk '{print $2}')
                CENTER=$(echo "$CHAN_LINE" | grep -oE 'center1: [0-9]+' | awk '{print $2}')
                
                [ -z "$CENTER" ] && CENTER="N/A"
                [ -z "$WIDTH" ] && WIDTH="N/A"
                
                echo "  -> Channel         : $CHAN"
                echo "  -> Frequency       : ${FREQ} MHz"
                echo "  -> Width           : ${WIDTH} MHz"
                echo "  -> Center Channel  : ${CENTER} MHz"
                
                WLAN1_FREQ="$FREQ"
                WLAN1_WIDTH="$WIDTH"
                WLAN1_CENTER="$CENTER"
                
                # Check MLO mode
                MLO_OUT=$(sudo wpa_cli -i $iface mlo_status 2>/dev/null)
                if [ -z "$MLO_OUT" ] || echo "$MLO_OUT" | grep -qi "FAIL"; then
                    echo "  -> MLO Status      : Not in MLO mode"
                else
                    echo "  -> MLO Status      : Active"
                fi
            else
                echo "  -> Status          : Disconnected"
            fi
        fi
    else
        echo "[$iface] Status: NOT FOUND"
    fi
    echo "------------------------------------------"
    
    # --- WLAN2 PROCESSING ---
    iface="wlan2"
    if ip link show $iface >/dev/null 2>&1; then
        # Check if wlan1 is connected with valid channel parameters
        if [ -n "$WLAN1_FREQ" ]; then
            
            # wlan1 IS connected: Ensure wlan2 is set to monitor mode and interface is UP
            MODE=$(iw dev $iface info 2>/dev/null | grep type | awk '{print $2}')
            LINK_STATE=$(ip link show $iface 2>/dev/null | grep -q "UP" && echo "UP" || echo "DOWN")
            
            if [ "$MODE" != "monitor" ] || [ "$LINK_STATE" = "DOWN" ]; then
                sudo ip link set $iface down 2>/dev/null
                sudo iw dev $iface set type monitor 2>/dev/null
                sudo nmcli device set $iface managed no 2>/dev/null
                sudo ip link set $iface up 2>/dev/null
            fi
            
            # Sync wlan2 monitor frequency to match wlan1
            # Handles iw syntax: 20MHz uses control freq, >20MHz includes width and center freq
            if [ -n "$WLAN1_WIDTH" ] && [ "$WLAN1_WIDTH" != "20" ] && [ "$WLAN1_WIDTH" != "N/A" ] && [ -n "$WLAN1_CENTER" ] && [ "$WLAN1_CENTER" != "N/A" ] && [ "$WLAN1_CENTER" != "$WLAN1_FREQ" ]; then
                sudo iw dev $iface set freq $WLAN1_FREQ $WLAN1_WIDTH $WLAN1_CENTER 2>/dev/null
            else
                sudo iw dev $iface set freq $WLAN1_FREQ 2>/dev/null
            fi

            MODE=$(iw dev $iface info 2>/dev/null | grep type | awk '{print $2}')
            echo "[$iface] Mode: ${MODE:-monitor}"

            INFO=$(iw dev $iface info 2>/dev/null)
            CHAN_LINE=$(echo "$INFO" | grep "channel ")
            
            if [ -n "$CHAN_LINE" ]; then
                CHAN=$(echo "$CHAN_LINE" | awk '{print $2}')
                FREQ=$(echo "$CHAN_LINE" | grep -oE '\([0-9]+ MHz\)' | head -n1 | tr -d '() MHz')
                WIDTH=$(echo "$CHAN_LINE" | grep -oE 'width: [0-9]+' | awk '{print $2}')
                CENTER=$(echo "$CHAN_LINE" | grep -oE 'center1: [0-9]+' | awk '{print $2}')
                
                [ -z "$CENTER" ] && CENTER="N/A"
                [ -z "$WIDTH" ] && WIDTH="N/A"
                
                echo "  -> Status          : Monitoring"
                echo "  -> Channel         : $CHAN"
                echo "  -> Frequency       : ${FREQ} MHz"
                echo "  -> Width           : ${WIDTH} MHz"
                echo "  -> Center Channel  : ${CENTER} MHz"
            else
                echo "  -> Status          : Monitoring (Freq unknown)"
            fi
        else
            # wlan1 IS Disconnected: Turn off monitoring by bringing wlan2 link DOWN
            sudo ip link set $iface down 2>/dev/null
            
            echo "[$iface] Mode: monitor"
            echo "  -> Status          : Standby (Not monitoring - wlan1 disconnected)"
        fi
    else
        echo "[$iface] Status: NOT FOUND"
    fi
    echo "------------------------------------------"
    sleep 1
done
EOF

# Make the diagnostics script executable
chmod +x "$DIAG_FILE"

log "Launching diagnostics.sh in a new detached terminal window..."
# Launch in background and decouple from this process session using nohup & disown
nohup x-terminal-emulator -e bash "$DIAG_FILE" >/dev/null 2>&1 &
disown

log "Setup script finished successfully!"

# ==========================================
# PAUSE / END
# ==========================================
echo ""
echo "==================================================="
echo "Setup is complete. Diagnostics are running in a new window."
echo "Press Ctrl+C or close this window safely at any time."
echo "==================================================="

# Keep the original terminal window open until closed by user
while true; do 
    sleep 1 
done
