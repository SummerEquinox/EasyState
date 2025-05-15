---
sidebar_position: 3
---

# Advanced Usage

## Shorthand Options

### Using Subscriber ID to Unsubscribe

When you get a subscriber ID from `Subscribe()`, you can call it directly to unsubscribe instead of using `Unsubscribe()`:

```lua
local myState = EasyState.new(0)
local subscriber = myState:Subscribe(function(value)
    print("State changed to:", value)
end)

-- Later, to unsubscribe:
subscriber()  -- This is the shorthand
```

This is equivalent to:
```lua
myState:Unsubscribe(subscriber)
```

### Using State Object to Set Values

You can call the state object directly to set its value instead of using the `Set()` method:

```lua
local myState = EasyState.new(0)
myState(42)  -- Sets the state to 42
```

This is equivalent to:
```lua
myState:Set(42)
```

These shorthand options make your code more concise while maintaining the same functionality as their longer counterparts.

