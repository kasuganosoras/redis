if Redis then return end

local Redis = {}
local isReady = false
local readyCallbacks = {}

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

-- 创建元表来处理任意命令
local syncMt = {
    __index = function(t, command)
        -- 检查是否是别名
        local actualCommand = aliasNames[command] or command
        
        -- 创建对应的函数
        local fn = function(...)
            local p = promise.new()
            local args = {...}

            exports.redis:execute(actualCommand, args, function(result, err)
                if err then return p:reject(err) end
                return p:resolve(result)
            end)

            return Citizen.Await(p)
        end
        
        -- 缓存这个函数以便下次直接使用
        t[command] = fn
        return fn
    end
}

local asyncMt = {
    __index = function(t, command)
        -- 检查是否是别名
        local actualCommand = aliasNames[command] or command
        
        -- 创建对应的函数
        local fn = function(...)
            local args = {...}
            local cb = table.remove(args) -- 从参数中分离出回调函数
            return exports.redis:execute(actualCommand, args, cb)
        end
        
        -- 缓存这个函数以便下次直接使用
        t[command] = fn
        return fn
    end
}

-- 应用元表
setmetatable(Redis.Sync, syncMt)
setmetatable(Redis.Async, asyncMt)

-- 为Redis对象创建元表，使其可以直接调用任意命令（默认指向Sync版本）
local redisMt = {
    __index = function(t, command)
        -- 直接从Sync获取或创建方法
        return Redis.Sync[command]
    end
}

-- 应用元表到Redis对象
setmetatable(Redis, redisMt)

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

    -- 使用元表来支持任意命令
    local pipelineMt = {
        __index = function(t, command)
            -- 检查是否是别名
            local actualCommand = aliasNames[command] or command
            
            -- 创建对应的函数
            local fn = function(self, ...)
                -- 当调用 pipeline:command(...) 时，不立即执行，而是将命令存入队列
                table.insert(self._commands, {actualCommand, ...})
                return self -- 返回 self 以实现链式调用
            end
            
            -- 缓存这个函数以便下次直接使用
            t[command] = fn
            return fn
        end
    }
    
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

    -- 应用元表 - 只应用一次元表
    return setmetatable(pipeline, pipelineMt)
end

-- 设置为全局变量
_ENV.Redis = Redis

exports('GetInstance', function() return Redis end)
