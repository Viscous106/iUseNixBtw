#!/usr/bin/env bash
set -uo pipefail

# ScreenMode.sh — evidence-based screen comfort / media profiles for Hyprland.
#
#   menu | next | prev | set <profile> | init | status | list | breaks [on|off|toggle]
#
# SUPER + SHIFT + M opens the rofi picker (see lua/keybinds.lua).
#
# ---------------------------------------------------------------- design notes
#
# LUMINANCE IS HANDLED BY THE BACKLIGHT, COLOUR BY THE SHADER. They are separate
# knobs on purpose:
#   * Dimming in the shader only scales the digital code values. The panel still
#     emits the same light, you just lose shadow detail and get banding, and the
#     melanopic dose barely moves.
#   * Dimming the backlight removes actual photons. That is what the comfort and
#     circadian research is measuring, and it costs no image quality.
# So every shader here is normalised to peak white (max channel == 1.0) and does
# pure chromaticity; brightnessctl carries the brightness.
#
# Colour maths is done in LINEAR light (sRGB decode -> scale -> re-encode).
# Scaling gamma-encoded values crushes shadows non-uniformly and gets the
# resulting chromaticity wrong.
#
# Backend is decoration:screen_shader — gamma-control (gammastep/wlsunset) is a
# silent no-op on this machine, Hyprland reports "Zero outputs support gamma
# adjustment". Under the Lua parser, runtime options go through `hyprctl eval
# hl.config{...}`; plain `hyprctl keyword` is rejected.

STATE_DIR="$HOME/.cache/hypr"
STATE_FILE="$STATE_DIR/screenmode.state"
BREAK_PID="$STATE_DIR/screenmode-breaks.pid"
SHADER_DIR="$HOME/.config/hypr/shaders/screenmode"
ROFI_THEME="$HOME/.config/rofi/config-screenmode.rasi"
mkdir -p "$STATE_DIR" "$SHADER_DIR"

# Set SCREENMODE_BACKLIGHT=0 to make profiles colour-only and leave brightness alone.
USE_BACKLIGHT="${SCREENMODE_BACKLIGHT:-1}"

# id|label|icon|kelvin|backlight%|shader-kind|blurb
#   shader-kind: none | chroma | vivid
PROFILES=(
  "day|Day|󰃠|6500|80|none|Daylight-balanced. Bright room, general use."
  "reading|Reading|󰂺|5000|55|chroma|Long text in normal indoor light."
  "night|Night|󰤄|3400|30|chroma|Evening, from ~3h before bed."
  "dark|Dark Room|󰉠|2700|12|chroma|Late night in a dark room."
  "cinema|Cinema|󰟞|6500|100|none|Movies. Untouched, colour-accurate."
  "vivid|Vivid|󰊴|6500|100|vivid|Games. Punchier saturation + contrast."
)

field() { printf '%s' "$1" | cut -d'|' -f"$2"; }

profile_line() {
  local p
  for p in "${PROFILES[@]}"; do
    [[ "$(field "$p" 1)" == "$1" ]] && { printf '%s' "$p"; return 0; }
  done
  return 1
}

current_profile() {
  local m
  m="$(cat "$STATE_FILE" 2>/dev/null || true)"
  profile_line "$m" >/dev/null 2>&1 || m="day"
  printf '%s' "$m"
}

profile_index() {
  local i=0 p
  for p in "${PROFILES[@]}"; do
    [[ "$(field "$p" 1)" == "$1" ]] && { printf '%s' "$i"; return 0; }
    i=$((i + 1))
  done
  printf '0'
}

# ------------------------------------------------------- temperature -> RGB gain
# Tanner Helland's blackbody approximation, normalised twice: against its own value
# at 6500K (so 6500K is exactly 1,1,1) and then against its own peak channel (so
# white stays white and only the hue shifts — the backlight does the dimming).
temp_rgb() { # temp_rgb <kelvin> -> "R G B"
  awk -v k="$1" '
    function clamp(v) { return v < 0 ? 0 : (v > 255 ? 255 : v) }
    function red(t) {
      if (t <= 66) return 255
      return clamp(329.698727446 * (t - 60) ^ -0.1332047592)
    }
    function green(t) {
      if (t <= 66) return clamp(99.4708025861 * log(t) - 161.1195681661)
      return clamp(288.1221695283 * (t - 60) ^ -0.0755148492)
    }
    function blue(t) {
      if (t >= 66) return 255
      if (t <= 19) return 0
      return clamp(138.5177312231 * log(t - 10) - 305.0447927307)
    }
    BEGIN {
      t = k / 100; n = 65
      cr = red(t) / red(n); cg = green(t) / green(n); cb = blue(t) / blue(n)
      mx = cr; if (cg > mx) mx = cg; if (cb > mx) mx = cb
      if (mx > 0) { cr /= mx; cg /= mx; cb /= mx }
      printf "%.6f %.6f %.6f", cr, cg, cb
    }'
}

