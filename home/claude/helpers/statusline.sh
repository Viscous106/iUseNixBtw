#!/usr/bin/env bash
# Claude Code statusline — claude-flow V3 aesthetic, 100% real Claude Code data.
# All values come from the statusline stdin JSON (no transcript scraping).
# Edit NAME to taste.

NAME="YASH NITIN VIRULKAR"

input=$(cat)

# ---- pull real fields from stdin JSON (single jq pass) ----
IFS=$'\t' read -r model model_id cwd version style cost dur_ms api_ms added removed \
        ctx_pct ctx_size effort thinking fast_mode \
        rl5_pct rl5_reset rl7_pct rl7_reset now <<EOF
$(printf '%s' "$input" | jq -r '
  [ (.model.display_name // "Claude"),
    (.model.id // "-"),
    (.workspace.current_dir // .cwd // "-"),
    (.version // "?"),
    (.output_style.name // "default"),
    (.cost.total_cost_usd // 0),
    (.cost.total_duration_ms // 0),
    (.cost.total_api_duration_ms // 0),
    (.cost.total_lines_added // 0),
    (.cost.total_lines_removed // 0),
    (.context_window.used_percentage // 0 | round),
    (.context_window.context_window_size // 0),
    (.effort.level // "-"),
    (if .thinking.enabled then "on" else "off" end),
    (if .fast_mode then "on" else "off" end),
    (.rate_limits.five_hour.used_percentage // -1 | round),
    (.rate_limits.five_hour.resets_at // 0 | floor),
    (.rate_limits.seven_day.used_percentage // -1 | round),
    (.rate_limits.seven_day.resets_at // 0 | floor),
    (now | floor)
  ] | @tsv')
EOF

# ---- ANSI 256 colors ----
e=$'\033'; R="${e}[0m"; B="${e}[1m"
purple="${e}[38;5;141m"; magenta="${e}[38;5;207m"; white="${e}[38;5;255m"
green="${e}[38;5;120m"; cyan="${e}[38;5;87m"; gold="${e}[38;5;220m"
red="${e}[38;5;203m"; orange="${e}[38;5;215m"; blue="${e}[38;5;111m"
dim="${e}[38;5;240m"
SEP="${dim} │ ${R}"

# ---- helpers ----
pctcol() { if [ "$1" -lt 50 ]; then printf '%s' "$green"; elif [ "$1" -lt 80 ]; then printf '%s' "$gold"; else printf '%s' "$red"; fi; }
bar()    { local p=$1; local f=$(( (p + 10) / 20 )); local i o=""; [ "$f" -gt 5 ] && f=5; [ "$f" -lt 0 ] && f=0
           for ((i=0;i<5;i++)); do [ "$i" -lt "$f" ] && o="${o}▰" || o="${o}▱"; done; printf '%s' "$o"; }
dur()    { local s=$(( $1 / 1000 ))
           if   [ "$s" -ge 3600 ]; then printf '%dh%dm' $((s/3600)) $(((s%3600)/60))
           elif [ "$s" -ge 60 ];   then printf '%dm%ds' $((s/60)) $((s%60))
           else printf '%ds' "$s"; fi; }
left()   { local s=$1
           if   [ "$s" -le 0 ];    then printf 'now'
           elif [ "$s" -ge 86400 ]; then printf '%dd%dh' $((s/86400)) $(((s%86400)/3600))
           elif [ "$s" -ge 3600 ];  then printf '%dh%dm' $((s/3600)) $(((s%3600)/60))
           else printf '%dm' $((s/60)); fi; }

# ---- git state ----
gitseg=""
if [ -n "$cwd" ] && git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  branch=$(git -C "$cwd" branch --show-current 2>/dev/null)
  [ -z "$branch" ] && branch=$(git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
  [ -z "$branch" ] && branch="(no commits)"
  ahead=0; behind=0
  if up=$(git -C "$cwd" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null); then
    set -- $(git -C "$cwd" rev-list --left-right --count "${up}...HEAD" 2>/dev/null)
    behind=${1:-0}; ahead=${2:-0}
  fi
  staged=0; modified=0; untracked=0
  while IFS= read -r line; do
    case "$line" in
      '??'*) untracked=$((untracked+1)) ;;
      ' '*)  modified=$((modified+1)) ;;
      *)     staged=$((staged+1)) ;;
    esac
  done < <(git -C "$cwd" status --porcelain 2>/dev/null)
  st=""
  [ "$ahead" -gt 0 ]     && st="${st}${green}⇡${ahead}"
  [ "$behind" -gt 0 ]    && st="${st}${red}⇣${behind}"
  [ "$staged" -gt 0 ]    && st="${st}${gold}+${staged}"
  [ "$modified" -gt 0 ]  && st="${st}${orange}~${modified}"
  [ "$untracked" -gt 0 ] && st="${st}${dim}?${untracked}"
  gitseg="${green}🌿 ${branch}${st}${R}${SEP}"
fi

# ---- context (real field, not transcript scraping) ----
case "$ctx_pct" in ''|*[!0-9]*) ctx_pct=0 ;; esac
if   [ "$ctx_size" -ge 1000000 ]; then wlabel="$((ctx_size/1000000))M"
elif [ "$ctx_size" -ge 1000 ];    then wlabel="$((ctx_size/1000))K"
else wlabel="?"; fi
ctxseg="$(pctcol "$ctx_pct")● ${ctx_pct}% ctx${R}"

# ---- rate limits (session quota) ----
lim=""
if [ "$rl5_pct" -ge 0 ]; then
  c=$(pctcol "$rl5_pct")
  lim="${lim}${c}🕐 5h $(bar "$rl5_pct") ${rl5_pct}%${R} ${dim}↻$(left $((rl5_reset - now)))${R}${SEP}"
fi
if [ "$rl7_pct" -ge 0 ]; then
  c=$(pctcol "$rl7_pct")
  lim="${lim}${c}📅 7d $(bar "$rl7_pct") ${rl7_pct}%${R} ${dim}↻$(left $((rl7_reset - now)))${R}${SEP}"
fi

# ---- modes ----
case "$effort" in
  max|xhigh) ecol=$red ;; high) ecol=$orange ;; medium) ecol=$gold ;; *) ecol=$dim ;;
esac
modes="${ecol}🧠 ${effort}${R}"
[ "$thinking"  = "on" ] && modes="${modes}${dim} · ${R}${purple}💭${R}"
[ "$fast_mode" = "on" ] && modes="${modes}${dim} · ${R}${gold}🚀 fast${R}"

# ---- formatting ----
timer=$(dur "$dur_ms"); api_s=$(dur "$api_ms")
costf=$(awk "BEGIN{printf \"%.2f\", ${cost}}")
dir="${cwd/#$HOME/\~}"; [ -z "$dir" ] && dir="~"

# ---- emit (three rows) ----
printf '%b\n' "${purple}🔮 ${B}Claude Flow V3${R} ${magenta}⚡ ${white}${NAME}${R}${SEP}${gitseg}${cyan}🤖 ${model} ${dim}(${wlabel})${R}${SEP}${cyan}⏱ ${timer}${R}${SEP}${ctxseg}${SEP}${gold}💲${costf}${R}"
printf '%b\n' "${blue}📁 ${dir}${R}${SEP}${green}📝 +${added} ${red}-${removed}${R}${SEP}${orange}🔧 v${version}${R}${SEP}${purple}🎨 ${style}${R}${SEP}${cyan}⚡ api ${api_s}${R}${SEP}${dim}${model_id}${R}"
printf '%b'   "${lim}${modes}"
