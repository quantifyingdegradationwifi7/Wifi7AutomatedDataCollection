#!/bin/bash

ROUTER="admin@192.168.50.1"
SOCKET="/tmp/asus_router_mux"

# ---------------------------------------------------------
# REMOTELY EXECUTED STATE MACHINE
# This script is pushed to the router and handles the cleanup
# of old virtual interfaces (VIFs) and the creation of new ones.
# ---------------------------------------------------------
ROUTER_SCRIPT='
# Helper function to safely remove an interface from a list (POSIX native)
rm_iface() {
    local var=$1; local iface=$2
    nvram set "$var"="$(echo $(nvram get "$var" | sed "s/$iface//g"))"
}

# Helper function to safely add an interface to a list (POSIX native)
add_iface() {
    local var=$1; local iface=$2
    nvram set "$var"="$(echo $(nvram get "$var" | sed "s/$iface//g") $iface)"
}

set_band() {
    local mode=$1 # "2.4", "5", "6", or "MLO"

    # --- RESET ALL VIRTUAL INTERFACES (VIFs) TO CLEAN SLATE ---
    # Disable 2.4GHz VIF
    nvram set wl0.1_bss_enabled=0
    nvram unset wl0.1_bss_mlo_mode; nvram unset wl0.1_eht_bssehtmode; nvram unset wl0.1_nband
    rm_iface "wl0_vifs" "wl0.1"; rm_iface "br0_ifnames" "wl0.1"; rm_iface "lan_ifnames" "wl0.1"

    # Disable 5GHz VIF
    nvram set wl1.1_bss_enabled=0
    nvram unset wl1.1_bss_mlo_mode; nvram unset wl1.1_eht_bssehtmode; nvram unset wl1.1_nband
    rm_iface "wl1_vifs" "wl1.1"; rm_iface "br0_ifnames" "wl1.1"; rm_iface "lan_ifnames" "wl1.1"

    # Disable 6GHz VIF
    nvram set wl2.1_bss_enabled=0
    nvram unset wl2.1_bss_mlo_mode; nvram unset wl2.1_eht_bssehtmode; nvram unset wl2.1_nband
    rm_iface "wl2_vifs" "wl2.1"; rm_iface "br0_ifnames" "wl2.1"; rm_iface "lan_ifnames" "wl2.1"


    # --- APPLY TARGET STATE ---
    if [ "$mode" = "2.4" ]; then
        nvram set apm2_mlo="0"
        nvram set apm2_dut_list="<*>1>"

        nvram set wl0.1_bss_enabled=1; nvram set wl0.1_bss_mlo_mode=1; nvram set wl0.1_eht_bssehtmode=1; nvram set wl0.1_nband=2
        add_iface "wl0_vifs" "wl0.1"; add_iface "br0_ifnames" "wl0.1"; add_iface "lan_ifnames" "wl0.1"

        nvram set ap_wifi_rl="<0>wl0.1>2"

    elif [ "$mode" = "5" ]; then
        nvram set apm2_mlo="0"
        nvram set apm2_dut_list="<*>6>"

        nvram set wl1.1_bss_enabled=1; nvram set wl1.1_bss_mlo_mode=1; nvram set wl1.1_eht_bssehtmode=1; nvram set wl1.1_nband=1
        add_iface "wl1_vifs" "wl1.1"; add_iface "br0_ifnames" "wl1.1"; add_iface "lan_ifnames" "wl1.1"

        nvram set ap_wifi_rl="<0>wl1.1>2"

    elif [ "$mode" = "6" ]; then
        nvram set apm2_mlo="0"
        nvram set apm2_dut_list="<*>80>"

        nvram set wl2.1_bss_enabled=1; nvram set wl2.1_bss_mlo_mode=1; nvram set wl2.1_eht_bssehtmode=1; nvram set wl2.1_nband=4
        add_iface "wl2_vifs" "wl2.1"; add_iface "br0_ifnames" "wl2.1"; add_iface "lan_ifnames" "wl2.1"

        nvram set ap_wifi_rl="<0>wl2.1>2"

    elif [ "$mode" = "MLO" ]; then
        nvram set apm2_mlo="2"
        nvram set apm2_dut_list="<*>59>"

        # 2.4G VIF
        nvram set wl0.1_bss_enabled=1; nvram set wl0.1_bss_mlo_mode=1; nvram set wl0.1_eht_bssehtmode=1; nvram set wl0.1_nband=2
        add_iface "wl0_vifs" "wl0.1"; add_iface "br0_ifnames" "wl0.1"; add_iface "lan_ifnames" "wl0.1"

        # 5G VIF
        nvram set wl1.1_bss_enabled=1; nvram set wl1.1_bss_mlo_mode=1; nvram set wl1.1_eht_bssehtmode=1; nvram set wl1.1_nband=1
        add_iface "wl1_vifs" "wl1.1"; add_iface "br0_ifnames" "wl1.1"; add_iface "lan_ifnames" "wl1.1"

        # 6G VIF
        nvram set wl2.1_bss_enabled=1; nvram set wl2.1_bss_mlo_mode=1; nvram set wl2.1_eht_bssehtmode=1; nvram set wl2.1_nband=4
        add_iface "wl2_vifs" "wl2.1"; add_iface "br0_ifnames" "wl2.1"; add_iface "lan_ifnames" "wl2.1"

        nvram set ap_wifi_rl="<0>wl0.1>2<1>wl1.1>2<2>wl2.1>2"
    fi

    # Explicitly ensure physical radios remain ON
    nvram set wl0_radio=1
    nvram set wl1_radio=1
    nvram set wl2_radio=1

    nvram commit
    service "restart_wireless;restart_sdn 2;"
}
'

