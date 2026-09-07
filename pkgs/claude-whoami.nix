# ── claude-whoami ───────────────────────────────────────────────────────────
# Reports which Anthropic org/workspace Claude Code is actually talking to.
# Companion to pkgs/codex-whoami.nix — same question, but the two CLIs resolve
# credentials in OPPOSITE directions, which is the whole reason both exist:
#
#   codex   auth.json WINS; $OPENAI_API_KEY is read only by `codex login` and
#           ignored at runtime. Exporting a different key changes nothing.
#   claude  the ENVIRONMENT wins; a stale exported ANTHROPIC_API_KEY silently
#           shadows the stored login and sends requests to whatever org that
#           key belongs to. `claude auth status` reports it as `apiKeySource`.
#
# Unlike the OpenAI side, identity comes back on a FREE endpoint: /v1/models
# returns `anthropic-organization-id` and `anthropic-workspace-id` headers, so
# this costs nothing to run (codex-whoami must make a billed call).
#
# Note this box authenticates via CLAUDE_CODE_OAUTH_TOKEN (an `sk-ant-oat01…`
# OAuth token from /persist/secrets/claude_api), not an `sk-ant-api03…` API
# key — the two take different auth headers, hence the branching below.
{
  writeShellApplication,
  curl,
  jq,
  coreutils,
}:

writeShellApplication {
  name = "claude-whoami";

  runtimeInputs = [
    curl
    jq
    coreutils
  ];

  # `claude` is deliberately NOT a runtimeInput: it lives in home.packages and
  # pinning it here would drag a second claude-code closure into the store just
  # to read four JSON fields. Degrade gracefully when it is not on PATH.
  text = ''
    if command -v claude >/dev/null 2>&1; then
      echo "── claude auth status ──"
      # `claude auth status` exits 1 when not logged in but still prints valid,
      # useful JSON — so never gate on its exit code (the Anthropic CLI docs say
      # as much: it reports status, it is not a health check). Capture the
      # output unconditionally and decide based on whether it parses.
      status=$(claude auth status 2>/dev/null || true)
      if [ -n "$status" ] && echo "$status" | jq -e . >/dev/null 2>&1; then
        echo "$status" | jq -r '
          "logged in : \(.loggedIn)",
          "method    : \(.authMethod)",
          "provider  : \(.apiProvider)",
          (if .apiKeySource then
             "⚠ api key : \(.apiKeySource) is set and SHADOWS the stored login"
           else empty end)'
      else
        echo "  (no parseable output from 'claude auth status')"
      fi
      echo
    fi

    # Documented resolution order (first match wins), per the Anthropic SDK/CLI
    # contract: ANTHROPIC_API_KEY → ANTHROPIC_AUTH_TOKEN → OAuth token/profile.
    # An EMPTY ANTHROPIC_API_KEY still wins its slot and authenticates as empty,
    # so test with -n, not merely "is it defined".
    if [ -n "''${ANTHROPIC_API_KEY:-}" ]; then
      src="ANTHROPIC_API_KEY"; cred="$ANTHROPIC_API_KEY"
      auth_args=(-H "x-api-key: $cred")
    elif [ -n "''${ANTHROPIC_AUTH_TOKEN:-}" ]; then
      src="ANTHROPIC_AUTH_TOKEN"; cred="$ANTHROPIC_AUTH_TOKEN"
      auth_args=(-H "Authorization: Bearer $cred")
    elif [ -n "''${CLAUDE_CODE_OAUTH_TOKEN:-}" ]; then
      src="CLAUDE_CODE_OAUTH_TOKEN"; cred="$CLAUDE_CODE_OAUTH_TOKEN"
      auth_args=(-H "Authorization: Bearer $cred" -H "anthropic-beta: oauth-2025-04-20")
    else
      echo "no Anthropic credential in the environment." >&2
      echo "  Claude Code may still be logged in via its own stored credential," >&2
      echo "  which this cannot read — see 'claude auth status' above." >&2
      echo "  For an env credential: source /persist/secrets/claude_api" >&2
      exit 1
    fi

    echo "── resolved credential ──"
    echo "source    : $src"
    echo "token     : ''${cred:0:14}***''${cred: -5}"
    echo

    echo "── org (GET /v1/models — free, no tokens billed) ──"
    curl -sS -o /dev/null -D - https://api.anthropic.com/v1/models \
      "''${auth_args[@]}" \
      -H "anthropic-version: 2023-06-01" \
      | grep -iE '^HTTP/|^anthropic-organization-id|^anthropic-workspace-id' \
      | sed 's/^/  /'
  '';
}
