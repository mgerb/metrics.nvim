local metrics = require("metrics")

vim.api.nvim_create_user_command("MetricsDebug",
                                 function() metrics.print_branch_map() end, {})

vim.api.nvim_create_user_command("MetricsGetTime", function()
    -- write current buffers
    metrics.flush_time_tracking_buffer()

    -- query db for current branch time
    metrics.get_time_worked_for_current_branch_async(
        vim.schedule_wrap(function(branch_name, seconds_worked)
            if not seconds_worked then
                vim.notify("No time worked for current branch",
                           vim.log.levels.WARN)
                return
            end

            -- convert seconds to hours, minutes, seconds
            local hours = math.floor(seconds_worked / 3600)
            local minutes = math.floor((seconds_worked - (hours * 3600)) / 60)
            local seconds = math.floor(seconds_worked - (hours * 3600) -
                                           (minutes * 60))

            print("Branch: " .. branch_name .. ", Logged: " .. hours .. "h " ..
                      minutes .. "m " .. seconds .. "s")
        end))
end, {})

-- Start time tracking after 1 second.
-- This is done in case a plugin causes the working directory to change.
-- NOTE: The defer currently is not necessary because the database is
-- initialized after it starts tracking. This will be needed if the database
-- is initialized during startup though.
vim.defer_fn(function() metrics.start_time_tracking() end, 1000)
