# Save Controller Example

This example demonstrates how to create a save controller using EasyState to manage and expose data cache updates to the rest of the client code.

```lua
-- SaveController.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EasyState = require(ReplicatedStorage.Packages.EasyState)

local SaveController = {}

-- Create a state for the entire data cache
SaveController.Data = EasyState.new({})

-- Remote events for data updates
local DataUpdateEvent = ReplicatedStorage:WaitForChild("DataUpdate")
local KeyUpdateEvent = ReplicatedStorage:WaitForChild("KeyUpdate")

-- Handle incoming data updates
DataUpdateEvent.OnClientEvent:Connect(function(newData)
    SaveController.Data:Set(newData)
end)

-- Handle single key updates
KeyUpdateEvent.OnClientEvent:Connect(function(key, value)
    local currentData = SaveController.Data:Get()
    currentData[key] = value
    SaveController.Data:Set(currentData)
end)

return SaveController
```

Here's how other client code can use the controller:

```lua
-- SomeOtherModule.lua
local SaveController = require(path.to.SaveController)

-- Subscribe to any data changes
SaveController.Data:Subscribe(function(newData)
    print("Data updated:", newData)
end)

-- Access specific data
local currentData = SaveController.Data:Get()
print("Current coins:", currentData.coins)
print("Current level:", currentData.level)
print("Current inventory:", currentData.inventory)
```

This controller provides a centralized way to manage and observe data changes across your client code. The entire data cache is stored in a single state, making it easy to handle both complete data updates and single key updates from the server.

Other modules can require the SaveController and subscribe to the data state to react to any changes in the save data. The controller handles incoming data updates from the server and automatically updates the state with the new data.

You can extend this pattern by adding methods to handle specific data types or update scenarios while maintaining the single source of truth for the data cache.
