# FiveM Redis

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![FiveM](https://img.shields.io/badge/framework-FiveM-orange.svg)
![Language](https://img.shields.io/badge/language-Lua%20%2B%20JS-yellow.svg)

一个为 FiveM 服务器设计的、高性能、API 友好的 Redis 支持库。它采用与 `oxmysql` 类似的设计哲学，通过文件包含的方式，为您的 Lua 脚本提供一个简单、稳定、看似同步的 Redis 操作接口。

这个库同时支持逐条命令执行和高性能的 **Pipeline（管道）** 模式，以满足不同场景下的性能需求。

## 目录

- [特性](#特性)
- [安装](#安装)
- [使用方法](#使用方法)
  - [逐条命令 (标准用法)](#逐条命令-标准用法)
  - [Pipeline 模式 (高性能批量操作)](#pipeline-模式-高性能批量操作)
- [支持的命令](#支持的命令)
- [许可](#许可)

## 特性

- **`oxmysql` 风格的 API**: 无需处理复杂的导出函数，像使用 `oxmysql` 一样，通过包含库文件即可在脚本中获得全局的 `Redis` 对象。
- **同步调用体验**: 您可以像编写同步代码一样执行 Redis 操作 (`local value = Redis.get('key')`)，而不会阻塞服务器主线程。
- **高性能 Pipeline 模式**: 支持将大量命令打包一次性发送，极大减少网络延迟，使批量操作性能提升数十倍。
- **全面的命令支持**: 支持绝大部分常用的 Redis 命令，涵盖字符串、哈希、列表、集合等。
- **稳定的架构**: 采用 JS 后端 + Lua 前端的模式，通过回调函数进行内部通信，避免了 FiveM 中复杂的跨语言调用问题。
- **`Redis.ready()`**: 提供 `ready` 回调函数，确保您的业务逻辑在 Redis 连接成功后才执行，保证代码的健壮性。

## 安装

1.  **下载资源**: 将该项目下载或克隆到您的服务器 `resources` 文件夹中，并确保资源名为 `redis`。

2.  **安装依赖**:
    -   如果您的服务器有权访问互联网，只需确保 `[redis]` 资源在 `server.cfg` 中被 `ensure`。服务器启动时，它会自动下载 `package.json` 中定义的 `redis@3` 依赖库。
    -   如果服务器无法访问互联网，请在本地有 Node.js 环境的电脑上，进入 `[redis]` 文件夹，运行 `npm install`，然后将整个 `[redis]` 文件夹（包含 `node_modules`）上传到服务器。

3.  **配置连接**: 打开您的 `server.cfg` 文件，添加 Redis 连接字符串。

    ```cfg
    # --- Redis Configuration ---
    # 格式: redis://[user:password@]host[:port][/db-number]
    # 示例 (无密码): set redis_connection_string "redis://127.0.0.1:6379"
    # 示例 (有密码): set redis_connection_string "redis://:your_password@127.0.0.1:6379"
    set redis_connection_string "redis://127.0.0.1:6379"

    # 确保 redis 资源启动
    ensure redis
    ```

## 使用方法

### 逐条命令 (标准用法)

这是最常用、最直观的使用方式，适用于绝大多数日常的单次读写操作。

#### 1. 在您资源的 `fxmanifest.lua` 中引入库

确保 `@redis/libs/Redis.lua` 在您自己的服务器脚本**之前**被加载。

```lua
-- 在你的资源 [my_script] 的 fxmanifest.lua 中
server_scripts {
    '@redis/libs/Redis.lua', -- <--- 首先加载 Redis 库
    'server/main.lua'        -- <--- 然后加载您自己的脚本
}
```

#### 2. 在您的 Lua 脚本中直接使用

```lua
-- 在 [my_script]/server/main.lua 中

-- 使用 Redis.ready 是最佳实践，确保所有操作都在连接成功后执行
Redis.ready(function()
    print('^^2[MyScript] Redis is ready!^^7')

    -- 同步获取/设置一个值
    local serverName = Redis.get('server:name')
    if not serverName then
        print('Server name not found, setting a new one.')
        Redis.set('server:name', 'My Awesome FiveM Server')
    end
    print('Server name from Redis: ' .. Redis.get('server:name'))

    -- 使用哈希 (Hash) 存储玩家数据
    local playerKey = 'player:steam:110000100000001'
    Redis.hset(playerKey, 'name', 'John Doe', 'cash', 5000)
    local playerData = Redis.hgetall(playerKey)
    print('Player data: ' .. json.encode(playerData))
end)
```

### Pipeline 模式 (高性能批量操作)

当您需要一次性执行大量命令时（例如，批量读取上百个玩家的数据、或进行性能测试），`pipeline` 是您的不二之选。它能将所有命令打包一次性发送，极大提升性能。

#### 用法示例

```lua
Redis.ready(function()
    -- 1. 创建一个 pipeline 对象
    local pipeline = Redis.pipeline()

    -- 2. 向 pipeline 添加命令（这不会产生任何网络请求）
    -- 支持链式调用
    pipeline:set('bulk:user:1', 'data1')
            :set('bulk:user:2', 'data2')
            :incr('server:login_count')
            :get('bulk:user:1')
            :get('bulk:user:2')

    -- 3. 调用 exec()，一次性发送所有命令并等待所有结果返回
    local results = pipeline:exec()

    -- `results` 是一个 table，包含了所有命令的返回值，顺序与添加顺序一致
    -- results 的内容将会是:
    -- {
    --   'OK',                               -- set 命令的返回值
    --   'OK',                               -- set 命令的返回值
    --   1234,                               -- incr 命令执行后的新值
    --   'data1',                            -- get 命令的返回值
    --   'data2'                             -- get 命令的返回值
    -- }
    print('Pipeline executed. Results: ' .. json.encode(results))


    -- 性能测试示例
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
        print('耗时：' .. (endTime - start) .. 'ms') -- 耗时通常在 100ms 以内
        print('收到的响应数量: ' .. #replies)
    end, false)
end)
```

## 支持的命令

所有命令都支持同步风格调用 (`Redis.get`) 和 `pipeline` 调用 (`pipeline:get`)。

#### 通用命令 (Generic)
- `del`, `exists`, `expire`, `expireat`, `keys`, `ttl`

#### 字符串 (String)
- `get`, `set`, `setex`, `setnx`, `mget`, `mset`, `incr`, `decr`, `incrby`, `decrby`

#### 哈希 (Hash)
- `hget`, `hset`, `hgetall`, `hdel`, `hkeys`, `hvals`, `hlen`, `hexists`, `hincrby`

#### 列表 (List)
- `lpush`, `rpush`, `lpop`, `rpop`, `lrange`, `llen`, `lindex`, `lrem`

#### 集合 (Set)
- `sadd`, `srem`, `smembers`, `sismember`, `scard`, `spop`

#### 有序集合 (Sorted Set)
- `zadd`, `zrange`, `zrevrange`, `zrem`, `zcard`, `zscore`, `zcount`

## 许可

本项目采用 MIT 许可。

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