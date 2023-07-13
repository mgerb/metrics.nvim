# metrics.nvim

- tracks time spent in your editor
- logs locally to sqlite3 database

## Requirements

- sqlite3

## Commands

- `MetricsDebug` - prints out some debug information for current time tracking session
- `MetricsGetTime` - prints out total time spent on your current branch

## Installing

### Packer

```lua
use("mgerb/metrics.nvim")
```

## Setup

```lua
local metrics = require("metrics")

local config = {}

metrics.setup(config)
```

### Default Config

```lua
{
    db_filename = 'metrics.db'
}
```

## Credits

Thanks, @justinrassier, for writing most of this code!
