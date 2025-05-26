--[[
	SummerEquinox

	EasyState is a state container class for all kinds of state management. [Release: 1.2.1]
]]

--!strict
--!native
--!optimize 2

local HttpService = game:GetService("HttpService")

--[=[
	@within EasyState
	@type EasyStateValue number | string | boolean | { [any]: any }

	Represents the value of an EasyState object.
]=]
type EasyStateValue = number | string | boolean | { [any]: any }

--[=[
	@within EasyState
	@type Subscriber (number | string | boolean | { [any]: any })? -> ...any

	Represents a function that will be called when the state changes.
]=]
type SubscriberCallback = (EasyStateValue) -> ...any

--[=[
	@within EasyState
	@type SubscriberID userdata

	Represents the ID of a subscriber.
]=]
type SubscriberID = unknown

--[=[
	@within EasyState
	@type SubscriptionState "Active" | "Suspended" | "Inactive"

	Represents the status of a subscriber.
]=]
type SubscriptionState = "Active" | "Suspended" | "Inactive"

local e, w = error, warn

--[[
	Enum for the error messages.
]]
local ErrorMessages = table.freeze({
	Generic = "[EasyState Error] An error occurred.",
	InvalidSubscriberType = "[EasyState Error] A valid subscriber should be a callback function.",
	TryChangeType = "[EasyState Error] EasyState objects are type-locked once created.",
	NoInitialValue = "[EasyState Error] No initial EasyState value was provided.",
	InvalidInitialValue = "[EasyState Error] Attempt to initialize using an invalid type.",
	SubscriberAlreadySuspended = "[EasyState Error] The requested subscriber is already suspended.",
	UnavaiableInMinified = "[EasyState Error] This function is not available in minified state objects.",
	Frozen = "[EasyState Error] This state is frozen and cannot be changed.",
})

--[[
	Enum for the warning messages.
]]
local WarnMessages = table.freeze({
	SubscriberNotFound = "[EasyState Warning] Could not find the requested subscriber.",
	UpdateTypeNoMatch = "[EasyState Warning] Attempt to run :Set() with a new value of a different type. Request will be dropped.",
})

--[[
	Enum for the subscription state.
]]
local SubscriptionState = table.freeze({
	Active = "Active" :: SubscriptionState,
	Suspended = "Suspended" :: SubscriptionState,
	Inactive = "Inactive" :: SubscriptionState,
})

--[[
	Function to audit the initial value.
]]
local function auditInitialValue(value: any)
	if value == nil then
		e(ErrorMessages.NoInitialValue)
	end

	if type(value) == "userdata" or type(value) == "function" then
		e(ErrorMessages.InvalidInitialValue)
	end
end

--[[
	Function to deep copy a table.
]]
local function deepCopy(value: any)
	if type(value) == "table" then
		local newTable = {}
		for key, value in pairs(value) do
			newTable[key] = deepCopy(value)
		end
		return newTable
	end

	return value
end

--[=[
	@class EasyState

	EasyState is a state container class for all kinds of state management.
]=]
local EasyState = {}
EasyState.__index = EasyState
EasyState.__metatable = "This metatable is protected."
EasyState.__call = function(self, newValue: EasyStateValue?)
	if newValue then
		self:Set(newValue)
	else
		self:Reset()
	end
end

--[[
	EasyState type.
]]
type EasyState = typeof(setmetatable(
	{} :: {
		_value: EasyStateValue,
		_originalValue: EasyStateValue?,
		_subscribers: { [SubscriberID]: SubscriberCallback },
		_suspendedSubscribers: { [SubscriberID]: SubscriberCallback },
	},
	{} :: typeof(EasyState)
))

-- Hacky way to make a mini state type that doesn't have the restricted methods without actually running extra code.
--[[
	EasyStateMini type.
]]
type EasyStateMini = typeof(setmetatable(
	{} :: {
		_value: EasyStateValue,
		_subscribers: { [SubscriberID]: SubscriberCallback },
		_suspendedSubscribers: { [SubscriberID]: SubscriberCallback },
	},
	{} :: typeof((function()
		local mt = table.clone(EasyState)
		mt.GetOriginal = nil :: never
		mt.Reset = nil :: never
		mt.__call = function(self, newValue: EasyStateValue?)
			if newValue then
				self:Set(newValue)
			else
				error(ErrorMessages.UnavaiableInMinified)
			end
		end
		return mt
	end)())
))

