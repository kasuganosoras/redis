if Redis then return end

local Redis = {}
local isReady = false
local readyCallbacks = {}

local commandNames = {
    'del', 'exists', 'expire', 'expireat', 'keys', 'ttl', 'get', 'set', 'setex',
    'setnx', 'mget', 'mset', 'incr', 'decr', 'incrby', 'decrby', 'hget', 'hset',
    'hgetall', 'hdel', 'hkeys', 'hvals', 'hlen', 'hexists', 'hincrby', 'lpush',
    'rpush', 'lpop', 'rpop', 'lrange', 'llen', 'lindex', 'lrem', 'sadd', 'srem',
    'smembers', 'sismember', 'scard', 'spop', 'zadd', 'zrange', 'zrevrange',
    'zrem', 'zcard', 'zscore', 'zcount'
}

-- 兼容小驼峰语法
local aliasNames = {
    ['expireAt'] = 'expireat',
    ['hIncrBy'] = 'hincrby',
    ['hDel'] = 'hdel',
    ['hKeys'] = 'hkeys',
    ['hVals'] = 'hvals',
    ['hLen'] = 'hlen',
    ['sAdd'] = 'sadd',
    ['sRem'] = 'srem',
    ['sMembers'] = 'smembers',
    ['sIsMember'] = 'sismember',
    ['sCard'] = 'scard',
    ['sPop'] = 'spop',
    ['zAdd'] = 'zadd',
    ['zRange'] = 'zrange',
    ['zRevRange'] = 'zrevrange',
    ['zRem'] = 'zrem',
    ['zCard'] = 'zcard',
    ['zScore'] = 'zscore',
    ['zCount'] = 'zcount'
}

AddEventHandler('redis:ready', function()
    if isReady then return end
    isReady = true
    for _, cb in ipairs(readyCallbacks) do Citizen.CreateThread(cb) end
    readyCallbacks = {}
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == 'redis' then
        isReady = false
        print('^3[Redis]^7 Redis resource stopped.')
    end
end)

-- 构建 Redis 对象
Redis.Sync = {}
Redis.Async = {}

for _, command in ipairs(commandNames) do
    Redis.Sync[command] = function(...)
        local p = promise.new()
        local args = {...}

        exports.redis:execute(command, args, function(result, err)
            if err then return p:reject(err) end
            return p:resolve(result)
        end)

        return Citizen.Await(p)
    end

    Redis.Async[command] = function(...)
        local args = {...}
        local cb = table.remove(args) -- 从参数中分离出回调函数
        return exports.redis:execute(command, args, cb)
    end
end

-- 别名方法
for alias, command in pairs(aliasNames) do
    Redis.Sync[alias] = Redis.Sync[command]
    Redis.Async[alias] = Redis.Async[command]
end

-- 默认方法指向 Sync 版本
for key, func in pairs(Redis.Sync) do Redis[key] = func end

Redis.ready = function(cb)
    if type(cb) ~= 'function' then
        return error('^1[Redis]^0 Redis.ready(cb) expects a function.')
    end
    if isReady then
        Citizen.CreateThread(cb)
    else
        table.insert(readyCallbacks, cb)
    end
end

function Redis.pipeline()
    local pipeline = {
        _commands = {} -- 用于存储命令队列
    }

    -- 为管道对象动态添加所有 redis 命令方法
    for _, command in ipairs(commandNames) do
        pipeline[command] = function(self, ...)
            -- 当调用 pipeline:set(...) 时，不立即执行，而是将命令存入队列
            table.insert(self._commands, {command, ...})
            return self -- 返回 self 以实现链式调用
        end
    end

    -- 添加执行方法
    function pipeline:exec()
        local p = promise.new()
        if #self._commands == 0 then
            p:resolve({}) -- 如果没有命令，直接返回空 table
            return Citizen.Await(p)
        end
        -- 调用 JS 的 executePipeline，将整个命令队列传过去
        exports.redis:executePipeline(self._commands, function(results, err)
            if err then return p:reject(err) end
            p:resolve(results)
        end)
        return Citizen.Await(p)
    end

    -- 使用元表来使 pipeline:set() 和 pipeline.set() 都能工作
    return setmetatable(pipeline, { __index = pipeline })
end

-- 设置为全局变量
_ENV.Redis = Redis

exports('GetInstance', function() return Redis end)
