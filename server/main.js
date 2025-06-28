const redis = require('redis');

let redisClient = null;
let isConnected = false;
const log = (message) => console.log(`^2[Redis]^7 ${message}`);
const error = (message) => console.error(`^1[Redis]^7 ${message}`);

function connectToRedis() {
    const connectionString = GetConvar('redis_connection_string', 'redis://localhost:6379');
    if (redisClient) {
        redisClient.quit();
        redisClient = null;
    }
    redisClient = redis.createClient(connectionString);

    redisClient.on('ready', () => {
        if (!isConnected) {
            isConnected = true;
            log('Redis connection established.');
            emit('redis:ready');
        }
    });

    redisClient.on('end', () => { isConnected = false; log('Disconnected from Redis.'); });
    redisClient.on('error', (err) => error(`Client Error: ${err.message || err}`));
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

    const nodeRedisCallback = (err, reply) => {
        if (err) {
            return cb(null, err.message);
        }
        return cb(reply, null);
    };

    // 将回调函数添加到参数数组的末尾
    const finalArgs = args.concat(nodeRedisCallback);

    // 使用 .apply() 安全地调用命令
    try {
        redisClient[commandName].apply(redisClient, finalArgs);
    } catch (e) {
        cb(null, `[Redis] Error applying command '${commandName}': ${e.message}`);
    }
});

exports('executePipeline', (commandList, cb) => {
    if (typeof commandList !== 'object' || !Array.isArray(commandList) || typeof cb !== 'function') {
        return error(`[Redis] Internal error: invalid arguments passed to 'executePipeline'`);
    }
    if (!isConnected) { return cb(null, 'Redis not connected'); }

    // 使用 redis@3 的 batch() 方法创建一个管道
    const batch = redisClient.batch();

    // 循环遍历从 Lua 发来的命令列表
    for (const command of commandList) {
        const commandName = command.shift(); // 第一个元素是命令名
        const args = command; // 剩下的是参数
        if (typeof batch[commandName] === 'function') {
            batch[commandName](...args); // 将命令添加到管道队列
        }
    }

    // 执行管道中的所有命令
    batch.exec((err, replies) => {
        if (err) {
            return cb(null, err.message);
        }
        // replies 是一个包含所有结果的数组
        return cb(replies, null);
    });
});

connectToRedis();