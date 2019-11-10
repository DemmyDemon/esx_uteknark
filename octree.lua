local table = table
local vector3 = vector3
local AXIS = {'x','y','z'}
local MAX_OBJECTS = 5
local MAX_LEVELS = 50

local function intersects(box,item)
    local intersect = {x=false,y=false,z=false}
    ---[[
    for _,axis in ipairs(AXIS) do
        if item.max[axis] > box.min[axis] and item.min[axis] < box.max[axis] then
            intersect[axis] = true
        end
    end
    return intersect.x and intersect.y and intersect.z, intersect

end

function canFit(box,item)
    local fit = {x=false,y=false,z=false}
    for _,axis in ipairs(AXIS) do
        if item.max[axis] <= box.max[axis] and item.min[axis] >= box.min[axis] then
            fit[axis] = true
        end
    end
    return fit.x and fit.y and fit.z,fit
end


local function crossProduct(A,B)
    return vector3(
        A.y * B.z - A.z * B.y, -- X
        A.z * B.x - A.x * B.z, -- Y
        A.x * B.y - A.y * B.x  -- Z
    )
end

local function dotProduct(A,B)
    return A.x * B.x + A.y * B.y + A.z * B.z
end

local function modulus(A)
    return math.sqrt(dotProduct(A,A))
end

local function lineDistance(A,B,C)
    local AB = B - A
    local AC = C - A
    local modab = modulus(AB)

    local dotProductACAB = dotProduct(AC,AB)
    if dotProductACAB <= 0.0 then
        return modulus(AC)--,0.0
    end

    local BC = C - B
    local dotProductBCAB = dotProduct(BC,AB)
    if dotProductBCAB >= 0.0 then
        return modulus(BC)--,1.0
    end

    local cpabac = crossProduct(AB,AC)
    local modcpabac = modulus(cpabac)
    return  modcpabac/modab
end

function pointInside(box,point)
    local inside = {x=false,y=false,z=false}
    for _,axis in ipairs(AXIS) do
        if point[axis] >= box.min[axis] and point[axis] <= box.max[axis] then
            inside[axis] = true
        end
    end
    return inside.x and inside.y and inside.z, inside
end

local boundsMeta = {
    __newindex = function(instance,key,value)
        -- Drop. Ignore. Go away.
    end,
    __index = function(instance,key)
        return instance._methods[key]
    end,
}
local boundsMethods = {
    volume = function(instance)
        local width = instance.max.x - instance.min.x
        local breadth = intance.max.y - instance.min.y
        local height = instance.max.z - instance.min.z
        return width*breadth*height
    end,
    canFit = function(instance,location,dimensions)
        if getmetatable(location) == boundsMeta then
            return canFit(instance,location)
        else
            local item = pBoxBounds(location,dimensions)
            return canFit(instance,location)
        end
    end,
    intersects = function(instance,location,dimensions)
        if getmetatable(location) == boundsMeta then
            return intersects(instance,location)
        else
            local item = pBoxBounds(location,dimensions)
            return intersects(instance,item)
        end
    end,
    inside = function(instance,point)
        if #(instance.location - point) <= instance.radius then
            return pointInside(instance,point)
        end
        return false
    end,
    draw = function(instance,r,g,b,a)
        r = r or 255
        g = g or 0
        b = b or 0
        a = a or 128
        -- Upper layer
        DrawLine(
            instance.max.x,instance.max.y,instance.max.z,
            instance.min.x,instance.max.y,instance.max.z,
        r,g,b,a)
        DrawLine(
            instance.min.x,instance.max.y,instance.max.z,
            instance.min.x,instance.min.y,instance.max.z,
        r,g,b,a)
        DrawLine(
            instance.min.x,instance.min.y,instance.max.z,
            instance.max.x,instance.min.y,instance.max.z,
        r,g,b,a)
        DrawLine(
            instance.max.x,instance.min.y,instance.max.z,
            instance.max.x,instance.max.y,instance.max.z,
        r,g,b,a)

        -- Lower layer
        DrawLine(
            instance.max.x,instance.max.y,instance.min.z,
            instance.min.x,instance.max.y,instance.min.z,
        r,g,b,a)
        DrawLine(
            instance.min.x,instance.max.y,instance.min.z,
            instance.min.x,instance.min.y,instance.min.z,
        r,g,b,a)
        DrawLine(
            instance.min.x,instance.min.y,instance.min.z,
            instance.max.x,instance.min.y,instance.min.z,
        r,g,b,a)
        DrawLine(
            instance.max.x,instance.min.y,instance.min.z,
            instance.max.x,instance.max.y,instance.min.z,
        r,g,b,a)

        -- Connectors
        DrawLine(
        instance.max.x,instance.max.y,instance.max.z,
        instance.max.x,instance.max.y,instance.min.z,
        r,g,b,a)
        DrawLine(
        instance.min.x,instance.max.y,instance.max.z,
        instance.min.x,instance.max.y,instance.min.z,
        r,g,b,a)
        DrawLine(
        instance.min.x,instance.min.y,instance.max.z,
        instance.min.x,instance.min.y,instance.min.z,
        r,g,b,a)
        DrawLine(
        instance.max.x,instance.min.y,instance.max.z,
        instance.max.x,instance.min.y,instance.min.z,
        r,g,b,a)
        --DrawBox(instance.min,instance.max,r,g,b,math.floor(a/2))
    end,
}

function pBoxBounds(location,dimensions)
    if type(dimensions) == 'number' then -- Assume it's a cube
        dimensions = vector3(dimensions,dimensions,dimensions)
    end
    local half = dimensions/2
    local bounds = {
        location = location,
        dimensions = dimensions,
        max = vector3(
            location.x + half.x,
            location.y + half.y,
            location.z + half.z
        ),
        min = vector3(
            location.x - half.x,
            location.y - half.y,
            location.z - half.z
        ),
        _methods = boundsMethods,
    }
    bounds.radius = #(bounds.max - bounds.min)/2
    return setmetatable(bounds,boundsMeta)
end

local nodeMethods = {
    canFit = function(instance,location,dimensions)
        local box = instance.bounds
        if getmetatable(location) == boundsMeta then
            return canFit(box,location)
        end
        local item = pBoxBounds(location,dimensions)
        return canFit(box,item)
    end,
    intersects = function(instance,location,dimensions)
        local box = instance.bounds
        if getmetatable(location) == boundsMeta then
            return intersects(box,location)
        end
        local item = pBoxBounds(location,dimensions)
        return intersects(box,item)
    end,
    selectNode = function(instance,item)
        if instance._data.nodes then
            for i,node in ipairs(instance._data.nodes) do
                if node:canFit(item) then
                    return node
                end
            end
        end
    end,
    split = function(instance)
        if not instance._data.nodes then
            --pPushText('Splitting '..instance.level..' ('..GetGameTimer()..')')
            instance._data.nodes = {}
            local dim = instance._data.bounds.dimensions
            local pos = instance._data.bounds.location
            local quarter = dim/4
            local half = dim/2
            local nextLevel = instance._data.level + 1
            table.insert(instance._data.nodes,pOctree(vector3(pos.x+quarter.x,pos.y+quarter.x,pos.z+quarter.z),half,nextLevel))
            table.insert(instance._data.nodes,pOctree(vector3(pos.x-quarter.x,pos.y+quarter.x,pos.z+quarter.z),half,nextLevel))
            table.insert(instance._data.nodes,pOctree(vector3(pos.x+quarter.x,pos.y-quarter.x,pos.z+quarter.z),half,nextLevel))
            table.insert(instance._data.nodes,pOctree(vector3(pos.x-quarter.x,pos.y-quarter.x,pos.z+quarter.z),half,nextLevel))

            table.insert(instance._data.nodes,pOctree(vector3(pos.x+quarter.x,pos.y+quarter.x,pos.z-quarter.z),half,nextLevel))
            table.insert(instance._data.nodes,pOctree(vector3(pos.x-quarter.x,pos.y+quarter.x,pos.z-quarter.z),half,nextLevel))
            table.insert(instance._data.nodes,pOctree(vector3(pos.x+quarter.x,pos.y-quarter.x,pos.z-quarter.z),half,nextLevel))
            table.insert(instance._data.nodes,pOctree(vector3(pos.x-quarter.x,pos.y-quarter.x,pos.z-quarter.z),half,nextLevel))
        end
    end,
    insert = function(instance,location,dimensions,data)
        data = data or {}
        if type(location) ~= 'vector3' then
            error('First argument to :insert must be a vector3 for location, got '..tyoe(location),2)
        end
        if type(dimensions) == 'number' then -- Presume cube
            dimensions = vector3(dimensions,dimensions,dimensions)
        elseif type(dimensions) ~= 'vector3' then
            error('Second argument to :insert must be either a number (if cube) or a vector3 for dimetions, got '..type(dimensions),2)
        end
        local object = {
            data = data,
            bounds = pBoxBounds(location,dimensions),
        }
        if instance:canFit(object.bounds) then

            local node = instance:selectNode(object.bounds)
            if node then
                return node:insert(location,dimensions,data)
            end

            object.node = instance
            object.oindex = #instance._data.objects + 1
            table.insert(instance._data.objects,object)
            completeSuccess = true

            if #instance._data.objects > MAX_OBJECTS and instance._data.level < MAX_LEVELS then
                local limboObjects = instance._data.objects
                instance._data.objects = {}
                if not instance._data.nodes then
                    instance:split()
                end
                for i,lobject in ipairs(limboObjects) do
                    local newNode = instance:selectNode(lobject.bounds)
                    if newNode then
                        if not newNode:insert(lobject.bounds.location,lobject.bounds.dimensions,lobject.data) then
                            completeSuccess = false
                        end
                    else
                        lobject.oindex = #instance._data.objects + 1
                        table.insert(instance._data.objects,lobject)
                    end
                end
            end
            return completeSuccess,object
        else
            error('Object inserted by :insert does not fit in node at level '..instance._data.level,2)
        end
    end,
    remove = function(instance,index)
        if instance._data.objects[index] then
            local removed = instance._data.objects[index]
            removed.node = nil
            removed.oindex = nil
            table.remove(instance._data.objects,index)
            for i,object in ipairs(instance._data.objects) do
                object.oindex = i
            end
            return removed
        end
    end,
    all = function(instance,funcref)
        if type(funcref) == 'function' then
            for i,item in ipairs(instance._data.objects) do
                funcref(item)
            end
            if instance._data.nodes then
                for i,node in ipairs(instance._data.nodes) do
                    node:all(funcref)
                end
            end
        end
    end,
    searchBox = function(instance,location,dimensions,hits)
        hits = hits or {}
        local searchBox
        dimensions = dimensions or vector3(1,1,1)
        if getmetatable(location) == boundsMeta then
            searchBox = location
        else
            searchBox = pBoxBounds(location,dimensions)
        end
        if instance._data.bounds:intersects(searchBox) then
            for i,object in ipairs(instance._data.objects) do
                if object.bounds:intersects(searchBox) then
                    table.insert(hits,object)
                end
            end
            if instance._data.nodes then
                for i,node in ipairs(instance._data.nodes) do
                    node:searchBox(searchBox,dimensions,hits)
                end
            end
        end
        return hits
    end,
    searchSphereAsync = function(instance,location,radius,callback, slowMode)
        Citizen.CreateThread(function()
            local distance = #( location - instance._data.bounds.location )
            if distance <= radius + instance._data.bounds.radius then
                for i,object in pairs(instance._data.objects) do
                    local objectDistance = #( location - object.bounds.location)
                    if objectDistance <= radius + object.bounds.radius then
                        callback(object)
                    end
                end
                if instance._data.nodes then
                    for i,node in ipairs(instance._data.nodes) do
                        if slowMode then
                            Citizen.Wait(0)
                        end
                        node:searchSphereAsync(location, radius, callback, slowMode)
                    end
                end
            end
        end)
    end,
    searchSphere = function(instance,location,radius,hits)
        hits = hits  or {}
        local distance = #( location - instance._data.bounds.location )
        if distance <= radius + instance._data.bounds.radius then
            for i,object in pairs(instance._data.objects) do
                local objectDistance = #( location - object.bounds.location)
                if objectDistance <= radius + object.bounds.radius then
                    table.insert(hits,object)
                end
            end
            if instance._data.nodes then
                for i,node in ipairs(instance._data.nodes) do
                    node:searchSphere(location,radius,hits)
                end
            end
        end
        return hits
    end,
    searchRay = function(instance,from,to,thickness,hits)
        thickness = thickness or 0
        hits = hits or {}
        local distance = lineDistance(from,to,instance._data.bounds.location)
        local intersectRange = thickness+instance._data.bounds.radius
        if distance <= intersectRange then
            for i,object in ipairs(instance._data.objects) do
                local objDistance = lineDistance(from,to,object.bounds.location)
                local objIntersectRange = thickness+object.bounds.radius
                if objDistance <= objIntersectRange then
                    table.insert(hits,object)
                end
            end
            if instance._data.nodes then
                for i,node in ipairs(instance._data.nodes) do
                    node:searchRay(from,to,thickness,hits)
                end
            end
        end
        return hits
    end,
}
local octreeNodeMeta = {
    __index = function(instance,key)
        if instance._methods[key] then
            return instance._methods[key]
        else
            return instance._data[key]
        end
    end,
    __newindex = function(instance,key,value)
        if instance._data[key] then
            instance._data[key] = value
        end
    end,
}
local function newNode(location,dimensions,level)
    level = level or 0
    if type(dimensions) == 'number' then -- Presume it's a cube
        dimensions = vector3(dimensions,dimensions,dimensions)
    end
    local new = {
        _data = {
            location = location or vector3(0,0,0),
            dimensions = dimensions or vector3(1,1,1),
            objects = {},
            level = level,
        },
        _methods = nodeMethods,
    }
    new._data.bounds = pBoxBounds(new._data.location,new._data.dimensions)
    return setmetatable(new,octreeNodeMeta)
end

function pOctree(location,dimensions,startLevel)
    return newNode(location,dimensions,startLevel)
end
