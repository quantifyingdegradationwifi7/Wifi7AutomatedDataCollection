# Testing Procedure

Our methodology tests 17 environmental scenarios (Line-of-Sight vs. Obstructed/Interfered) across 4 states: 2.4 GHz, 5 GHz, 6 GHz, and MLO. To ensure accuracy, we utilize a dual-software approach: `iPerf3` logs application-level throughput at 0.1-second intervals, while `Wireshark` concurrently captures raw frames in monitor mode to calculate Received Signal Strength (RSSI) and ambient noise.

## Step 1: Initialize the Diagnostics and Wireshark
1. Ensure your `diagnostics.sh` script is running. This script reads the channel, frequency, and width of `wlan1` (the transmitting adapter) and automatically forces `wlan2` (the monitoring adapter) to tune to the exact same frequency space.
2. Open **Wireshark** as `sudo` and begin capturing on `wlan2`.
3. In Wireshark, adjust your view for data extraction:
   * Go to `Edit -> Preferences -> Columns -> Add (+)`. Set the field to `wlan_radio.signal_dbm`.
   * Go to `View -> Time Display Format` and select **Time of Day**.

## Step 2: Start the iPerf3 Server
On the laptop connected via Ethernet (IP: `192.168.50.5`), start the iPerf3 server:
```bash
iperf3 -s
```

## Step 3: Run the Router Controller
Switching bands manually via a web GUI is slow and error-prone. We provide `router_controller_poc.sh` to SSH into the router and directly modify the `nvram` to toggle virtual interfaces (VIFs) and force the router into specific bands.

On the client laptop, run:
```bash
./router_controller_poc.sh
```
*Note: You will be prompted for the router's SSH password once. The script will keep an SSH multiplexing socket open and prompt you to press Enter whenever you are ready to transition to the next band in the test cycle.*

## Step 4: Execute the Tests
With the router set to the desired band, use `run_iperf_tests.sh` to begin traffic generation.

```bash
./run_iperf_tests.sh
```
1. The script will ask for the duration of the **LOS** (Line-of-Sight) baseline tests and the **PROPER** (Environmental/Obstructed) tests in seconds.
2. It will loop through the bands (`2.4`, `5`, `6`, `mlo`).
3. For each band, it will execute 3 iterations (`a`, `b`, `c`) to meet the quality assurance criterion of ≤10% variation between trials.
4. Output logs are automatically saved to the Home (`~/`) directory (e.g., `los_6_a_1.log`).

Once data collection is complete for a scenario, you can stop the Wireshark capture and save it as a `.PCAPNG` file. Combine the `.log` files, the `.pcapng` file, and a `.csv` of the diagnostics to proceed to Stage 2 (Data Processing).