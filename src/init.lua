--[[
	SummerEquinox
	EasyState
	v1.0.0
]]

--!strict
--!native
--!optimize 2

local HttpService = game:GetService("HttpService")

type subscriber = (any?) -> ...any
type subcriberID = string

type easyStateValue = number | string | boolean | { [any]: any }
type subscriptionState = string

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
	Active = "Active",
	Suspended = "Suspended",
	Inactive = "Inactive",
}

local function auditInitialValue(value: any)
	if value == nil then
		e(ErrorMessages.NoInitialValue)
	end

	if type(value) == "userdata" or type(value) == "function" then
		e(ErrorMessages.InvalidInitialValue)
	end
end

-- Class Definition
--[=[
	@class EasyState

	EasyState is a state container class for all kinds of state management.
]=]
local EasyState = {}
EasyState.__index = EasyState
EasyState.__metatable = "[EasyState]"

export type EasyState = typeof(setmetatable(
	{} :: {
		ClassName: string,
		_value: easyStateValue,
		_originalValue: easyStateValue,
		_subscribers: { [subcriberID]: subscriber },
		_suspendedSubscribers: { [subcriberID]: subscriber },
	},
	{} :: typeof(EasyState)
))

--[=[
	@within EasyState

	EasyState is a state container class for all kinds of state management.

	@param value easyStateValue
	@return EasyState
]=]
function EasyState.new(value: easyStateValue): EasyState
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

	Gets the current value of the state.

	@return easyStateValue
]=]
function EasyState:Get(): easyStateValue
	if type(self._originalValue) == "table" then
		return table.clone(self._value)
	end

	return self._value
end

--[=[
	@within EasyState

	Gets the original value of the state.

	@return easyStateValue
]=]
function EasyState:GetOriginal(): easyStateValue
	if type(self._originalValue) == "table" then
		return table.clone(self._originalValue)
	end

	return self._originalValue
end

--[=[
	@within EasyState

	Sets the state to a new value.

	@param value easyStateValue
]=]
function EasyState:Set(value: easyStateValue)
	if type(value) ~= type(self._originalValue) then
		w(WarnMessages.UpdateTypeNoMatch)
	end

	self._value = value

	for _, subscriber in self._subscribers do
		if type(value) == "table" then
			subscriber(table.clone(value))
		else
			subscriber(value)
		end
	end
end

--[=[
	@within EasyState

	Subscribes a callback to the state.

	@param callback subscriber
	@return subcriberID
]=]
function EasyState:Subscribe(callback: subscriber): subcriberID
	if type(callback) ~= "function" then
		e(ErrorMessages.InvalidSubscriberType)
	end

	local subscriberID = HttpService:GenerateGUID(false)
	self._subscribers[subscriberID] = callback

	return subscriberID
end

--[=[
	@within EasyState

	Subscribes a callback to the state until a certain value is reached.

	@param callback subscriber
	@param untilValue easyStateValue
	@return subcriberID
]=]
function EasyState:SubscribeUntil(callback: subscriber, untilValue: easyStateValue): subcriberID
	if type(callback) ~= "function" then
		e(ErrorMessages.InvalidSubscriberType)
	end

	if type(untilValue) ~= type(self._originalValue) then
		e(ErrorMessages.Generic)
	end

	local subscriberID = HttpService:GenerateGUID(false)
	self._subscribers[subscriberID] = callback

	local deportID = nil
	local deportID = self:Subscribe(function(value)
		if value == untilValue then
			self:Unsubscribe(subscriberID)
			self:Unsubscribe(deportID)
		end
	end)

	return subscriberID
end

--[=[
	@within EasyState

	Gets the status of a subscriber by its ID.

	@param subscriberID subcriberID
	@return subscriptionState
]=]
function EasyState:GetSubscriptionStatus(subscriberID: subcriberID): subscriptionState
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

	Unsubscribes a subscriber.

	@param subcriberID subcriberID
]=]
function EasyState:Unsubscribe(subcriberID: subcriberID)
	if not self._subscribers[subcriberID] then
		w(WarnMessages.SubscriberNotFound)
		return
	end

	self._subscribers[subcriberID] = nil
end

--[=[
	@within EasyState

	Unsubscribes a subscriber until a certain value is reached.

	@param subscriberID subcriberID
	@param untilValue easyStateValue
	@param dropSubscriberAfter number
]=]
function EasyState:UnsubscribeUntil(subscriberID: subcriberID, untilValue: easyStateValue, dropSubscriberAfter: number)
	if type(untilValue) ~= type(self._originalValue) then
		e(ErrorMessages.Generic)
	end

	if not self._subscribers[subscriberID] then
		w(WarnMessages.SubscriberNotFound)
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
	local suspendedCaretakerID = self:Subscribe(function(value)
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
