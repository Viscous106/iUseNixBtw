local M = {}

function M:setup(opts)
	self.update_db = opts.update_db
end

function M:entry()
	local path = ya.input({
		title = "Zoxide:",
		position = { "center", w = 60 },
	})
	if not path then
		return
	end

	local child, err = Command("zoxide")
		:args({ "query", path })
		:stdout(Command.PIPED)
		:spawn()

	if not child then
		return ya.err(string.format("Failed to spawn zoxide: %s", err))
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
