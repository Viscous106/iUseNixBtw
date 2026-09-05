# Shell-sourceable defaults for JaKooLit helper scripts (bash).
# Mirrors the values in lua/user_defaults.lua. These scripts are plain bash and
# cannot read the Lua config, so the few values they need are duplicated here.
# (Sourced by RofiSearch.sh, etc.)

edit="${EDITOR:-nvim}"
term="kitty"
files="thunar"
Search_Engine="https://www.google.com/search?q={}"
