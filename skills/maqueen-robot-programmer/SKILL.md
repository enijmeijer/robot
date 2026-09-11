---
name: maqueen-robot-programmer
description: Programs a DFRobot micro:Maqueen robot (BBC micro:bit V2, Arduino/arduino-cli toolchain) from a natural-language request in Dutch or English. Writes a new sketch directory containing the .ino file, compiles it, and — only after explicit user confirmation — uploads it to the robot over the port in the MICROBITPORT environment variable. Use whenever the user asks to make the robot/robotje/maqueen/micro:bit do something, drive, avoid obstacles, follow a line, blink, play sounds, etc.
---

# Maqueen robot programmer

Turns a user's request — in **Dutch or English** — into working Arduino
firmware for a **DFRobot micro:Maqueen** chassis driven by a **BBC micro:bit
V2**, compiled and uploaded with `arduino-cli`. This project does NOT use
MakeCode/Python; it uses the `sandeepmistry:nRF5` Arduino core.

## When to use this skill

Trigger on any request to program, change, or test the robot's behavior,
in Dutch or English, e.g. "laat het robotje vooruit rijden en stoppen voor
een obstakel", "maak een lijnvolger", "make the robot blink its LEDs and
play a sound when button A is pressed". Respond to the user in the same
language they used; keep code, comments, and identifiers in English for
portability.

## Fixed facts about this setup (do not re-derive)

- Board FQBN: `sandeepmistry:nRF5:BBCmicrobitV2`
- Upload port: **always** the `MICROBITPORT` environment variable — never
  hardcode a `/dev/cu.usbmodemXXXX` path. If `MICROBITPORT` is not set in
  the current shell, tell the user to set it (see `setenv.sh` in the repo
  root) or export it before uploading, and stop — do not guess a port.
- Example convenience scripts exist at `./bin/compile <dir>` and
  `./bin/upload <dir>` (default to `MaqueenRobot` if no dir given); they
  just wrap the two `arduino-cli` commands below. You may use them or call
  `arduino-cli` directly — either is fine, but `upload` must never run
  without the confirmation step in this skill.
- Known one-time toolchain issue: the `sandeepmistry:nRF5` core has a
  link bug on V2 boards (`uses VFP register arguments ... does not` /
  `failed to merge target specific data`). If compilation fails with that
  error, run `./patches/fix-microbit-v2-fpu.sh` once and recompile before
  concluding something is wrong with the sketch.

## Workflow

0. **Don't ask for permission to create a new directory**
   Only when you are changing stuff that already exist this should be considered.

1. **Understand the request.** If the desired behavior, sensors, or pins
   are ambiguous (e.g. unclear which sensors to use, what "close" means
   for an obstacle, which LED/sound to trigger), ask the user a short
   clarifying question (via `ask_user`) rather than guessing. Otherwise
   proceed directly — don't over-ask for simple/obvious requests.

2. **Pick a sketch name and directory.** Arduino requires the sketch
   folder name to exactly match the `.ino` filename. Choose a short
   PascalCase name describing the behavior (e.g. `LineFollower`,
   `ObstacleAvoider`, `BlinkAndBeep`). Check whether a directory with that
   name already exists in the repo root:
   - If it exists and this is clearly an update to the same behavior,
     edit the existing `.ino` in place.
   - If it exists but is unrelated, or to avoid ambiguity, ask the user
     whether to overwrite it or pick a different name.
   - Otherwise create a new directory `<Name>/` with `<Name>.ino` inside 
    but don't ask the user for confirmation or approval

3. **Write the sketch** using the Maqueen library API reference below.
   Keep it focused on what was asked; don't add unrelated features. Add
   short English comments for non-obvious logic.

4. **Compile before offering to upload:**
   ```bash
   arduino-cli compile --fqbn sandeepmistry:nRF5:BBCmicrobitV2 <Name>
   # or: ./bin/compile <Name>
   ```
   - If it fails with the VFP/pulse_asm error described above, run
     `./patches/fix-microbit-v2-fpu.sh` and recompile.
   - For any other error, fix the sketch and recompile until it succeeds.
     Don't move on to upload with a failing/uncompiled sketch.

