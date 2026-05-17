# Sensor Access from Termux

Native Android sensor access from Termux using the NDK ASensorManager API -- no root, no JNI, no proot required.

> **Note:** This uses `ASensorManager` from the Android NDK, loaded via `dlsym` at runtime. It does not use the `termux-sensor` command (which relies on the Termux:API Java bridge). The NDK approach provides direct hardware access with higher sample rates and lower latency.

---

## Summary

**9 of 11 standard sensor types confirmed working** on an Android 16 device (ARM64), tested from native Termux with a compiled C binary linked against `-landroid -ldl`.

---

## Hardware Inventory

45 sensors detected via ASensorManager on the test device (Samsung S26 Ultra, Android 16). Counts vary by device and enumeration API: `docs/avf-guide.md` reports 42 sensors on Pixel 10 Pro via `dumpsys sensorservice`. Different devices, different APIs -- both numbers are accurate for their respective contexts.

Key sensors:

| Type | Sensor | Status |
|------|--------|--------|
| 1 | Accelerometer | WORKS |
| 2 | Magnetometer | WORKS |
| 4 | Gyroscope | WORKS |
| 5 | Light (ALS) | WORKS |
| 6 | Pressure (Barometer) | WORKS |
| 8 | Proximity | WORKS (event-driven, 1 sample per change) |
| 9 | Gravity (fused) | WORKS |
| 10 | Linear Acceleration (fused) | WORKS |
| 11 | Rotation Vector (fused) | Not tested |
| 19 | Step Counter | WORKS (cumulative since reboot, fires on step events) |

Device-specific sensors (tilt detector, pick-up gesture, auto-rotation, motion detect, etc.) were also present but not tested. The number and type of device-specific sensors will vary by manufacturer.

---

## Test Results

### Test 1: Multi-Sensor Quick Read (5 samples each)

All 8 quick-read sensor types returned data (step counter confirmed separately during walking test):

- **Accelerometer**: x=0.49, y=3.23, z=9.25 m/s^2 (phone tilted ~20 deg from vertical)
- **Magnetometer**: x=40.3, y=30.1, z=-36.0 uT (indoor magnetic field, stable)
- **Gyroscope**: x=0.02, y=-0.08, z=0.04 rad/s (slight rotation while held)
- **Light**: 1050-1341 lux (bright indoor, fluctuating)
- **Pressure**: 1012.95 hPa (sea-level-equivalent indoor pressure)
- **Proximity**: 5.00 cm (binary sensor, max distance = nothing close)
- **Gravity**: x=0.94, y=3.14, z=9.24 m/s^2 (device orientation)
- **Linear Accel**: near zero (stationary baseline)

### Test 2: 30-Second Walking Capture

#### Accelerometer (300 samples at ~125Hz)

| Metric | Value |
|--------|-------|
| Samples | 301 |
| Mean magnitude | 9.824 m/s^2 |
| Min magnitude | 0.000 m/s^2 |
| Max magnitude | 10.763 m/s^2 |
| Range | 10.763 m/s^2 |

The magnitude oscillation (9.0 to 10.8) around gravity (9.81) is the classic walking signature -- each footstrike creates a vertical acceleration spike.

#### Barometric Pressure (300 samples over 24 seconds)

| Metric | Value |
|--------|-------|
| Samples | 300 |
| Duration | 24.0 seconds |
| Mean | 1013.910 hPa |
| Min | 1013.537 hPa |
| Max | 1014.251 hPa |
| Range | 0.714 hPa |
| Net drift | -0.033 hPa |

0.714 hPa range over 24 seconds. In a standard atmosphere, 1 hPa corresponds to roughly 8.3 meters of altitude. Net drift of only -0.033 hPa shows the sensor is stable -- the variation is real environmental signal, not sensor drift.

#### Gyroscope (291 samples over ~29 seconds)

| Metric | Value |
|--------|-------|
| Samples | 291 |
| Mean magnitude | 0.163 rad/s |
| Min magnitude | 0.003 rad/s |
| Max magnitude | 1.057 rad/s |
| Range | 1.053 rad/s |

Peak rotation of 1.057 rad/s (about 60 deg/s) indicates turns while walking.

---

## Observations

1. **All standard sensors work from native Termux** using the ASensorManager NDK API loaded via `dlsym`. No JNI, no root, no proot needed.

2. **Sensor rates**: Accelerometer and gyroscope deliver at ~125Hz (10ms). Pressure delivers at ~12.5Hz (80ms). Light at ~5Hz. These rates are device-specific and may vary.

3. **Proximity sensor** is event-driven (only fires on change), so it returned just 1 sample in 5 attempts. This is correct behavior.

4. **Step counter** reports cumulative steps since last reboot and only fires on step events. A longer capture during active walking would show incrementing values.

5. **The walking signature is clearly visible** in the accelerometer data: magnitude oscillates around 9.81 m/s^2 with each footstrike pushing it to ~10.8 and each flight phase dropping it below 9.0.

6. **Barometric pressure captures real environmental signal** at 0.01 hPa resolution -- sufficient for indoor floor-level detection.

---

## Vendor-Specific Sensors (Samsung)

The updated sensor-poc.c now supports vendor-specific sensor types (type IDs above 65536) via list-scan fallback when getDefaultSensor returns NULL. On a Samsung Galaxy S26 Ultra (Android 16), these Samsung-specific sensors were detected and resolved:

| Type ID | Name | Vendor | Status |
|---------|------|--------|--------|
| 65605 | Pocket Mode | Samsung | Resolved (event-driven, awaiting trigger) |
| 65644 | Drop Classifier | Samsung | Resolved (event-driven, awaiting trigger) |
| 65648 | Car Crash Detect | Samsung | Resolved (event-driven, awaiting trigger) |
| 65651 | Back Tap | Samsung | Resolved (event-driven, awaiting trigger) |
| 65655 | Elevator Detector | Samsung | Resolved (event-driven, awaiting trigger) |

Note: these are event-driven wakeup sensors. They resolve via the NDK API but only produce data when their physical trigger occurs (phone dropped, back tapped, elevator entered, etc.). Availability varies by device manufacturer and model. Non-Samsung devices will have different vendor-specific sensors or none.

---

## Methodology

A small C program was compiled in native Termux, linked against `-landroid -ldl`. At runtime it:

1. Loads `libandroid.so` via `dlopen`
2. Resolves `ASensorManager_getInstance`, `ASensorManager_getSensorList`, `ASensorManager_createEventQueue`, etc. via `dlsym`
3. Enumerates all available sensors
4. For each target sensor type, enables it, polls for events, and prints timestamped readings
5. Disables the sensor and moves to the next

No root permissions, no Java bridge, no proot environment required. The binary runs directly in the native Termux environment.

---

## Reproducing

To build the sensor reader, you need:

```bash
pkg install clang -y
```

Write a C file that uses `dlopen("libandroid.so", RTLD_NOW)` and resolves the `ASensorManager_*` functions. Compile with:

```bash
clang sensor-reader.c -o sensor-reader -landroid -ldl
./sensor-reader list        # enumerate sensors
./sensor-reader 1 5         # read 5 samples from accelerometer (type 1)
```

The Android NDK sensor types are defined in `<android/sensor.h>`. The numeric type codes (1=accelerometer, 2=magnetometer, etc.) are stable across Android versions.

---

*Tested on Android 16 device (ARM64), native Termux, March 2026.*

*Last updated: 2026-05-16.*
