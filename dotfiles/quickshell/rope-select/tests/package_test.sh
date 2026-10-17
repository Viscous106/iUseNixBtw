#!/usr/bin/env bash
set -uo pipefail
fails=0
check() { if [ "$2" = "$3" ]; then echo "  ok: $1"; else
  echo "  FAIL: $1 (expected '$2', got '$3')"; fails=$((fails+1)); fi }

out="$(nix build --no-link --print-out-paths \
  "path:/persist/nixos-config#nixosConfigurations.laptop.pkgs.rope-select" 2>/dev/null | head -1)"
check "package builds" "1" "$([ -n "$out" ] && echo 1 || echo 0)"
check "binary exists"  "1" "$([ -x "$out/bin/rope-select" ] && echo 1 || echo 0)"
check "quickshell on wrapped PATH" "1" \
  "$(grep -q 'quickshell' "$out/bin/rope-select" 2>/dev/null && echo 1 || echo 0)"
# slurp is the fallback path; if it is not in the closure the one mechanism
# that exists to survive a broken overlay would itself fail.
check "slurp on wrapped PATH" "1" \
  "$(grep -q 'slurp' "$out/bin/rope-select" 2>/dev/null && echo 1 || echo 0)"

if [ "$fails" -eq 0 ]; then echo "ALL PASS"; exit 0; else echo "FAILURES=$fails"; exit 1; fi