# Verification payload (Updated to show status of the active Virtual Interfaces)
VERIFY_CMD='echo "--- APPLIED SDN PROFILE STATE ---"; printf "MLO Mode (apm2_mlo)       : %s\n" "$(nvram get apm2_mlo)"; printf "Band Mask (apm2_dut_list)  : %s\n" "$(nvram get apm2_dut_list)"; printf "2.4GHz VIF Enabled (wl0.1) : %s\n" "$(nvram get wl0.1_bss_enabled)"; printf "5GHz VIF Enabled   (wl1.1) : %s\n" "$(nvram get wl1.1_bss_enabled)"; printf "6GHz VIF Enabled   (wl2.1) : %s\n" "$(nvram get wl2.1_bss_enabled)"; echo "---------------------------------"'

echo "=========================================="
echo " ASUS Wi-Fi Band Switching Test Script"
echo "=========================================="
echo "Connecting to $ROUTER..."
echo "You will be prompted for your SSH password ONCE."

# Open background SSH multiplexing socket
ssh -M -S "$SOCKET" -fnNT "$ROUTER"

if [ $? -ne 0 ]; then
    echo "Failed to authenticate or connect. Exiting."
    exit 1
fi

# Trap to close background socket on exit or interruption
trap 'ssh -S "$SOCKET" -O exit "$ROUTER" 2>/dev/null' EXIT INT TERM

echo "Connection established!"
echo ""

# ---------------------------------------------------------
# TIME SYNCHRONIZATION BLOCK
# ---------------------------------------------------------
echo "Syncing router time with local computer..."

LOCAL_FORMATTED_TIME=$(date "+%Y.%m.%d-%H:%M:%S")

echo "Setting router date to: $LOCAL_FORMATTED_TIME"
ssh -S "$SOCKET" "$ROUTER" "date $LOCAL_FORMATTED_TIME"

ROUTER_EPOCH=$(ssh -S "$SOCKET" "$ROUTER" "date +%s")
HOST_EPOCH=$(date +%s)

DIFF=$(( HOST_EPOCH - ROUTER_EPOCH ))
DIFF=${DIFF#-} # Absolute value

if [ "$DIFF" -le 1 ]; then
    echo "Time successfully synced! (Difference: ${DIFF} seconds)"
else
    echo "Warning: Time sync mismatch. The difference is ${DIFF} seconds."
fi
echo ""

# ---------------------------------------------------------
# STEP EXECUTION FUNCTION
# ---------------------------------------------------------
run_step() {
    local prompt_msg="$1"
    local target_band="$2"

    # Pause and wait for Enter
    read -p "$prompt_msg"

    echo "Executing changes..."
    # Inject our functions and call set_band with target band
    ssh -S "$SOCKET" "$ROUTER" "$ROUTER_SCRIPT set_band \"$target_band\""

    # Sleep 3 seconds to let cfg_server update profile state
    sleep 3

    echo "Verifying changes on the router..."
    ssh -S "$SOCKET" "$ROUTER" "$VERIFY_CMD"

    echo "Done. (Note: It may take ~10-15 seconds for the router's radios to physically reboot)"
    echo ""
}

# --- CYCLE 1 ---
echo "--- STARTING CYCLE 1 ---"
run_step "Step 2: Press enter to switch to 2.4GHz ONLY..." "2.4"
run_step "Step 3: Press enter to switch to 5GHz ONLY..." "5"
run_step "Step 4: Press enter to switch to 6GHz ONLY..." "6"
run_step "Step 5: Press enter to switch to MLO (All Bands)..." "MLO"

# --- CYCLE 2 ---
echo "--- STARTING CYCLE 2 ---"
run_step "Step 6a: Press enter to switch to 2.4GHz ONLY..." "2.4"
run_step "Step 6b: Press enter to switch to 5GHz ONLY..." "5"
run_step "Step 6c: Press enter to switch to 6GHz ONLY..." "6"
run_step "Step 6d: Press enter to switch to MLO (All Bands)..." "MLO"

# --- FINISH ---
echo "--- FINISHING UP ---"
run_step "Step 7: Press enter to switch back to 2.4GHz and end the test..." "2.4"

echo "Test script finished! SSH connection closing."
