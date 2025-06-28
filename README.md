# FiveM Redis

A high-performance, API-friendly Redis library designed for FiveM servers. It adopts a design philosophy similar to `oxmysql`, providing a simple, stable, and seemingly synchronous Redis operation interface for your Lua scripts through file inclusion.

This library supports both per-command execution and a high-performance **Pipeline** mode to meet the performance needs of different scenarios.

## Table of Contents

  - [Features](https://www.google.com/search?q=%23features)
  - [Installation](https://www.google.com/search?q=%23installation)
  - [Usage](https://www.google.com/search?q=%23usage)
      - [Per-Command (Standard Usage)](https://www.google.com/search?q=%23per-command-standard-usage)
      - [Pipeline Mode (High-Performance Bulk Operations)](https://www.google.com/search?q=%23pipeline-mode-high-performance-bulk-operations)
  - [Supported Commands](https://www.google.com/search?q=%23supported-commands)
  - [License](https://www.google.com/search?q=%23license)

## Features

  - **`oxmysql`-style API**: No need to deal with complex export functions. Like `oxmysql`, you get a global `Redis` object in your script simply by including the library file.
  - **Synchronous-like Experience**: You can execute Redis operations as if you were writing synchronous code (`local value = Redis.get('key')`) without blocking the server's main thread.
  - **High-Performance Pipeline Mode**: Supports batching a large number of commands to be sent at once, significantly reducing network latency and boosting the performance of bulk operations by tens of times.
  - **Comprehensive Command Support**: Supports most commonly used Redis commands, covering Strings, Hashes, Lists, Sets, etc.
  - **Stable Architecture**: Uses a JS backend + Lua frontend architecture, communicating internally through callbacks, avoiding the complex cross-language invocation issues in FiveM.
  - **`Redis.ready()`**: Provides a `ready` callback function to ensure your business logic executes only after the Redis connection is successfully established, guaranteeing code robustness.

## Installation

1.  **Download the Resource**: Download or clone this project into your server's `resources` folder and ensure the resource name is `redis`.

2.  **Install Dependencies**:

      - If your server has internet access, simply `ensure` the `[redis]` resource in your `server.cfg`. It will automatically download the `redis@3` dependency defined in `package.json` when the server starts.
      - If your server does not have internet access, go to the `[redis]` folder on a computer with a Node.js environment, run `npm install`, and then upload the entire `[redis]` folder (including `node_modules`) to your server.

3.  **Configure the Connection**: Open your `server.cfg` file and add the Redis connection string.

    ```cfg
    # --- Redis Configuration ---
    # Format: redis://[user:password@]host[:port][/db-number]
    # Example (no password): set redis_connection_string "redis://127.0.0.1:6379"
    # Example (with password): set redis_connection_string "redis://:your_password@127.0.0.1:6379"
    set redis_connection_string "redis://127.0.0.1:6379"

    # Ensure the redis resource is started
    ensure redis
    ```

## Usage

### Per-Command (Standard Usage)

This is the most common and intuitive way to use the library, suitable for most everyday single read/write operations.

#### 1\. Include the library in your resource's `fxmanifest.lua`

Ensure that `@redis/libs/Redis.lua` is loaded **before** your own server scripts.

```lua
-- In your resource's [my_script] fxmanifest.lua
server_scripts {
    '@redis/libs/Redis.lua', -- <--- Load the Redis library first
    'server/main.lua'        -- <--- Then load your own script
}
```

#### 2\. Use it directly in your Lua script

```lua
-- In [my_script]/server/main.lua

-- Using Redis.ready is best practice to ensure all operations run after the connection is successful
Redis.ready(function()
    print('^^2[MyScript] Redis is ready!^^7')

    -- Synchronously get/set a value
    local serverName = Redis.get('server:name')
    if not serverName then
        print('Server name not found, setting a new one.')
        Redis.set('server:name', 'My Awesome FiveM Server')
    end
    print('Server name from Redis: ' .. Redis.get('server:name'))

    -- Use a Hash to store player data
    local playerKey = 'player:steam:110000100000001'
    Redis.hset(playerKey, 'name', 'John Doe', 'cash', 5000)
    local playerData = Redis.hgetall(playerKey)
    print('Player data: ' .. json.encode(playerData))
end)
```

### Pipeline Mode (High-Performance Bulk Operations)

When you need to execute a large number of commands at once (e.g., bulk reading data for hundreds of players, or for performance testing), `pipeline` is your best choice. It bundles all commands to be sent in a single trip, drastically improving performance.

#### Usage Example

```lua
Redis.ready(function()
    -- 1. Create a pipeline object
    local pipeline = Redis.pipeline()

    -- 2. Add commands to the pipeline (this generates no network requests)
    -- Chaining is supported
    pipeline:set('bulk:user:1', 'data1')
            :set('bulk:user:2', 'data2')
            :incr('server:login_count')
            :get('bulk:user:1')
            :get('bulk:user:2')

    -- 3. Call exec() to send all commands at once and wait for all results
    local results = pipeline:exec()

    -- `results` is a table containing the return values of all commands, in the order they were added
    -- The content of results will be:
    -- {
    --   'OK',                               -- return value for the set command
    --   'OK',                               -- return value for the set command
    --   1234,                               -- the new value after the incr command
    --   'data1',                            -- return value for the get command
    --   'data2'                             -- return value for the get command
    -- }
    print('Pipeline executed. Results: ' .. json.encode(results))


    -- Performance test example
    RegisterCommand('redisbenchmark_pipeline', function()
        print('^^2Starting pipeline benchmark...^^7')
        local start = GetGameTimer()

        local p = Redis.pipeline()
        for i = 1, 10000 do
            p:get('benchmark_test')
        end
        local replies = p:exec()

        local endTime = GetGameTimer()
        print('^^2Pipeline benchmark for 10,000 GETs finished!^^7')
        print('Time taken: ' .. (endTime - start) .. 'ms') -- Usually under 100ms
        print('Number of replies received: ' .. #replies)
    end, false)
end)
```

## Supported Commands

All commands support both synchronous-style calls (`Redis.get`) and pipeline calls (`pipeline:get`).

#### Generic

  - `del`, `exists`, `expire`, `expireat`, `keys`, `ttl`

#### String

  - `get`, `set`, `setex`, `setnx`, `mget`, `mset`, `incr`, `decr`, `incrby`, `decrby`

#### Hash

  - `hget`, `hset`, `hgetall`, `hdel`, `hkeys`, `hvals`, `hlen`, `hexists`, `hincrby`

#### List

  - `lpush`, `rpush`, `lpop`, `rpop`, `lrange`, `llen`, `lindex`, `lrem`

#### Set

  - `sadd`, `srem`, `smembers`, `sismember`, `scard`, `spop`

#### Sorted Set

  - `zadd`, `zrange`, `zrevrange`, `zrem`, `zcard`, `zscore`, `zcount`

## License

This project is licensed under the MIT License.

```text
MIT License

Copyright (c) 2025 [Your Name or Project Name]

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```