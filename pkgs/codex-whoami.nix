# ── codex-whoami ────────────────────────────────────────────────────────────
# Reports which OpenAI org/project the Codex CLI is actually billing.
#
# Why this exists: `codex login status` and `codex doctor` only report the auth
# *mode* (api_key vs ChatGPT plan). ~/.codex/auth.json stores nothing but
# {auth_mode, OPENAI_API_KEY} — the owning org/project lives server-side only,
# so the account can be identified solely by making a call and reading the
# `openai-organization` / `openai-project` response headers.
#
# The trap this guards against: at runtime auth.json takes precedence over
# $OPENAI_API_KEY. Verified by running `codex exec` with a deliberately invalid
# OPENAI_API_KEY exported — the call still succeeded. The env var is consumed
# once, by `codex login --with-api-key`, and ignored thereafter. So exporting a
# different key does NOT move Codex to another account; only `codex logout` +
# re-login does. Hence this reads auth.json, never the environment.
{
  writeShellApplication,
  curl,
  jq,
  coreutils,
}:

writeShellApplication {
  name = "codex-whoami";

  runtimeInputs = [
    curl
    jq          # auth.json parsing; avoids a python3 dependency for two fields
    coreutils
  ];

  text = ''
    auth="''${CODEX_HOME:-$HOME/.codex}/auth.json"

    if [ ! -r "$auth" ]; then
      echo "codex-whoami: not logged in (no $auth)" >&2
      echo "  fix: printenv OPENAI_API_KEY | codex login --with-api-key" >&2
      exit 1
    fi

    mode=$(jq -r '.auth_mode // "unknown"' "$auth")
    key=$(jq -r '.OPENAI_API_KEY // ""' "$auth")

    echo "auth_mode: $mode"

    # ChatGPT-plan auth stores tokens instead of a key: usage is billed to the
    # signed-in ChatGPT account, so there is no API org/project to resolve.
    if [ -z "$key" ]; then
      echo "ChatGPT-plan auth — billed to the signed-in ChatGPT account, not API credits"
      exit 0
    fi

    echo "key      : ''${key:0:14}***''${key: -5}"

    # gpt-5-nano with a 256-token ceiling: the cheapest request that still comes
    # back 200. A lower ceiling 400s on reasoning models before any content is
    # emitted, which would hide the headers we are after.
    curl -sS -o /dev/null -D - https://api.openai.com/v1/chat/completions \
      -H "Authorization: Bearer $key" \
      -H "Content-Type: application/json" \
      -d '{"model":"gpt-5-nano","messages":[{"role":"user","content":"hi"}],"max_completion_tokens":256}' \
      | grep -iE '^HTTP/|^openai-organization|^openai-project' \
      | sed 's/^/  /'
  '';
}
