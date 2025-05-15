---
sidebar_position: 2
---

# Basic Usage

EasyState is a powerful and lightweight state management solution for Roblox Lua. It provides a simple way to create, manage, and subscribe to state changes in your applications.

## Installation

Add EasyState to your project using Wally:

```toml
[dependencies]
EasyState = "summerequinox/easystate@1.0.2"
```

## Basic Usage

### Creating a State

```lua
local EasyState = require(path.to.EasyState)

-- Create a new state with an initial value
local counter = EasyState.new(0)
local name = EasyState.new("Player")
local isActive = EasyState.new(false)
local playerData = EasyState.new({
    health = 100,
    level = 1
})
```

### Getting and Setting Values

```lua
-- Get the current value
local currentValue = counter:Get()

-- Set a new value
counter:Set(5)
name:Set("NewPlayer")
isActive:Set(true)
playerData:Set({
    health = 90,
    level = 2
})

-- Reset to original value
counter:Reset()
```

### Subscribing to Changes

```lua
-- Basic subscription
local subscription = counter:Subscribe(function(newValue)
    print("Counter changed to:", newValue)
end)

-- Subscribe until a specific value is reached
local untilSubscription = counter:SubscribeUntil(function(value)
    print("Counter is now:", value)
end, 10)

-- Unsubscribe when done
counter:Unsubscribe(subscription)
```

### Type Safety

EasyState is type-locked once created. This means you cannot change the type of value after initialization:

```lua
local numberState = EasyState.new(5)
numberState:Set(10) -- Works fine
numberState:Set("string") -- Warning: Type mismatch, request will be dropped
```

### Table Values

When working with table values, EasyState automatically clones the tables to prevent reference issues:

```lua
local data = EasyState.new({ count = 0 })

-- Getting returns a clone
local currentData = data:Get()
currentData.count = 5 -- Won't affect the original state

-- Setting with a table
data:Set({ count = 10 })
```
