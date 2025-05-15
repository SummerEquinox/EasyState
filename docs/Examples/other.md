# UnsubscribeUntil Example

```lua
local state = EasyState.new(0)

local subscription = state:Subscribe(function(value)
    print("Value:", value)
end)

state:UnsubscribeUntil(subscription, 5)

for i = 1, 10 do
    state:Set(i)
end
```


