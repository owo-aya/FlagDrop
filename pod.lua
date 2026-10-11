-- Build 25480438. ShipStationHotkeys v1.9 (0BSD), native F8 path:
-- https://github.com/CowboyBingus/ShipStationHotkeys
-- Called on the solo ship after mission selection. Stops at drop-point choice.
local ffi = require('ffi')
ffi.cdef[[void *flagdrop_pod_GetModuleHandleA(const char *) __asm__("GetModuleHandleA");]]
local game = ffi.cast('uint8_t *', ffi.load('kernel32').flagdrop_pod_GetModuleHandleA('game.dll'))
local M = {state='idle'}
local function ptr(a) return ffi.cast('uint8_t **',a)[0] end
local function u32(a) return tonumber(ffi.cast('uint32_t *',a)[0]) end

local open_briefing = ffi.cast('void (__fastcall *)(void *, uint32_t)',game+0x661cf0)
local instant_seat = ffi.cast('void (__fastcall *)(void *, void *, void *)',game+0x639830)
local pod

-- Resolve the local player's avatar through the game's entity table, then
-- find its seater entity. These are lookups, with no file or build checks.
local function avatar_entity()
    local players = ptr(game+0x3326468)
    local entity_ref = u32(players+0x3a8)
    local entities = ptr(game+0x346bf98)
    local map = entities+0xf22ec8
    local buckets, capacity = ptr(map),u32(map+8)
    local avatar_id
    for i=0,capacity-1 do
        if u32(buckets+i*8)==entity_ref then
            local index = u32(buckets+i*8+4)
            avatar_id = u32(entities+0xf32f18+index*24+8)
            break
        end
    end
    local seater = ptr(game+0x3326d78)
    local members = ptr(seater+56)
    for i=0,u32(seater+12)-1 do
        local entity = ptr(members+i*8)
        if u32(entity+8)==avatar_id then return entity end
    end
end

local function pod_open()
    local manager = ptr(game+0x3326428)
    for i=0,u32(manager+8)-1 do
        if u32(ptr(manager+104+i*8)+8)==pod then
            return u32(manager+184+i*20)==3 and u32(manager+264+i*4)==3
        end
    end
end

local function seat()
    -- The instant-entry request uses byte 0 and a placement pointer at +72.
    -- Placement words 406/407/408 are seat entity / entrance key / index;
    -- zero entrance key and index select the pod's first entrance.
    local placement = ffi.new('uint32_t[409]')
    placement[406] = pod
    local request = ffi.new('uint8_t[80]')
    request[0] = 1
    ffi.cast('uint32_t **',request+72)[0] = placement
    instant_seat(nil,avatar_entity(),request)
    M.state = 'done'
end

function M.enter()
    -- Solo ship: deployment slot 0 is the local player's Hellpod.
    pod = u32(ptr(game+0x33265f0)+72984)
    M.state = 'opening'
    return false
end

function M.screen()
    local stack = ptr(game+0x347ce38)
    if u32(stack)==11 then return ptr(stack+176) end
end

function M.update(dt)
    if M.state=='done' then return true end
    if M.state=='opening' then
        if pod_open() then
            open_briefing(nil,0)
            M.state = 'briefing'
        end
        return false
    end
    if M.state=='briefing' then
        local stack = ptr(game+0x347ce38)
        if u32(stack)~=11 then return false end
        local screen = ptr(stack+176)
        local phase = u32(screen+2570636)
        if phase==1 then
            ffi.cast('float *',screen+2570632)[0] = 0
        elseif phase==0 then
            -- Seat on this frame, when briefing sets its map camera.
            seat()
            return true
        end
    end
    return false
end

return M
