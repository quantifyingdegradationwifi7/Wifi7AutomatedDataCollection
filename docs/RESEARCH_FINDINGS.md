# Research Findings & Environmental Impact

As part of this project, we executed 17 controlled indoor and near-indoor test scenarios. Our goal was to investigate how building materials, device distance, floor separation, and electromagnetic interference (EMI) degrade IEEE 802.11be network performance.

Here is a summary of our empirical findings which underscore the physical and hardware limitations currently facing Wi-Fi 7 deployments.

## 1. 6 GHz Bypasses Contention & EMI, but Requires New Penetration Budgets
In environments saturated with co-channel interference, high user density (e.g., Libraries, Cafes), or heavy EMI (near active microwave ovens or enterprise server racks), the 6 GHz band proved exceptionally robust. While legacy 2.4 GHz and 5 GHz bands collapsed, 6 GHz experienced virtually 0% degradation. 
**Takeaway:** Network engineers should prioritize direct Line-of-Sight (LOS) 6 GHz deployments in open-plan offices and communal spaces. However, because higher frequencies suffer greater material skin-depth absorption, penetration budgets for thick concrete corners and stairwells must be recalculated.

## 2. Split-Tier SSID Architectures Over Default MLO
Theoretically, Multi-Link Operation (MLO) aggregates multiple bands for seamless connectivity. However, our empirical data shows that early Wi-Fi 7 hardware relies on **Enhanced Multi-Link Single-Radio (EMLSR)** fallback mechanisms, which alternate between frequencies rather than transmitting concurrently.
During testing, MLO frequently made poor band-steering decisions. In obstructed scenarios, the fallback mechanism often latched onto the severely congested or attenuated 2.4 GHz spectrum instead of the pristine 6 GHz spectrum, causing catastrophic throughput drops (e.g., from 900+ Mbps down to < 1 Mbps). 
**Takeaway:** Until vendor firmware matures, network planners should adopt a split-tier SSID architecture, dedicating a 5 GHz + 6 GHz SSID for high-performance clients to physically prevent firmware from downshifting into congested legacy spectrum.

## 3. Mitigating Glass Scattering
Modern glass paneling introduces severe multipath scattering across higher frequency bands. In our testing, both 5 GHz and 6 GHz throughput degraded by ~40% due to specular reflection, angle-of-incidence diffraction, and destructive phase interference.
**Takeaway:** Access points should be installed directly inside glass-walled meeting spaces, utilizing a 2 to 3-meter setback from the glass to prevent high-frequency RF energy from immediately reflecting into the AP's own transceiver arrays.

## 4. Metal Elevators act as Faraday Cages
Testing in a solid metallic elevator cab showed that external signals are attenuated by nearly 100%, collapsing MLO throughput to an unstable state. 
**Takeaway:** Provisioning dedicated in-shaft radiating cables (leaky feeders) or cab-mounted client bridge access points is mandatory for metal elevators. Conversely, glass elevators successfully permitted 5 GHz and 6 GHz penetration, meaning external high-density APs are sufficient.