# ------------------------------------------------------------------- shaders
SRGB_HELPERS='
// sRGB <-> linear. Clamped before pow() so a stray negative cannot produce NaN.
vec3 toLinear(vec3 c) {
    c = clamp(c, 0.0, 1.0);
    return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}
vec3 toSRGB(vec3 c) {
    c = clamp(c, 0.0, 1.0);
    return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), c));
}'

shader_path() { printf '%s/%s.glsl' "$SHADER_DIR" "$1"; }

ensure_shader() { # ensure_shader <profile-id>
  local line kind path rgb
  line="$(profile_line "$1")" || return 1
  kind="$(field "$line" 6)"
  [[ "$kind" == "none" ]] && return 0

  path="$(shader_path "$1")"
  # regenerate when missing or older than this script (the profile table lives here)
  [[ -s "$path" && "$path" -nt "${BASH_SOURCE[0]}" ]] && return 0

  case "$kind" in
    chroma)
      rgb="$(temp_rgb "$(field "$line" 4)" | tr ' ' ',')"
      cat > "$path" <<EOF
// Generated by ScreenMode.sh — edit the PROFILES table, not this file.
// profile: $1 — $(field "$line" 4)K chromaticity, peak white preserved.
precision highp float;
varying vec2 v_texcoord;
uniform sampler2D tex;
$SRGB_HELPERS
void main() {
    vec4 pixColor = texture2D(tex, v_texcoord);
    vec3 lin = toLinear(pixColor.rgb) * vec3($rgb);
    gl_FragColor = vec4(toSRGB(lin), pixColor.a);
}
EOF
      ;;
    vivid)
      cat > "$path" <<EOF
// Generated by ScreenMode.sh — edit the PROFILES table, not this file.
// profile: $1 — saturation in linear light, contrast as an S-curve in gamma space.
precision highp float;
varying vec2 v_texcoord;
uniform sampler2D tex;

const float SATURATION = 1.14;
const float CONTRAST   = 1.07;
$SRGB_HELPERS
void main() {
    vec4 pixColor = texture2D(tex, v_texcoord);

    // Saturate around Rec.709 luma, in linear light so hues do not skew.
    vec3 lin  = toLinear(pixColor.rgb);
    float luma = dot(lin, vec3(0.2126, 0.7152, 0.0722));
    lin = mix(vec3(luma), lin, SATURATION);

    // Contrast around mid-grey, in gamma space where 0.5 is perceptual middle.
    vec3 enc = toSRGB(lin);
    enc = clamp((enc - 0.5) * CONTRAST + 0.5, 0.0, 1.0);

    gl_FragColor = vec4(enc, pixColor.a);
}
EOF
      ;;
  esac
}

set_shader() { hyprctl eval "hl.config{ decoration = { screen_shader = \"$1\" } }" >/dev/null 2>&1; }

set_backlight() { # set_backlight <percent>
  [[ "$USE_BACKLIGHT" == "1" ]] || return 0
  command -v brightnessctl >/dev/null || return 0
  brightnessctl -q set "$1%" 2>/dev/null || true
}

apply_profile() { # apply_profile <profile-id>
  local line kind
  line="$(profile_line "$1")" || return 1
  kind="$(field "$line" 6)"

  if [[ "$kind" == "none" ]]; then
    set_shader "" || return 1
  else
    ensure_shader "$1" || return 1
    set_shader "$(shader_path "$1")" || return 1
  fi
  set_backlight "$(field "$line" 5)"
  echo "$1" > "$STATE_FILE"
}

# ------------------------------------------------------- 20-20-20 break reminder
# The one intervention with decent trial evidence behind it: every 20 min, look at
# something ~20 ft away for 20 s. Blink rate drops from ~15/min to ~5/min on screens,
# which is what actually dries eyes out — no colour filter addresses that.
breaks_running() {
  local pid
  pid="$(cat "$BREAK_PID" 2>/dev/null || true)"
  [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null
}

breaks_start() {
  breaks_running && return 0
  setsid -f bash -c '
    echo $$ > "'"$BREAK_PID"'"
    while true; do
      sleep 1200
      notify-send -u normal -h "string:x-canonical-private-synchronous:eyebreak" \
        "󰈈  Look away — 20 seconds" "Focus on something ~6 m away, and blink a few times."
    done' 2>/dev/null
  sleep 0.3
}

breaks_stop() {
  local pid
  pid="$(cat "$BREAK_PID" 2>/dev/null || true)"
  [[ -n "$pid" ]] && kill -- "-$pid" 2>/dev/null
  [[ -n "$pid" ]] && kill "$pid" 2>/dev/null
  rm -f "$BREAK_PID"
}

cmd_breaks() {
  case "${1:-toggle}" in
    on)  breaks_start; notify-send -u low "󰈈  Eye breaks on" "Reminder every 20 minutes." || true ;;
    off) breaks_stop;  notify-send -u low "󰈈  Eye breaks off" || true ;;
    status) breaks_running && echo on || echo off ;;
    toggle) breaks_running && cmd_breaks off || cmd_breaks on ;;
  esac
}

