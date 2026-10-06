// opencode -> tmux agent state.
//
// opencode is the one agent of the four that has no hooks.json: it wants a
// TypeScript plugin, loaded from ~/.config/opencode/plugin/. Everything it does
// is hand off to home/tmux/scripts/agent-state.sh, so the state machine lives
// in exactly one place.
//
// Event names below were confirmed against the shipped opencode binary
// (1.18.21), not docs.
//
// LIMITATION: the pane is taken from $TMUX_PANE in the opencode process. That
// is correct for the normal `opencode` TUI, whose server is a child of the pane
// you launched it in. It is NOT correct for `opencode attach`, where the server
// belongs to some other pane -- in that case TMUX_PANE either is missing (we
// no-op) or points at the server's pane, not yours.

const SCRIPT = `${process.env.HOME}/.config/tmux/scripts/agent-state.sh`;

export const AgentState = async () => {
  const pane = process.env.TMUX_PANE;

  // Not inside tmux -- load the plugin but do nothing.
  if (!pane) return {};

  const set = (state: string) => {
    try {
      // Explicit argv, and TMUX_PANE forced into the child env rather than
      // inherited, so this keeps working if opencode ever sanitises env.
      Bun.spawn([SCRIPT, "set", state], {
        env: { ...process.env, TMUX_PANE: pane },
        stdout: "ignore",
        stderr: "ignore",
      });
    } catch {
      // A status chip is never worth breaking the agent over.
    }
  };

  return {
    event: async ({ event }: { event: { type: string } }) => {
      switch (event.type) {
        case "permission.asked":
          set("blocked");
          break;
        // Answering a permission prompt puts it straight back to work; waiting
        // for the next session.idle would leave a stale red chip.
        case "permission.replied":
          set("working");
          break;
        case "session.idle":
          set("done");
          break;
      }
    },

    "chat.message": async () => {
      set("working");
    },
  };
};
