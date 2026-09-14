# Scale Contract & Runtime Audit: 1 Godot Unit = 1 Metre

## Overview
This document audits the world-scale mismatch in **URBAN Strike Rogue** and establishes a unified scale contract:
$$\mathbf{1.0\text{ Godot Unit} = 1.0\text{ Metre}}$$

Measurements were gathered directly via runtime AABB inspection and collision shape bounds rather than guesswork.

---

## 1. Runtime Scale Audit: Before vs Target Dimensions

| Entity / Asset | Initial Runtime Dimension (Before) | Target Contract Range | Adjusted Dimension (After) | Status & Verification |
| :--- | :--- | :--- | :--- | :--- |
| **Player Helicopter**<br>`player_helicopter.tscn` | Rotor Diameter: **5.30 m**<br>Fuselage Length: **4.20 m**<br>Collision: $r=0.95, h=4.20\text{m}$ | Rotor: **11.0 – 13.0 m**<br>Fuselage: **9.0 – 12.0 m** | Rotor Diameter: **12.0 m** ($r=6.0\text{m}$)<br>Fuselage Length: **9.60 m**<br>Collision: $r=1.90, h=9.60\text{m}$ | **Scaled 2.26×**.<br>Visuals, weapon mounts, collision, downwash, rotor blur aligned. |
| **Civilian Car**<br>`parked_vehicle.tscn` | Length: **4.80 m**<br>Width: **2.20 m**, Height: **0.90 m** | Length: **4.0 – 5.0 m**<br>Width: **1.8 – 2.2 m** | Length: **4.80 m**<br>Width: **2.20 m**, Height: **1.45 m** | **Baseline Anchor**.<br>Car dimensions adhere to realistic 1:1 metre scale. |
| **Local 2-Way Road**<br>`road_straight.tscn` | Asphalt Width: **18.0 m**<br>Total Shoulders: **22.0 m** | Asphalt Width: **8.0 – 10.0 m**<br>Sidewalks: **1.5 – 2.5 m** each | Asphalt Width: **9.0 m** (2 lanes @ 4.5m)<br>Total with Sidewalks: **13.0 m** | **Reduced from 18m to 9m** asphalt.<br>Edge lines at $\pm 4.2\text{m}$. |
| **Main City Avenue**<br>`wide_avenue.tscn` | Total Width: **30.0 m**<br>(Asphalt: 26.0 m) | Asphalt: **14.0 – 18.0 m**<br>Total with Medians: **18.0 – 24.0 m** | Asphalt: **16.0 m** (4 lanes @ 4.0m)<br>Total with Sidewalks: **20.0 m** | **Reduced from 26m to 16m** asphalt.<br>Edge lines at $\pm 7.7\text{m}$. |
| **Low-Rise Building A**<br>`building_small.tscn` | Footprint: **8.39 × 6.42 m**<br>Height: **6.40 m** (~2 small storeys) | Footprint: **14.0 – 25.0 m**<br>Height: **9.0 – 18.0 m** (3–5 storeys) | Footprint: **18.46 × 14.12 m**<br>Height: **14.08 m** (~4 storeys) | **Scaled 2.2×**.<br>Collision $18.46 \times 14.08 \times 14.12$, roof at $14.20\text{m}$. |
| **Low-Rise Building B**<br>`building_small_b.tscn` | Footprint: **5.65 × 7.15 m**<br>Height: **4.74 m** | Footprint: **14.0 – 25.0 m**<br>Height: **9.0 – 18.0 m** (3–5 storeys) | Footprint: **13.56 × 17.16 m**<br>Height: **11.38 m** (~3–4 storeys) | **Scaled 2.4×**.<br>Collision $13.56 \times 11.38 \times 17.16$, roof at $11.50\text{m}$. |
| **Mid-Rise Building A**<br>`building_medium.tscn` | Footprint: **10.42 × 6.21 m**<br>Height: **8.82 m** | Footprint: **18.0 – 32.0 m**<br>Height: **20.0 – 45.0 m** (6–13 storeys) | Footprint: **25.00 × 19.87 m**<br>Height: **27.34 m** (~8 storeys) | **Scaled 2.4–3.1×**.<br>Collision $25.00 \times 27.34 \times 19.87$, roof at $27.46\text{m}$. |
| **Mid-Rise Building B**<br>`building_medium_b.tscn` | Footprint: **8.95 × 6.40 m**<br>Height: **9.63 m** | Footprint: **18.0 – 32.0 m**<br>Height: **20.0 – 45.0 m** (6–13 storeys) | Footprint: **22.38 × 16.00 m**<br>Height: **28.88 m** (~8–9 storeys) | **Scaled 2.5–3.0×**.<br>Collision $22.38 \times 28.88 \times 16.00$, roof at $29.00\text{m}$. |
| **High-Rise Skyscraper A**<br>`building_large.tscn` | Footprint: **7.04 × 7.63 m**<br>Height: **24.62 m** | Footprint: **22.0 – 35.0 m**<br>Height: **50.0 – 90.0 m** (15–28 storeys) | Footprint: **26.88 × 15.26 m**<br>Height: **64.00 m** (~20 storeys) | **Scaled 2.0–2.6×**.<br>TowerA: $h=64.0\text{m}$, TowerB: $h=44.55\text{m}$, roof at $64.12\text{m}$. |
| **High-Rise Skyscraper B**<br>`building_large_b.tscn` | Footprint: **6.80 × 6.80 m**<br>Height: **22.40 m** | Footprint: **22.0 – 35.0 m**<br>Height: **50.0 – 90.0 m** (15–28 storeys) | Footprint: **25.26 × 13.60 m**<br>Height: **58.24 m** (~18 storeys) | **Scaled 2.0–2.6×**.<br>TowerMain: $h=58.24\text{m}$, TowerAnnex: $h=47.74\text{m}$, roof at $58.36\text{m}$. |
| **Warehouse Depot**<br>`warehouse.tscn` | Footprint: **15.65 × 8.01 m**<br>Height: **7.66 m** | Footprint: **25.0 – 45.0 m**<br>Height: **10.0 – 16.0 m** | Footprint: **28.17 × 14.42 m**<br>Height: **12.26 m** | **Scaled 1.8× width, 1.6× height**.<br>Collision $28.17 \times 12.26 \times 14.42$, roof at $12.38\text{m}$. |
| **Warehouse Sawtooth**<br>`warehouse_sawtooth.tscn` | Footprint: **13.13 × 14.76 m**<br>Height: **7.50 m** | Footprint: **25.0 – 45.0 m**<br>Height: **10.0 – 16.0 m** | Footprint: **26.26 × 29.52 m**<br>Height: **12.00 m** | **Scaled 2.0× width, 1.6× height**.<br>Collision $26.26 \times 12.00 \times 29.52$, roof at $12.12\text{m}$. |

