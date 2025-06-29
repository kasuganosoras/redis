# Redis Pub/Sub Feature Guide

## Introduction

This module provides Redis Publish/Subscribe (Pub/Sub) functionality for a FiveM server. With this feature, you can achieve real-time message communication across different resources and servers.

## Installation

Ensure that you have correctly installed the Redis resource and configured the Redis connection string in your `server.cfg`:

```
set redis_connection_string "redis://localhost:6379"
ensure redis
```

## Functionality Description

### Subscribe to a Channel

```lua
exports.redis:subscribe(channel, callback)
```

**Parameters:**

  - `channel`: The name of the channel to subscribe to.
  - `callback`: A callback function that receives two arguments: `(success, error)`.

**Example:**

```lua
exports.redis:subscribe("news", function(success, err)
    if err then
        print("Subscription failed: " .. err)
    else
        print("Successfully subscribed to the channel")
    end
end)
```

### Subscribe to Multiple Channels in Bulk

```lua
local channels = {"channel1", "channel2", "channel3"}
exports.redis:subscribeMulti(channels, function(success, err)
    if err then
        print('Bulk subscription failed: ' .. err)
    else
        print('Successfully bulk subscribed to multiple channels')
    end
end)
```

### Unsubscribe from a Channel

```lua
exports.redis:unsubscribe(channel, callback)
```

**Parameters:**

  - `channel`: The name of the channel to unsubscribe from.
  - `callback`: A callback function that receives two arguments: `(success, error)`.

**Example:**

```lua
exports.redis:unsubscribe("news", function(success, err)
    if err then
        print("Unsubscription failed: " .. err)
    else
        print("Successfully unsubscribed from the channel")
    end
end)
```

### Publish a Message

```lua
exports.redis:publish(channel, message, callback)
```

**Parameters:**

  - `channel`: The name of the channel to publish the message to.
  - `message`: The content of the message to be published (can be a string or a table).
  - `callback`: A callback function that receives two arguments: `(recipients, error)`, where `recipients` is the number of clients that received the message.

**Example (Publishing a string):**

```lua
exports.redis:publish("news", "This is a news message", function(recipients, err)
    if err then
        print("Publish failed: " .. err)
    else
        print("Message published, " .. recipients .. " clients received the message")
    end
end)
```

**Example (Publishing table data):**

```lua
local tableData = {
    id = 1234,
    name = "Test Data",
    items = {"Item1", "Item2"},
    metadata = {
        created = os.time(),
        author = "System"
    }
}

exports.redis:publish("data_channel", tableData, function(recipients, err)
    if err then
        print("Publish failed: " .. err)
    else
        print("Table data published, " .. recipients .. " clients received the message")
    end
end)
```

### Publish Multiple Messages in Bulk

Use pipeline technology to publish multiple messages in bulk for improved performance:

```lua
local messages = {
    {channel = "channel1", message = "Message 1"},
    {channel = "channel2", message = "Message 2"},
    {channel = "channel3", message = {id = 1, name = "Table Data"}} -- Supports table data
}

exports.redis:publishMulti(messages, function(replies, err)
    if err then
        print('Bulk publish failed: ' .. err)
    else
        print('Successfully bulk published multiple messages')
        -- replies is an array containing the number of recipients for each message
        for i, reply in ipairs(replies) do
            print('Message #' .. i .. ' sent to ' .. messages[i].channel .. ', received by ' .. reply .. ' clients')
        end
    end
end)
```

> Note: Table data is automatically converted to a JSON string for transmission. Ensure that the data in the table can be correctly serialized (e.g., it does not contain functions, userdata, or other non-serializable data types).

### Receiving Messages

When a subscribed channel receives a message, the `redis:message` event is triggered.

```lua
AddEventHandler("redis:message", function(channel, message, parsedData)
    print("Received a message from channel " .. channel .. ": " .. message)
    
    -- If JSON data (a table) is received
    if parsedData then
        -- parsedData is the automatically parsed table data
        print("Data ID: " .. parsedData.id)
        -- You can directly access the data in the table
    else
        -- It's a regular string message
    end
end)
```

**Parameters:**

  - `channel`: The name of the channel the message came from.
  - `message`: The original message content (string).
  - `parsedData`: If the original message is in JSON format, this parameter will contain the parsed table data; otherwise, it will be `nil`.

> Note: The system automatically attempts to parse JSON-formatted messages into a table. If parsing is successful, the `parsedData` parameter will contain the resulting table; if parsing fails or the message is not in JSON format, `parsedData` will be `nil`.

## Use Cases

1.  **Cross-Resource Communication**: Different resources can communicate with each other via Redis Pub/Sub without direct dependencies.

2.  **Cross-Server Communication**: Multiple FiveM servers can achieve real-time cross-server communication by sharing the same Redis instance.

3.  **Real-Time Notification System**: Can be used to implement server-wide announcements, administrator notifications, etc.

4.  **Data Synchronization**: When data on one server changes, it can notify other servers to synchronize.

## Example Code

A complete example code can be found in `examples/pubsub_example.lua`, which includes a full demonstration of subscribing, publishing, and receiving messages.

## Important Notes

1.  Redis Pub/Sub is non-persistent. If a client disconnects, it will not receive messages that were published during the disconnection period.

2.  To avoid message loss for important messages, it is recommended to implement a message queue in conjunction with other Redis features (such as Lists or Sorted Sets).

3.  A large volume of frequent messages may impact performance. Please use this feature reasonably based on your actual needs.