--[=[
	@within EasyState
	@function new
	@param value boolean | number | string | { [any]: any }
	@return EasyState

	Creates a new EasyState instance with the given initial value.

	:::caution
	It should be noted that EasyState deep clones on all accounts when working with tables. Do not expect external table updates to trigger subscribers.
	You are completely unable to access the deep cloned table by normal means. Updates for table-types must be done with `:Set()` if subscribers are to fire.
	:::

	```lua
	local foo = {}
	print(foo) -- {} (table: 0x4324234234)

	local state = EasyState.new(foo)
	foo.bar = 'baz'

	print(state:Get()) -- {} (table: 0x12321321321)
	```
]=]
function EasyState.new(value: EasyStateValue): EasyState
	auditInitialValue(value)
	local self = setmetatable({}, EasyState)

	self._value = if type(value) == "table" then deepCopy(value) else value
	self._originalValue = self._value
	self._subscribers = {}
	self._suspendedSubscribers = {}

	return self
end

--[=[
	@within EasyState
	@function mini
	@param value boolean | number | string | { [any]: any }
	@return EasyState

	Creates a minified EasyState instance with the given initial value. Mini states take less memory, but restrict the use of some methods.
	Methods which are restricted to mini-states have it noted in their documentation and docstrings.

	:::caution
	Please see warning in the `.new` documentation for information on working with table-type EasyState objects.
	:::
]=]
function EasyState.mini(value: EasyStateValue): EasyStateMini
	auditInitialValue(value)
	local self = (
		setmetatable({
			_value = if type(value) == "table" then deepCopy(value) else value,
			_subscribers = {},
			_suspendedSubscribers = {},
		}, EasyState) :: any
	) :: EasyStateMini

	return self
end

--[=[
	@within EasyState
	@return EasyStateValue

	Gets the current value of the state.
]=]
function EasyState:Get(): EasyStateValue
	if type(self._value) == "table" then
		return deepCopy(self._value)
	end

	return self._value
end

--[=[
	@within EasyState
	@return EasyStateValue
	@error Restricted Method Access  -- This method is unavailable to minified states.

	Gets the original value of the state.
]=]
function EasyState:GetOriginal(): EasyStateValue
	if self._originalValue == nil then
		e(ErrorMessages.UnavaiableInMinified)
	end

	if type(self._originalValue) == "table" then
		return deepCopy(self._originalValue)
	end

	return self._originalValue
end

--[=[
	@within EasyState
	@param value EasyStateValue

	Sets the state to a new value.
]=]
function EasyState:Set(value: EasyStateValue)
	if type(value) ~= type(self._value) then
		w(WarnMessages.UpdateTypeNoMatch)
		return
	end

	if self["_frozen"] then
		e(ErrorMessages.Frozen)
	end

	for _, subscriber in self._subscribers do
		if type(value) == "table" then
			subscriber(deepCopy(value))
		else
			subscriber(value)
		end
	end

	self._value = value
end

--[=[
	@within EasyState
	@param callback Subscriber
	@return SubscriberID

	Subscribes a callback to the state.
]=]
function EasyState:Subscribe(callback: SubscriberCallback): SubscriberID
	if type(callback) ~= "function" then
		e(ErrorMessages.InvalidSubscriberType)
	end

	local subscriberID = newproxy(true)

	local mt = getmetatable(subscriberID)
	mt.__metatable = "This metatable is protected."
	mt.__call = function()
		self:Unsubscribe(subscriberID)
	end

	self._subscribers[subscriberID] = callback

	return subscriberID
end

