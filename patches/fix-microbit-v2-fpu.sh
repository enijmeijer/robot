#!/usr/bin/env bash
# Fixes the sandeepmistry:nRF5 core (as installed via arduino-cli) so the
# BBC micro:bit V2 (nRF52833, Cortex-M4F, hard-float) target compiles and
# links correctly.
#
# Without this fix, compiling for sandeepmistry:nRF5:BBCmicrobitV2 fails at
# link time with:
#   error: ...elf uses VFP register arguments, ...pulse_asm.S.o does not
#   failed to merge target specific data of file ...pulse_asm.S.o
#
# Root cause (two bugs, both fixed here):
#  1. platform.txt's `compiler.S.flags` recipe for assembling .S files does
#     not pass `-mcpu` / `{build.float_flags}`, so pulse_asm.S is always
#     assembled with the assembler's default (soft-float) ABI regardless of
#     the target board.
#  2. cores/nRF5/pulse_asm.S (copied historically from the Arduino Zero/SAMD
#     core) hardcodes `.cpu cortex-m0plus`, `.fpu softvfp` and several
#     `.eabi_attribute` directives, which override whatever is passed on the
#     command line anyway.
#
# This only affects BBCmicrobitV2 (Cortex-M4F/hard-float). BBCmicrobit V1
# (Cortex-M0, no FPU) is unaffected and keeps working after this patch.
#
# Usage:
#   ./fix-microbit-v2-fpu.sh                     # auto-detect core version
#   ./fix-microbit-v2-fpu.sh /path/to/nRF5/0.8.0 # explicit core path
#
# Safe to re-run (idempotent) — e.g. after `arduino-cli core install/upgrade`
# reinstalls the core and the fix needs to be re-applied.

set -euo pipefail

CORE_DIR="${1:-}"
if [ -z "$CORE_DIR" ]; then
  CORE_DIR=$(find "$HOME/Library/Arduino15/packages/sandeepmistry/hardware/nRF5" \
    -maxdepth 1 -mindepth 1 -type d 2>/dev/null | sort -V | tail -1)
fi

if [ -z "$CORE_DIR" ] || [ ! -d "$CORE_DIR" ]; then
  echo "Could not find sandeepmistry:nRF5 core install directory." >&2
  echo "Install it first: arduino-cli core install sandeepmistry:nRF5" >&2
  echo "Or pass the path explicitly, e.g.:" >&2
  echo "  $0 \$HOME/Library/Arduino15/packages/sandeepmistry/hardware/nRF5/0.8.0" >&2
  exit 1
fi

echo "Using core dir: $CORE_DIR"

PLATFORM_TXT="$CORE_DIR/platform.txt"
PULSE_ASM="$CORE_DIR/cores/nRF5/pulse_asm.S"

# --- Fix 1: platform.txt compiler.S.flags ---
if grep -q '^compiler.S.flags=-c -g -x assembler-with-cpp$' "$PLATFORM_TXT"; then
  sed -i.bak \
    's/^compiler.S.flags=-c -g -x assembler-with-cpp$/compiler.S.flags=-mcpu={build.mcu} -mthumb {build.float_flags} -c -g -x assembler-with-cpp/' \
    "$PLATFORM_TXT"
  echo "Patched: $PLATFORM_TXT (compiler.S.flags now includes -mcpu/{build.float_flags})"
elif grep -q '^compiler.S.flags=-mcpu={build.mcu}' "$PLATFORM_TXT"; then
  echo "Already patched: $PLATFORM_TXT"
else
  echo "WARNING: unexpected compiler.S.flags line in $PLATFORM_TXT — please check manually." >&2
fi

# --- Fix 2: pulse_asm.S hardcoded .cpu/.fpu/.eabi_attribute directives ---
if grep -q '^\s*\.cpu cortex-m0plus$' "$PULSE_ASM"; then
  # Delete the hardcoded directive block (the .cpu line through the last
  # .eabi_attribute line, just before ".file \"count.c\"").
  sed -i.bak '/^\t\.cpu cortex-m0plus$/,/^\t\.eabi_attribute 18, 4/d' "$PULSE_ASM"
  echo "Patched: $PULSE_ASM (removed hardcoded Cortex-M0+/soft-float directives)"
elif ! grep -q '^\s*\.cpu cortex-m0plus$' "$PULSE_ASM"; then
  echo "Already patched (or directives absent): $PULSE_ASM"
fi

# --- Clear arduino-cli build caches so the fix takes effect immediately ---
rm -rf "$HOME/Library/Caches/arduino/cores"/* "$HOME/Library/Caches/arduino/sketches"/* 2>/dev/null || true

echo "Done. Recompile with:"
echo "  arduino-cli compile --fqbn sandeepmistry:nRF5:BBCmicrobitV2 <sketch>"
