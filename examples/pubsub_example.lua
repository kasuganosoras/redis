-- Redis Pub/Sub 功能示例

-- 注册一个命令来订阅频道
RegisterCommand('redis_subscribe', function(source, args)
    local channel = args[1]
    
    if not channel then
        print('Usage: /redis_subscribe [channel]')
        return
    end
    
    exports.redis:subscribe(channel, function(success, err)
        if err then
            print('Failed to subscribe: ' .. err)
        else
            print('Subscribe successfuel: ' .. channel)
        end
    end)
end, false)

-- 注册一个命令来批量订阅多个频道
RegisterCommand('redis_subscribe_multi', function(source, args)
    if #args == 0 then
        print('Usage: /redis_subscribe_multi [channel1] [channel2] [channel3] ...')
        return
    end
    
    exports.redis:subscribeMulti(args, function(success, err)
        if err then
            print('Failed to subscribe multi: ' .. err)
        else
            print('Subscribe multi successfuel:')
            for i, channel in ipairs(args) do
                print('- ' .. channel)
            end
        end
    end)
end, false)

-- 取消订阅频道示例
RegisterCommand('redis_unsubscribe', function(source, args)
    if #args < 1 then
        print('Usage: /redis_unsubscribe [channel]')
        return
    end
    
    local channel = args[1]
    exports.redis:unsubscribe(channel, function(success, err)
        if err then
            print('Unsubscribe failed: ' .. err)
        else
            print('Unsubscribed from channel: ' .. channel)
        end
    end)
end, false)

-- 注册一个命令来发布消息
RegisterCommand('redis_publish', function(source, args)
    local channel = args[1]
    local message = args[2]
    
    if not channel or not message then
        print('Usage: /redis_publish [channel] [message]')
        return
    end
    
    exports.redis:publish(channel, message, function(reply, err)
        if err then
            print('Publish failed: ' .. err)
        else
            print('Message published to ' .. channel .. ', ' .. reply .. ' recipients received message')
        end
    end)
end, false)

-- 注册一个命令来批量发布消息
RegisterCommand('redis_publish_multi', function(source, args)
    if #args < 2 then
        print('Usage: /redis_publish_multi [channel1] [message1] [channel2] [message2] ...')
        return
    end
    
    local messages = {}
    for i = 1, #args, 2 do
        if args[i] and args[i+1] then
            table.insert(messages, {channel = args[i], message = args[i+1]})
        end
    end
    
    if #messages == 0 then
        print('No message to publish')
        return
    end
    
    exports.redis:publishMulti(messages, function(replies, err)
        if err then
            print('Failed to publish multi: ' .. err)
        else
            print('Publish multi successfuel:')
            for i, reply in ipairs(replies) do
                print('Message #' .. i .. ' published to ' .. messages[i].channel .. ', ' .. reply .. ' recipients received message')
            end
        end
    end)
end, false)

-- 发布表格数据示例
RegisterCommand('redis_publish_table', function(source, args)
    if #args < 1 then
        print('Usage: /redis_publish_table [channel]')
        return
    end
    
    local channel = args[1]
    -- 创建一个示例表格
    local tableData = {
        id = 1234,
        name = "Test Data",
        items = {"Item 1", "Item 2", "Item 3"},
        metadata = {
            created = os.time(),
            author = "System"
        }
    }
    
    exports.redis:publish(channel, tableData, function(recipients, err)
        if err then
            print('Publish table data failed: ' .. err)
        else
            print('Table data published to channel ' .. channel .. ', ' .. recipients .. ' recipients received message')
        end
    end)
end, false)

-- 监听来自Redis的消息
AddEventHandler('redis:message', function(channel, message, parsedData)
    print('Message received from channel ' .. channel .. ': ' .. message)
    
    -- 如果收到的是JSON数据（表格）
    if parsedData then
        print('Received JSON data, parsed:')
        -- 打印表格内容
        local function printTable(t, indent)
            indent = indent or ''
            for k, v in pairs(t) do
                if type(v) == 'table' then
                    print(indent .. k .. ' = {')
                    printTable(v, indent .. '    ')
                    print(indent .. '}')
                else
                    print(indent .. k .. ' = ' .. tostring(v))
                end
            end
        end
        
        printTable(parsedData)
        
        -- 可以直接使用解析后的表格数据
        if parsedData.id then
            print('Data ID: ' .. parsedData.id)
        end
        
        -- 触发事件时同时传递原始消息和解析后的数据
        TriggerEvent('custom:event', channel, message, parsedData)
    else
        -- 普通字符串消息
        TriggerEvent('custom:event', channel, message)
    end
end)

-- 监听Redis连接就绪事件
AddEventHandler('redis:ready', function()
    print('Redis connection ready, Pub/Sub example loaded')
    -- 可以在这里自动订阅一些频道
    -- exports.redis:subscribe('news', function() end)
    -- exports.redis:subscribe('updates', function() end)
end)

print('Redis Pub/Sub example is running')