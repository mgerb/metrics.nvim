local Job = require("plenary.job")

local M = {}

M.get_current_branch_name = function()
	if not M.is_valid_git_repo() then
		return nil
	end

	local branch_name = vim.fn.system("git branch --show-current")

	-- trim branch_name
	branch_name = string.gsub(branch_name, "\n", "")
	return branch_name
end

M.is_valid_git_repo = function()
	local valid = false
	Job:new({
		command = "git",
		args = { "status" },
		on_exit = function(_result, return_val)
			if return_val ~= 0 then
				valid = false
			else
				valid = true
			end
		end,
	}):sync()

	return valid
end

return M
