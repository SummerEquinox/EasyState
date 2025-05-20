--[[
	SummerEquinox
	EasyState
	v1.1.6

    https://summerequinox.github.io/EasyState/api/EasyState/
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
	@type Subscriber (any?) -> ...any

	Represents a function that will be called when the state changes.
]=]
type Subscriber = (EasyStateValue?) -> ...any

--[=[
	@within EasyState
	@type SubscriberID unknown

	Represents the ID of a subscriber.
]=]
type SubscriberID = typeof(newproxy(true))

--[=[
	@within EasyState
	@type SubscriptionState "Active" | "Suspended" | "Inactive"

	Represents the status of a subscriber.
]=]
type SubscriptionState = "Active" | "Suspended" | "Inactive"

local e, w = error, warn

local ErrorMessages = {
	Generic = "[EasyState Error] An error occurred.",
	InvalidSubscriberType = "[EasyState Error] A valid subscriber should be a callback function.",
	TryChangeType = "[EasyState Error] EasyState objects are type-locked once created.",
	NoInitialValue = "[EasyState Error] No initial EasyState value was provided.",
	InvalidInitialValue = "[EasyState Error] Attempt to initialize using an invalid type.",
	SubscriberAlreadySuspended = "[EasyState Error] The requested subscriber is already suspended.",
}

local WarnMessages = {
	SubscriberNotFound = "[EasyState Warning] Could not find the requested subscriber.",
	UpdateTypeNoMatch = "[EasyState Warning] Attempt to run :Set() with a new value of a different type. Request will be dropped.",
}

local SubscriptionState = {
	Active = "Active" :: SubscriptionState,
	Suspended = "Suspended" :: SubscriptionState,
	Inactive = "Inactive" :: SubscriptionState,
}

local function auditInitialValue(value: any)
	if value == nil then
		e(ErrorMessages.NoInitialValue)
	end

	if type(value) == "userdata" or type(value) == "function" then
		e(ErrorMessages.InvalidInitialValue)
	end
end

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

-- Class Definition
--[=[
	@class EasyState

	EasyState is a state container class for all kinds of state management.
]=]
local EasyState = {}
EasyState.__index = EasyState
EasyState.__metatable = "[EasyState]"
EasyState.__call = function(self, newValue: EasyStateValue?)
	if newValue then
		self:Set(newValue)
	else
		self:Reset()
	end
end

export type EasyState = typeof(setmetatable(
	{} :: {
		ClassName: string,
		_value: EasyStateValue,
		_originalValue: EasyStateValue,
		_subscribers: { [SubscriberID]: Subscriber },
		_suspendedSubscribers: { [SubscriberID]: Subscriber },
	},
	{} :: typeof(EasyState)
))

--[=[
	@within EasyState
	@function new
	@param value EasyStateValue
	@return EasyState

	Creates a new EasyState instance with the given initial value.
]=]
function EasyState.new(value: EasyStateValue): EasyState
	auditInitialValue(value)
	local self = setmetatable({}, EasyState)

	self.ClassName = "EasyState"

	self._value = value
	self._originalValue = value
	self._subscribers = {}
	self._suspendedSubscribers = {}

	return self
end

--[=[
	@within EasyState
	@return EasyStateValue

	Gets the current value of the state.
]=]
function EasyState:Get(): EasyStateValue
	if type(self._originalValue) == "table" then
		return deepCopy(self._value)
	end

	return self._value
end

--[=[
	@within EasyState
	@return EasyStateValue

	Gets the original value of the state.
]=]
function EasyState:GetOriginal(): EasyStateValue
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
	if type(value) ~= type(self._originalValue) then
		w(WarnMessages.UpdateTypeNoMatch)
		return
	end

	self._value = value

	for _, subscriber in self._subscribers do
		if type(value) == "table" then
			subscriber(deepCopy(self._value))
		else
			subscriber(self._value)
		end
	end
end

--[=[
	@within EasyState
	@param callback Subscriber
	@return SubscriberID

	Subscribes a callback to the state.
]=]
function EasyState:Subscribe(callback: Subscriber): SubscriberID
	if type(callback) ~= "function" then
		e(ErrorMessages.InvalidSubscriberType)
	end

	local subscriberID = newproxy(true)

	local mt = getmetatable(subscriberID)
	mt.__metatable = "[EasyState.SubscriberID]"
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
function EasyState:SubscribeUntil(callback: Subscriber, untilValue: EasyStateValue): SubscriberID
	if type(callback) ~= "function" then
		e(ErrorMessages.InvalidSubscriberType)
	end

	if type(untilValue) ~= type(self._originalValue) then
		e(ErrorMessages.Generic)
	end

	local subscriberID = newproxy(true)

	local mt = getmetatable(subscriberID)
	mt.__metatable = "[EasyState.SubscriberID]"
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

	Unsubscribes a subscriber until a certain value is reached.
]=]
function EasyState:UnsubscribeUntil(subscriberID: SubscriberID, untilValue: EasyStateValue, dropSubscriberAfter: number)
	if type(untilValue) ~= type(self._originalValue) then
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

	Resets the state to its original value.
]=]
function EasyState:Reset()
	self:Set(self._originalValue)
end

return EasyState
