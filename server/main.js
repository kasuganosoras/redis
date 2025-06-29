const Redis = require('ioredis');

let redisClient = null;
let subscriberClient = null;
let isConnected = false;
let isSubscriberConnected = false;
let readyStateSent = false;
const log = (message) => console.log(`^2[Redis]^7 ${message}`);
const error = (message) => console.error(`^1[Redis]^7 ${message}`);

function connectToRedis() {
    const connectionString = GetConvar('redis_connection_string', 'redis://localhost:6379');

    // 主客户端连接
    if (redisClient) {
        redisClient.quit();
        redisClient = null;
    }
    redisClient = new Redis(connectionString);

    redisClient.on('ready', () => {
        if (!isConnected) {
            isConnected = true;
            log('Redis connection established.');
            if (isSubscriberConnected) {
                if (!readyStateSent) {
                    readyStateSent = true;
                    emit('redis:ready');
                }
            }
        }
    });

    redisClient.on('end', () => { isConnected = false; log('Disconnected from Redis.'); });
    redisClient.on('error', (err) => error(`Client Error: ${err.message || err}`));

    // 订阅客户端连接
    if (subscriberClient) {
        subscriberClient.quit();
        subscriberClient = null;
    }
    subscriberClient = new Redis(connectionString);

    subscriberClient.on('ready', () => {
        if (!isSubscriberConnected) {
            isSubscriberConnected = true;
            log('Redis subscriber connection established.');
            if (isConnected) {
                if (!readyStateSent) {
                    readyStateSent = true;
                    emit('redis:ready');
                }
            }
        }
    });

    subscriberClient.on('message', (channel, message) => {
        // 尝试解析消息，如果是JSON格式则解析为对象
        let parsedMessage = message;
        try {
            // 检查消息是否是JSON格式
            if (message.startsWith('{') || message.startsWith('[')) {
                const parsed = JSON.parse(message);
                // 发送原始消息和解析后的消息
                emit('redis:message', channel, message, parsed);
                return;
            }
        } catch (e) {
            // 解析失败，忽略错误，使用原始消息
        }

        // 如果不是JSON或解析失败，发送原始消息
        emit('redis:message', channel, message, null);
    });

    subscriberClient.on('end', () => { isSubscriberConnected = false; log('Disconnected from Redis subscriber.'); });
    subscriberClient.on('error', (err) => error(`Subscriber Error: ${err.message || err}`));
}

exports('execute', (commandName, args, cb) => {
    // 检查参数类型
    if (typeof commandName !== 'string') { return cb(null, `[Redis] commandName must be a string, got ${typeof commandName}`); }
    if (typeof args !== 'object' || !Array.isArray(args)) { return cb(null, `[Redis] args must be an array, got ${typeof args}`); }
    if (typeof cb !== 'function') { return error(`[Redis] Internal error: callback not provided for ${commandName}`); }

    if (!isConnected) { return cb(null, 'Redis not connected'); }

    // 检查 redisClient 是否真的有这个命令
    if (typeof redisClient[commandName] !== 'function') {
        return cb(null, `[Redis] Unknown redis command: ${commandName}`);
    }

    // 使用 ioredis 执行命令
    try {
        // ioredis 的命令返回 Promise，需要添加回调处理
        redisClient[commandName](...args).then(reply => {
            return cb(reply, null);
        }).catch(err => {
            return cb(null, err.message);
        });
    } catch (e) {
        cb(null, `[Redis] Error applying command '${commandName}': ${e.message}`);
    }
});

exports('executePipeline', (commandList, cb) => {
    if (typeof commandList !== 'object' || !Array.isArray(commandList) || typeof cb !== 'function') {
        return error(`[Redis] Internal error: invalid arguments passed to 'executePipeline'`);
    }
    if (!isConnected) { return cb(null, 'Redis not connected'); }

    // 使用 ioredis 的 pipeline() 方法创建一个管道
    const pipeline = redisClient.pipeline();

    // 循环遍历从 Lua 发来的命令列表
    for (const command of commandList) {
        const commandName = command.shift(); // 第一个元素是命令名
        const args = command; // 剩下的是参数
        if (typeof pipeline[commandName] === 'function') {
            pipeline[commandName](...args); // 将命令添加到管道队列
        }
    }

    // 执行管道中的所有命令
    pipeline.exec((err, replies) => {
        if (err) {
            return cb(null, err.message);
        }
        const results = replies.map(reply => reply[1]);
        return cb(results, null);
    });
});

