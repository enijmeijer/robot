# Micro:bit Maqueen Robot — Arduino Toolchain Setup

This project programs a **DFRobot micro:Maqueen** robot (chassis + motor driver
board) controlled by a **BBC micro:bit V2**, using the **Arduino** compiler
toolchain (`arduino-cli`) instead of MakeCode/Python.

The micro:bit's nRF5 chip has no native Arduino bootloader; instead we use
the community **`sandeepmistry/arduino-nRF5`** core, which programs the chip
directly over its on-board DAPLink debug/USB interface (no bootloader
flashing required).

- Board FQBN: **`sandeepmistry:nRF5:BBCmicrobitV2`** (nRF52833, Cortex-M4F)
- If you ever use an original V1 micro:bit (nRF51822, Cortex-M0) instead, use
  `sandeepmistry:nRF5:BBCmicrobit`.

## What gets installed

| Component | Purpose |
|---|---|
| `arduino-cli` (Homebrew) | Command-line Arduino compiler/uploader |
| Board index: `sandeepmistry:nRF5` (0.8.0) | Adds "BBC micro:bit V2" board support + `gcc-arm-none-eabi` toolchain + OpenOCD uploader |
| Library: `micro Maqueen` (1.1.1) | Motor/sensor/buzzer API for the Maqueen chassis |
| Library: `Adafruit microbit Library` (1.3.4) | micro:bit LED matrix / BLE support (dependency of Maqueen lib) |
| Library: `BLEPeripheral` (0.4.0) | BLE peripheral support (dependency) |
| Library: `NewPing` (1.9.7) | Ultrasonic distance sensor support |
| Auto-installed deps | `Adafruit BusIO`, `Adafruit GFX Library`, `STM32duino LSM303AGR` |
| **Local core patch** (see below) | Fixes a link error on the V2 (hard-float) target |

Project sketch: [`MaqueenRobot/MaqueenRobot.ino`](./MaqueenRobot/MaqueenRobot.ino)

## ⚠️ Required patch for micro:bit V2

The `sandeepmistry:nRF5` core (v0.8.0) has a bug affecting the **V2** board
only: it fails to link with:

```
error: ...MaqueenRobot.ino.elf uses VFP register arguments, ...pulse_asm.S.o does not
failed to merge target specific data of file ...pulse_asm.S.o
```

Cause: `cores/nRF5/pulse_asm.S` was copied from the Arduino Zero (SAMD) core
and hardcodes `.cpu cortex-m0plus` / `.fpu softvfp` directives that silently
override the command line, and `platform.txt`'s assembler recipe
(`compiler.S.flags`) doesn't pass `-mcpu`/float-ABI flags at all. On V1
(no FPU) this never mattered; V2's nRF52833 has an FPU and uses the
hard-float ABI, exposing the mismatch.

**Fix (already applied on this machine):** run the included script after
installing the core (idempotent — safe to re-run, e.g. after a core
upgrade/reinstall):

```bash
./patches/fix-microbit-v2-fpu.sh
```

It patches two files in the installed core (backups saved as `*.bak`):
- `platform.txt`: adds `-mcpu={build.mcu} {build.float_flags}` to `compiler.S.flags`
- `cores/nRF5/pulse_asm.S`: removes the hardcoded Cortex-M0+/soft-float directives

The raw diff is also kept at
[`patches/nRF5-0.8.0-pulse_asm-fpu-fix.patch`](./patches/nRF5-0.8.0-pulse_asm-fpu-fix.patch)
for reference.

## Setup instructions (repeat on the MacBook)

```bash
# 1. Install arduino-cli via Homebrew
brew install arduino-cli

# 2. Add the community nRF5 (micro:bit) board index and install the core
arduino-cli config init            # only if you have no config yet
arduino-cli config add board_manager.additional_urls \
  https://sandeepmistry.github.io/arduino-nRF5/package_nRF5_boards_index.json
arduino-cli core update-index
arduino-cli core install sandeepmistry:nRF5

# 3. Install the required libraries
arduino-cli lib install "micro Maqueen" "Adafruit microbit Library" \
  "BLEPeripheral" "NewPing"

# 4. Clone/copy this project, then apply the micro:bit V2 core patch
cd /path/to/this/project
./patches/fix-microbit-v2-fpu.sh

# 5. Plug in the micro:bit via USB and check it's detected
arduino-cli board list
# Expect: BBC micro:bit V2   sandeepmistry:nRF5:BBCmicrobitV2   (on /dev/cu.usbmodemXXXX)

# 6. Compile
arduino-cli compile --fqbn sandeepmistry:nRF5:BBCmicrobitV2 MaqueenRobot

# 7. Upload (replace the port with the one from `arduino-cli board list`)
arduino-cli upload -p /dev/cu.usbmodemXXXX --fqbn sandeepmistry:nRF5:BBCmicrobitV2 MaqueenRobot
```

Both compile and upload have been verified end-to-end against a physical
BBC micro:bit V2 + Maqueen robot.

## Known caveats (inherited from the Maqueen Arduino library)

- The Maqueen library is unmaintained/archived; it targets Maqueen **V1**
  hardware and the original micro:bit V1 but works fine on V2 hardware too.
- The 4 onboard NeoPixels (pin 15) are **not** supported by any Arduino
  NeoPixel library on this core.
- If upload/serial behaves oddly, reflashing a MakeCode `.hex` once and then
  retrying the Arduino upload can reset the board into a working state.
- `NewPing` prints an architecture-mismatch warning on compile (expects
  avr/arm/megaavr/esp32); this is harmless — it compiles and works on nRF5.
- BLE-dependent code paths (via `BLEPeripheral`) may need extra care on V2
  due to SoftDevice/header differences — not exercised by the basic motor
  demo sketch in this repo.

## Useful commands

```bash
arduino-cli board list                 # list connected boards/ports
arduino-cli lib list                   # list installed libraries
arduino-cli core list                  # list installed board cores
```

## Copilot CLI skill: program the robot from a prompt

This repo includes a GitHub Copilot CLI skill,
[`skills/maqueen-robot-programmer`](./skills/maqueen-robot-programmer), that
lets you ask Copilot (in Dutch or English) to program the robot: it writes a
new sketch directory with the `.ino` file, compiles it, and — only after you
explicitly confirm — uploads it to the robot on the port in `$MICROBITPORT`.

To install it, copy the skill directory into your personal Copilot skills
folder:

```bash
mkdir -p ~/.copilot/skills
cp -r skills/maqueen-robot-programmer ~/.copilot/skills/
```

Make sure `MICROBITPORT` is set in your shell before uploading (see
`setenv.sh`), then start `copilot` and ask it to program the robot, e.g.
"laat de robot vooruit rijden en stoppen voor een obstakel" or "make the
robot blink its LEDs when button A is pressed".
