#!/bin/bash

# 1) Ask how long the LOS tests should be in seconds
read -p "How long should the LOS tests be in seconds? " LOS_S

# 2) Ask how long the PROPER tests should be in seconds
read -p "How long should the PROPER tests be in seconds? " PROPER_S

# Define the bands and the test iterations (a, b, c)
BANDS=("2.4" "5" "6" "mlo")
LETTERS=("a" "b" "c")

# 7) Loop for Round 1 and Round 2
for ROUND in 1 2; do
    echo ""
    echo "=========================================="
    echo "          STARTING ROUND $ROUND           "
    echo "=========================================="
    
    # 3 & 6) Loop through 2.4, 5, 6, and MLO
    for BAND in "${BANDS[@]}"; do
        
        # Announce readiness
        echo ""
        if [ "$BAND" == "mlo" ]; then
            echo "--- Ready for MLO (Round $ROUND) ---"
        else
            echo "--- Ready for ${BAND}GHz (Round $ROUND) ---"
        fi
        
        # 4) Run LOS tests (a, b, c) ONLY in Round 1
        if [ "$ROUND" -eq 1 ]; then
            for LETTER in "${LETTERS[@]}"; do
                # Wait for user input to start
                read -p "Press [Enter] to start LOS test ${LETTER}_${ROUND} for ${BAND}... "
                
                LOG_FILE="$HOME/los_${BAND}_${LETTER}_${ROUND}.log"
                echo "Running: iperf3 -c 192.168.50.5 -t $LOS_S -i 0.1 --timestamps --logfile $LOG_FILE"
                
                iperf3 -c 192.168.50.5 -t "$LOS_S" -i 0.1 --timestamps --logfile "$LOG_FILE"
                echo "Done. Saved to ~/los_${BAND}_${LETTER}_${ROUND}.log"
            done
            echo ""
        fi
        
        # 5) Run PROPER tests (a, b, c) in BOTH rounds
        for LETTER in "${LETTERS[@]}"; do
            # Wait for user input to start
            read -p "Press [Enter] to start PROPER test ${LETTER}_${ROUND} for ${BAND}... "
            
            LOG_FILE="$HOME/proper_${BAND}_${LETTER}_${ROUND}.log"
            echo "Running: iperf3 -c 192.168.50.5 -t $PROPER_S -i 0.1 --timestamps --logfile $LOG_FILE"
            
            iperf3 -c 192.168.50.5 -t "$PROPER_S" -i 0.1 --timestamps --logfile "$LOG_FILE"
            echo "Done. Saved to ~/proper_${BAND}_${LETTER}_${ROUND}.log"
        done
        
    done
done

echo ""
echo "=========================================="
echo "          ALL TESTS COMPLETED             "
echo "=========================================="
echo "All logfiles have been saved to your home directory (~/)"