5. **Confirm before uploading — always, every time.** Never upload
   automatically. Use `ask_user` (or ask directly in chat if the tool is
   unavailable) to show: the sketch directory, a one-line summary of what
   it does, and the target port (value of `$MICROBITPORT`). Ask the user
   to confirm the upload to the physical robot before proceeding. Reply
   in the language the user has been using (Dutch or English), e.g.:
   - EN: "Sketch `LineFollower/LineFollower.ino` compiled successfully.
     Upload it to the robot now on port $MICROBITPORT?"
   - NL: "De sketch `LineFollower/LineFollower.ino` is succesvol
     gecompileerd. Wil je deze nu naar de robot uploaden op poort
     $MICROBITPORT?"

6. **Only on explicit yes, upload:**
   ```bash
   arduino-cli upload -p "$MICROBITPORT" --fqbn sandeepmistry:nRF5:BBCmicrobitV2 <Name>
   # or: ./bin/upload <Name>
   ```
   If `$MICROBITPORT` is empty/unset, stop and ask the user to set it
   first (don't fall back to auto-detecting or hardcoding a port). If the
   user declines the upload, leave the compiled sketch in place and stop
   without uploading.

7. **Report the result** briefly: directory/file written, compile status,
   and whether it was uploaded (or why not, if declined/skipped).

## Maqueen / micro:bit V2 API cheat sheet

```cpp
#include <Maqueen.h>
Maqueen bot;
```

Motors & movement (`bot.setSpeed()` sets % speed 1–100 for both motors
before calling a movement function):
- `bot.setSpeed(int speed)` — 1–100 %
- `bot.forward()`, `bot.backward()`, `bot.stop()`
- `bot.left()`, `bot.right()` — turn one side slower/stopped
- `bot.spinLeft()`, `bot.spinRight()` — spin in place
- `bot.motorRun(int motor, int direction, int speed)` — per-motor control;
  `motor`: `M1` (left) / `M2` (right); `direction`: `CW` / `CCW`

Sensors & buttons:
- `bot.readPatrolLeft()`, `bot.readPatrolRight()` — line sensors; on the
  Maqueen line map, **black returns 0, white returns 1**
- `bot.readIR()` — IR receiver
- `bot.readA()`, `bot.readB()` — micro:bit buttons A/B (true while held)

LEDs & sound:
- `digitalWrite(LED1, HIGH/LOW)` (left LED), `digitalWrite(LED2, HIGH/LOW)`
  (right LED)
- `bot.beep(float noteFrequency, long noteDuration)` and built-in effects:
  `bot.squeak()`, `bot.catcall()`, `bot.ohhh()`, `bot.laugh()`,
  `bot.laugh2()`, `bot.waka()`, `bot.r2d2()`, `bot.scale()`, `bot.uhoh()`,
  `bot.error()`, `bot.sos()`

Ultrasonic distance sensor (separate from the Maqueen line/IR sensors —
needs its own `NewPing` instance):
```cpp
NewPing sonar(TRIGGER_PIN, ECHO_PIN, MAX_DISTANCE); // pins from Maqueen.h
int distance_in = sonar.ping_in();  // inches
int distance_cm = sonar.ping_cm();  // centimeters
```

micro:bit 5x5 LED matrix (optional, for status/emoji feedback):
```cpp
#include <Adafruit_Microbit.h>
Adafruit_Microbit_Matrix microbit;   // or Adafruit_Microbit microbit; then microbit.matrix.*
microbit.begin();
microbit.print("A");        // scroll text
microbit.show(smile_bmp);   // built-in bitmaps, e.g. smile_bmp, sad (from images.h)
microbit.clear();
```

Always call `bot.begin()` (and `microbit.begin()` if the matrix is used)
in `setup()`. `Serial.begin(9600)` is conventional for debug prints in
these sketches (see existing examples in the repo root, e.g.
`Avoid/Avoid.ino`, `Follow/Follow.ino`, `Sensor/Sensor.ino`) — read one of
those for style/reference if unsure.

## Non-negotiable rules

- Never upload to the robot without an explicit, fresh user confirmation
  for that specific upload — a prior confirmation does not carry over to
  a later change.
- Never hardcode a serial port; always use `$MICROBITPORT`.
- Never skip compilation before offering to upload.
