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