--[=[
	@within EasyState
	@param callback Subscriber
	@param untilValue EasyStateValue
	@return SubscriberID

	Subscribes a callback to the state until a certain value is reached.
]=]
function EasyState:SubscribeUntil(callback: SubscriberCallback, untilValue: EasyStateValue): SubscriberID
	if type(callback) ~= "function" then
		e(ErrorMessages.InvalidSubscriberType)
	end

	if type(untilValue) ~= type(self._value) then
		e(ErrorMessages.Generic)
	end

	local subscriberID = newproxy(true)

	local mt = getmetatable(subscriberID)
	mt.__metatable = "This metatable is protected."
	mt.__call = function()
		self:Unsubscribe(subscriberID)
	end

	self._subscribers[subscriberID] = callback

	local deportID = nil
	deportID = self:Subscribe(function(value)
		if value == untilValue then
			self:Unsubscribe(subscriberID)
			self:Unsubscribe(deportID)
		end
	end)

	return subscriberID
end

--[=[
	@within EasyState
	@param subscriberID SubscriberID
	@return SubscriptionState

	Gets the status of a subscriber by its ID.
]=]
function EasyState:GetSubscriptionStatus(subscriberID: SubscriberID): SubscriptionState
	if self._subscribers[subscriberID] then
		return SubscriptionState.Active
	elseif self._suspendedSubscribers[subscriberID] then
		return SubscriptionState.Suspended
	else
		return SubscriptionState.Inactive
	end
end

--[=[
	@within EasyState
	@param subcriberID SubscriberID

	Unsubscribes a subscriber.
]=]
function EasyState:Unsubscribe(subcriberID: SubscriberID)
	if not self._subscribers[subcriberID] then
		w(WarnMessages.SubscriberNotFound)
		return
	end

	self._subscribers[subcriberID] = nil
end

--[=[
	@within EasyState
	@param subscriberID SubscriberID
	@param untilValue EasyStateValue
	@param dropSubscriberAfter number

	Unsubscribes a subscriber until a certain value is reached. Optionally allows a custom number of updates to pass before completely dropping the re-subscription potential.
]=]
function EasyState:UnsubscribeUntil(subscriberID: SubscriberID, untilValue: EasyStateValue, dropSubscriberAfter: number)
	if type(untilValue) ~= type(self._value) then
		e(ErrorMessages.Generic)
	end

	if not self._subscribers[subscriberID] then
		w(WarnMessages.SubscriberNotFound)
		return
	end

	if self._suspendedSubscribers[subscriberID] then
		e(ErrorMessages.SubscriberAlreadySuspended)
	end

	if not dropSubscriberAfter then
		dropSubscriberAfter = 10
	end

	local updateCount = 0
	local cachedSubscriber = self._subscribers[subscriberID]

	self._subscribers[subscriberID] = nil
	self._suspendedSubscribers[subscriberID] = cachedSubscriber

	local suspendedCaretakerID = nil
	suspendedCaretakerID = self:Subscribe(function(value)
		local match = false
		if type(value) == "table" and type(untilValue) == "table" then
			match = HttpService:JSONEncode(value) == HttpService:JSONEncode(untilValue)
		else
			match = value == untilValue
		end

		if match then
			self:Unsubscribe(suspendedCaretakerID)
			self._subscribers[subscriberID] = cachedSubscriber
			self._suspendedSubscribers[subscriberID] = nil
			return
		end

		updateCount += 1
		if updateCount >= dropSubscriberAfter then
			self:Unsubscribe(suspendedCaretakerID)
			self._suspendedSubscribers[subscriberID] = nil
		end
	end)
end

--[=[
	@within EasyState

	Unsubscribes all subscribers. Suspended subscribers will still be re-subscribed if their condition is met.
]=]
function EasyState:UnsubscribeAll()
	self._subscribers = {}
end

--[=[
	@within EasyState
	@error Restricted Method Access  -- This method is unavailable to minified states.

	Resets the state to its original value.
]=]
function EasyState:Reset()
	if self._originalValue == nil then
		e(ErrorMessages.UnavaiableInMinified)
	end

	self:Set(self._originalValue)
end

--[=[
	@within EasyState

	Freezes the state so that it cannot be changed.
]=]
function EasyState:Freeze()
	self._frozen = true
end

--[=[
	@within EasyState

	Unfreezes the state so that it can be changed again.
]=]
function EasyState:Unfreeze()
	self._frozen = nil
end

--[=[
	@within EasyState

	Checks if the state is frozen.
]=]
function EasyState:IsFrozen(): boolean
	return rawget(self, "_frozen") ~= nil
end

return EasyState
