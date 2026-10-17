# claude-whoami: which Anthropic org/workspace Claude Code uses, via the free
# /v1/models response headers. Unlike Codex, an exported ANTHROPIC_API_KEY
# silently shadows the stored login, so this resolves from the environment.
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

  # `claude` not a runtimeInput: avoids a second claude-code closure.
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