---

## 2. Scale Alignment Rules & Clearances

1. **Helicopter Systems**:
   - `FlightTiltPivot/Visuals`: scale adjusted by $2.26\times$ ($1.0 \rightarrow 2.26$).
   - `CollisionShape3D`: radius adjusted to $1.90\text{m}$, height adjusted to $9.60\text{m}$.
   - `RotorBlurDisc`: CylinderMesh top/bottom radius set to $6.0\text{m}$ ($12.0\text{m}$ diameter).
   - `GunMount`, `MuzzleMarker`, and `MissilePod` sockets scaled and repositioned in tandem.
   - `GroundShadow` and `DownwashDust` particle radii scaled proportionally.
   - Camera: base distance $36.0\text{m}$, height $24.0\text{m}$, camera far clip extended from $300\text{m}$ to $750\text{m}$. Flight speed ($38\text{ m/s} = 137\text{ km/h}$) and acceleration ($42\text{ m/s}^2$) remain untouched.
   - Helicopter altitude range: minimum altitude $3.6\text{m}$, maximum altitude $90.0\text{m}$.
2. **Street Corridors & Building Wrappers**:
   - In 128m chunks, streets run along center lines with $16\text{m} - 24\text{m}$ facade-to-facade clearance.
   - 12.0m rotor helicopter has ample $2\text{m} - 6\text{m}$ lateral safety clearance on each side even when flying at low altitudes down street canyons.
   - Rooftop markers (`RooftopDefensePoint`, `RooftopSpawnPoint`, `Equipment`, `Lookout`) placed on elevated roofs ($y = \text{height} + 0.12\text{m}$).
3. **Gameplay & Spawner Integration**:
   - Spawner clearance checks (`min_safe_dist = 38.0m`) remain fully valid in the 1 unit = 1 metre world.
   - City chunks ($128\text{m} \times 128\text{m}$) stream seamlessly across a 2048m × 2048m world envelope.
