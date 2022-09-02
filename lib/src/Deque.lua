local Deque = {}
Deque.__index = {}

export type Deque<T> = {
    getCount: (self: Deque<T>) -> number,

    pushLeft: (self: Deque<T>, obj: T) -> (),
    pushRight: (self: Deque<T>, obj: T) -> (),

    popLeft: (self: Deque<T>) -> T?,
    popRight: (self: Deque<T>) -> T?,
}

function Deque.new<T>(): Deque<T>
    return setmetatable({
        _objects = {},
        _first = 0,
        _last = -1,
    }, Deque) :: Deque<T>
end

function Deque.__index:getCount()
    return self._last - self._first + 1
end

function Deque.__index:pushLeft(obj)
    self._first = self._first - 1
    self._objects[self._first] = obj
end

function Deque.__index:pushRight(obj)
    self._last = self._last + 1
    self._objects[self._last] = obj
end

function Deque.__index:popLeft()
    if self._first > self._last then
        return nil
    end
    local obj = self._objects[self._first]
    self._objects[self._first] = nil
    self._first = self._first + 1
    return obj
end

function Deque.__index:popRight()
    if self._first > self._last then
        return nil
    end
    local obj = self._objects[self._last]
    self._objects[self._last] = nil
    self._last = self._last - 1
    return obj
end

function Deque.__index:peekLeft()
    return self._objects[self._first]
end

function Deque.__index:peekRight()
    return self._objects[self._last]
end

function Deque.__index:iter()
    local t = self._objects
    local i = self._first - 1
    return function()
        i = i + 1
        return t[i]
    end
end

return Deque