// 添加订阅相关方法
exports('subscribe', (channel, cb) => {
    if (!isSubscriberConnected) { return cb(null, 'Redis subscriber not connected'); }

    try {
        subscriberClient.subscribe(channel)
            .then(() => {
                return cb(true, null);
            })
            .catch(err => {
                return cb(null, err.message);
            });
    } catch (e) {
        cb(null, `[Redis] Error subscribing to channel '${channel}': ${e.message}`);
    }
});

// 批量订阅多个频道
exports('subscribeMulti', (channels, cb) => {
    if (!isSubscriberConnected) { return cb(null, 'Redis subscriber not connected'); }
    if (!Array.isArray(channels)) { return cb(null, '[Redis] channels must be an array'); }

    try {
        // 使用ioredis的multi命令批量订阅
        const multi = subscriberClient.multi();

        // 添加所有订阅命令
        for (const channel of channels) {
            multi.subscribe(channel);
        }

        // 执行批量订阅
        multi.exec((err, replies) => {
            if (err) {
                return cb(null, err.message);
            }
            // 检查是否有任何错误
            const hasError = replies.some(reply => reply[0]);
            if (hasError) {
                return cb(null, 'Error subscribing to one or more channels');
            }
            return cb(true, null);
        });
    } catch (e) {
        cb(null, `[Redis] Error subscribing to multiple channels: ${e.message}`);
    }
});

exports('unsubscribe', (channel, cb) => {
    if (!isSubscriberConnected) { return cb(null, 'Redis subscriber not connected'); }

    try {
        subscriberClient.unsubscribe(channel)
            .then(() => {
                return cb(true, null);
            })
            .catch(err => {
                return cb(null, err.message);
            });
    } catch (e) {
        cb(null, `[Redis] Error unsubscribing from channel '${channel}': ${e.message}`);
    }
});

exports('publish', (channel, message, cb) => {
    if (!isConnected) { return cb(null, 'Redis not connected'); }
    if (!cb) {
        cb = function (reply, err) {
            if (err) {
                console.error(`[Redis] Error publishing to channel '${channel}': ${err}`);
            }
        }
    }
    try {
        // 检查消息类型，如果不是字符串，尝试将其转换为JSON字符串
        let messageToSend = message;
        if (typeof message !== 'string') {
            try {
                messageToSend = JSON.stringify(message);
            } catch (jsonErr) {
                return cb(null, `[Redis] Error converting message to JSON: ${jsonErr.message}`);
            }
        }

        // ioredis的publish方法返回Promise
        redisClient.publish(channel, messageToSend)
            .then(reply => {
                return cb(reply, null); // reply 是接收到消息的客户端数量
            })
            .catch(err => {
                return cb(null, err.message);
            });
    } catch (e) {
        cb(null, `[Redis] Error publishing to channel '${channel}': ${e.message}`);
    }
});

// 批量发布消息到多个频道，使用pipeline提高性能
exports('publishMulti', (messages, cb) => {
    if (!isConnected) { return cb(null, 'Redis not connected'); }
    if (!Array.isArray(messages)) { return cb(null, '[Redis] messages must be an array'); }

    try {
        // 使用ioredis的pipeline创建管道
        const pipeline = redisClient.pipeline();

        // 处理每一条消息
        for (const item of messages) {
            if (!item.channel || item.message === undefined) {
                continue; // 跳过无效的消息
            }

            // 处理非字符串类型的消息
            let messageToSend = item.message;
            if (typeof item.message !== 'string') {
                try {
                    messageToSend = JSON.stringify(item.message);
                } catch (jsonErr) {
                    // 跳过无法序列化的消息
                    continue;
                }
            }

            // 添加到管道队列
            pipeline.publish(item.channel, messageToSend);
        }

        // 执行批量发布
        pipeline.exec((err, replies) => {
            if (err) {
                return cb(null, err.message);
            }
            const results = replies.map(reply => reply[1]);
            return cb(results, null);
        });
    } catch (e) {
        cb(null, `[Redis] Error publishing multiple messages: ${e.message}`);
    }
});

connectToRedis();