# ------------------------------------------------------------------- commands
cmd_set() {
  local line
  line="$(profile_line "$1")" || { echo "unknown profile: $1" >&2; cmd_list >&2; exit 2; }
  apply_profile "$1" || { notify-send -u critical "Screen mode" "Failed to apply $1" || true; exit 1; }
  notify-send -u low -h "string:x-canonical-private-synchronous:screenmode" \
    "$(field "$line" 3)  $(field "$line" 2)" \
    "$(field "$line" 4)K · $(field "$line" 5)% brightness
$(field "$line" 7)" || true
}

cmd_step() {
  local n idx
  n="${#PROFILES[@]}"
  idx="$(profile_index "$(current_profile)")"
  idx=$(( (idx + $1 + n) % n ))
  cmd_set "$(field "${PROFILES[$idx]}" 1)"
}

cmd_init() {
  apply_profile "$(current_profile)"
}

cmd_status() {
  local line m
  m="$(current_profile)"
  line="$(profile_line "$m")"
  printf '{"text":"%s","alt":"%s","class":"%s","tooltip":"%s — %sK, %s%% brightness\\n%s"}\n' \
    "$(field "$line" 3)" "$m" "$m" "$(field "$line" 2)" \
    "$(field "$line" 4)" "$(field "$line" 5)" "$(field "$line" 7)"
}

cmd_list() {
  local p rgb
  printf '%-8s %-11s %6s %6s  %-6s %s\n' ID LABEL KELVIN BACKLT SHADER NOTE
  for p in "${PROFILES[@]}"; do
    printf '%-8s %-11s %5sK %5s%%  %-6s %s\n' \
      "$(field "$p" 1)" "$(field "$p" 2)" "$(field "$p" 4)" "$(field "$p" 5)" \
      "$(field "$p" 6)" "$(field "$p" 7)"
  done
  echo
  echo "eye breaks: $(breaks_running && echo on || echo off)"
}

cmd_menu() {
  command -v rofi >/dev/null || { echo "rofi not installed" >&2; exit 1; }
  pidof rofi >/dev/null && pkill rofi

  local cur idx n p
  cur="$(current_profile)"
  n="${#PROFILES[@]}"

  # -format i returns the selected row index, so labels stay free-form.
  # NOTE: the whole row-generating group must be piped into rofi. Losing that pipe
  # makes the command substitution capture the menu text itself, which then fails the
  # numeric test below and the script exits silently — no menu, no error.
  idx="$(
    {
      for p in "${PROFILES[@]}"; do
        if [[ "$(field "$p" 1)" == "$cur" ]]; then
          printf '%s  %-11s  %sK · %s%%   ●\n' "$(field "$p" 3)" "$(field "$p" 2)" "$(field "$p" 4)" "$(field "$p" 5)"
        else
          printf '%s  %-11s  %sK · %s%%\n'     "$(field "$p" 3)" "$(field "$p" 2)" "$(field "$p" 4)" "$(field "$p" 5)"
        fi
      done
      printf '󰔛  %-11s  every 20 min   %s\n' "Eye breaks" "$(breaks_running && echo '●' || echo '○')"
    } | rofi -dmenu -i -format i -config "$ROFI_THEME"
  )" || exit 0

  [[ "$idx" =~ ^[0-9]+$ ]] || exit 0
  if (( idx >= n )); then
    cmd_breaks toggle
  else
    cmd_set "$(field "${PROFILES[$idx]}" 1)"
  fi
}

case "${1:-menu}" in
  menu)   cmd_menu ;;
  next)   cmd_step 1 ;;
  prev)   cmd_step -1 ;;
  set)    cmd_set "${2:?usage: $0 set <profile>}" ;;
  init)   cmd_init ;;
  status) cmd_status ;;
  list)   cmd_list ;;
  breaks) cmd_breaks "${2:-toggle}" ;;
  *) echo "usage: $0 [menu|next|prev|set <profile>|init|status|list|breaks]" >&2; exit 2 ;;
esac
