local M = {}

function M:entry()
	local child, err = Command("fzf")
		:stdin(Command.inherit())
		:stdout(Command.PIPED)
		:stderr(Command.inherit())
		:spawn()

	if not child then
		return ya.err(string.format("Failed to spawn fzf: %s", err))
	end

	local output = child:wait_with_output()
	if not output or not output.status.success then
		return
	end

	local target = output.stdout:gsub("\n$", "")
	if target ~= "" then
		ya.manager_emit("cd", { target })
	end
end

return M
