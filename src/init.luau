export type InternalConnection = {
    Disconnect: () -> ();
}

export type InternalSignal = {
    Connect: (args...) -> InternalConnection;
    Once: (args...) -> InternalConnection;
    Wait: () -> args...;
    Fire: () -> nil;
    Destroy: () -> nil;
}
export type Signal = {
    new: () -> InternalSignal;
}

local Connection = {}
Connection.__index = Connection

function Connection.new(callback, signal)
    local self = setmetatable({}, Connection)
    self._connected = true

    self._previousConnection = nil
    self._nextConnection = nil

    self._callback = callback
    self._signal = signal
    return self
end

function Connection:Disconnect()
    self._connected = false

    if self._previousConnection then
        self._previousConnection._nextConnection = self._nextConnection
    else
        self._signal._currentConnection = self._nextConnection
    end

    if self._nextConnection then
        self._nextConnection._previousConnection = self._previousConnection
    end
end

local Signal = {}
Signal.__index = Signal

function Signal.new() : Signal
    local self = setmetatable({}, Signal)
    self._currentConnection = nil
    return self
end

function Signal:Connect(callback) : InternalConnection
    local connection = Connection.new(callback, self)

    if self._currentConnection then
       self._currentConnection._previousConnection = connection
       connection._nextConnection = self._currentConnection
       self._currentConnection = connection
    else
        self._currentConnection = connection
    end

    return connection
end

function Signal:Once(callback) : InternalConnection
    local connection

    connection = self:Connect(function()
        connection:Disconnect()
        callback()
    end)

    return connection
end

function Signal:Wait()
    local ActiveThread = coroutine.running()

    self:Once(function()
        task.spawn(ActiveThread)
    end)

    return coroutine.yield()
end

function Signal:FIre(...)
    local CurrentConnection = self._currentConnection
    print(CurrentConnection)
    while CurrentConnection do
        if not CurrentConnection._connected then
            CurrentConnection = CurrentConnection._nextConnection
        end
        task.spawn(CurrentConnection._callback, ...)
        CurrentConnection = CurrentConnection._nextConnection
    end
end

function Signal:Destroy()
    self._currentConnection = nil
end

return Signal