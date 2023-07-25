local Job = require("plenary.job")
local util = require("metrics.util")

local M = {}

local branch_map = {}
local check_timer_interval = 1000 * 60 -- 1 minute milliseconds
local branch_idol_time = 60 -- 1 minute in seconds
local current_branch = nil

local function check_interval(force)
	for branch_name, branch_info in pairs(branch_map) do
		local current_time = os.time()
		local time_diff = current_time - branch_info.end_time

		if time_diff > branch_idol_time or force then
			-- create database tables if they don't exist
			M.init_db()

			local start_time_utc = os.date("!%Y-%m-%d %H:%M:%S", branch_info.start_time)
			local end_time_utc = os.date("!%Y-%m-%d %H:%M:%S", branch_info.end_time)

			local query = [[
                INSERT INTO time_tracking (branch, start_time, end_time)
                VALUES (']] .. branch_name .. [[', ']] .. start_time_utc .. [[', ']] .. end_time_utc .. [[')
            ]]

			Job:new({
				command = "sqlite3",
				args = { M.get_db_path(), query },
				on_exit = function(_result, return_val)
					if return_val == 0 then
						branch_map[branch_name] = nil
					end
				end,
				on_stderr = function(err, data)
					print("ON STDERR", vim.inspect(err), vim.inspect(data))
				end,
			}):sync()
		end
	end
end

function M.setup(config)
	local default_config = { db_filename = "metrics.db" }
	M.config = vim.tbl_extend("keep", default_config, config or {})
end

M.get_db_path = function()
	return vim.fn.getcwd() .. "/" .. M.config.db_filename
end

function M.flush_time_tracking_buffer()
	check_interval(true)
end

function M.start_time_tracking()
	-- capture the current ticket from the branch name on an event that is fired often enough to
	-- pick up a change in branch, but not so often that it's a performance hit
	vim.api.nvim_create_autocmd("BufEnter", {
		group = vim.api.nvim_create_augroup("MetricsTimeTrackingBufEnter", { clear = true }),
		callback = function()
			current_branch = util.get_current_branch_name()
		end,
	})

	-- whenever the cursor is moved, capture or update the time tracking for the current ticket
	vim.api.nvim_create_autocmd("CursorMoved", {
		group = vim.api.nvim_create_augroup("MetricsTimeTracking", { clear = true }),
		callback = function()
			local branch_name = current_branch

			if not branch_name then
				return
			end

			local current_time = os.time()

			if not branch_map[branch_name] then
				branch_map[branch_name] = {
					start_time = current_time,
					end_time = current_time,
				}
			end

			branch_map[branch_name].end_time = current_time
		end,
	})

	-- when vim exits, flush the time tracking
	vim.api.nvim_create_autocmd("VimLeave", {
		group = vim.api.nvim_create_augroup("MetricsTimeTrackingVimLeave", { clear = true }),
		callback = function()
			-- force flushing of time tracking before exit
			check_interval(true)
		end,
	})

	local timer = vim.loop.new_timer()
	timer:start(
		0,
		check_timer_interval,
		vim.schedule_wrap(function()
			check_interval(false)
		end)
	)
end

function M.init_db()
	local create_time_tracking_table = [[
            create table if not exists
            time_tracking
            (id integer primary key autoincrement, branch text, start_time text, end_time text);
        ]]

	Job:new({
		command = "sqlite3",
		args = { M.get_db_path(), create_time_tracking_table },
		on_exit = function(_j, _return_val) end,
		on_stdout = function(_j, data)
			print("on_stdout", data)
		end,
		on_stderr = function(_j, data)
			print("on_stderr", data)
		end,
	}):start()
end

function M.get_time_worked_for_current_branch_async(callback)
	local branch_name = util.get_current_branch_name()

	if not branch_name then
		print("Not in a valid git repository.")
		return
	end

	local query_by_branch_name = [[
         SELECT branch, SUM(strftime('%s', end_time) - strftime('%s', start_time))  AS total_time_seconds
         from time_tracking
         WHERE branch = "]] .. branch_name .. [["
         GROUP BY branch
     ]]

	Job:new({
		command = "sqlite3",
		args = { M.get_db_path(), query_by_branch_name },
		on_exit = function(j, _return_val)
			local result = j:result()
			if #result == 0 then
				callback(nil)
			end
			for _, row in ipairs(result) do
				local row_split = vim.split(row, "|")
				callback(branch_name, tonumber(row_split[2]))
			end
		end,
		on_stdout = function(_j, data)
			print("on_stdout", data)
		end,
		on_stderr = function(_j, data)
			print("on_stderr", data)
		end,
	}):start()
end

function M.print_branch_map()
	print(vim.inspect(branch_map))
end

return M
