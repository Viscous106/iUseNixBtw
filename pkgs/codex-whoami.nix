# codex-whoami: OpenAI org/project Codex bills, from API response headers. Uses auth.json, since
# Codex ignores $OPENAI_API_KEY after `codex login` (only logout + re-login switches).
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
    jq
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

    # Cheapest request that returns 200: a lower token ceiling 400s on reasoning models, hiding the headers.
    curl -sS -o /dev/null -D - https://api.openai.com/v1/chat/completions \
      -H "Authorization: Bearer $key" \
      -H "Content-Type: application/json" \
      -d '{"model":"gpt-5-nano","messages":[{"role":"user","content":"hi"}],"max_completion_tokens":256}' \
      | grep -iE '^HTTP/|^openai-organization|^openai-project' \
      | sed 's/^/  /'
  '';
}
