local ffi = require('ffi')

ffi.cdef [[
void *FlagDropLoadout_GetModuleHandleA(const char *name) __asm__("GetModuleHandleA");
]]

local game = ffi.cast('uint8_t *', ffi.C.FlagDropLoadout_GetModuleHandleA('game.dll'))
local M = {}

local function pointer(address)
    return ffi.cast('uint8_t **', address)[0]
end

local function set32(address, value)
    ffi.cast('uint32_t *', address)[0] = value
end

-- DiverKit's weapon category/slot arguments match the current game's
-- selector at 0x146E7E7..0x146E849. IDs are LoadoutEntryComponentData IDs.
local WEAPONS = {
    {category = 1, slot = 1, id = 0xF47A207A}, -- LAS-12 Sai
    {category = 3, slot = 2, id = 0x335B8A1A}, -- GP-20 Ultimatum
    {category = 4, slot = 4, id = 0x0B4761B8}, -- G-48 Giga Grenade
}

-- FileDiver LoadoutEntryComponentData: item id +0, item type +4.
-- Sources: its current generated_entities.dl_bin, named by each weapon's
-- actual entity resource (record 129/152/5 respectively).
local STRATAGEMS = {
    875551083,  -- AC-8 Autocannon
    1560416221, -- Orbital Airburst Strike
    3523620028, -- Orbital Precision Strike
    2084654169, -- Orbital Gatling Barrage
}

-- OneClickArmorSet/NOTES.md: the native Armory whole-loadout applier
-- receives a 0x2C-byte appearance block and the local player id, applies
-- the game's armor setters, copies it to saved settings +0x14C and saves.
local apply_appearance = ffi.cast('void (*)(const void *, uint32_t)', game + 0x18DD650)

-- Call aboard the ship before opening the Hellpod briefing.
function M.apply_ship_appearance()
    local settings = pointer(game + 0x347CDD8)
    local appearance = ffi.new('uint8_t[0x2C]')
    ffi.copy(appearance, settings + 0x14C, 0x2C)
    set32(appearance + 0x04, 0xD270FCCC) -- UF-16 Inspector helmet
    set32(appearance + 0x08, 0x7757D8E8) -- Protector of the Heart cape
    set32(appearance + 0x0C, 0x1C6C05FA) -- CM-09 Bonesnapper, Med-Kit

    local players = pointer(game + 0x3326468)
    local player = ffi.cast('uint32_t *', pointer(players + 0xE8) + 8)[0]
    apply_appearance(appearance, player)
end

-- DiverKit v12's actual selection path, mapped to build 25480438:
-- select weapons into the live payload, set the four stratagem widgets,
-- rebuild/broadcast their bound payload, save, refresh.
-- Current UI call at 0x146E80C targets 0x1365EF0 with these five arguments.
local set_weapon = ffi.cast('void (*)(void *, void *, uint32_t, uint32_t, uint32_t)', game + 0x1365EF0)
local set_stratagem = ffi.cast('void (*)(void *, uint32_t, uint32_t)', game + 0x189D050)
local rebuild_stratagems = ffi.cast('void (*)(void *, uint64_t)', game + 0x189D120)
local save_loadout = ffi.cast('void (*)(void *)', game + 0x1751350)
local refresh_card = ffi.cast('void (*)(void *, void *, bool, bool)', game + 0x189C780)

function M.equipment_context(screen)
    local index = tonumber(ffi.cast('uint32_t *', screen + 0x27D0)[0])
    local payload = screen + 0x10 + index * 0x9F0
    for visual_slot = 0, 3 do
        local candidate = screen + 0x53A78 + visual_slot * 0x1EE18
        if pointer(candidate + 0x1EDF0) == payload
            and tonumber(ffi.cast('uint32_t *', candidate + 0x1EDFC)[0]) == index then
            return candidate, payload
        end
    end
end

function M.apply_equipment(screen, card, payload)
    for _, weapon in ipairs(WEAPONS) do
        set_weapon(screen, payload, weapon.category, weapon.slot, weapon.id)
    end
    for slot, id in ipairs(STRATAGEMS) do
        set_stratagem(card, slot - 1, id)
    end
    rebuild_stratagems(card, ffi.cast('uint64_t', -1))
    save_loadout(payload)
    local mode = card[0x1EE0E] ~= 0
    refresh_card(card, payload, true, mode)
end

local equipment_time = 0
function M.begin_equipment()
    equipment_time = 0
end

function M.step_equipment(screen, dt)
    -- DiverKit Screen.identity: view 1 is Equipment; these two bytes mark
    -- a page transition or an open equipment selector. The player chooses
    -- the landing point and lets the game enter Equipment normally.
    local view = tonumber(ffi.cast('uint32_t *', screen + 8)[0])
    if view ~= 1 or screen[0x2808] ~= 0 or screen[0x273990] ~= 0 then
        equipment_time = 0
        return false
    end
    -- DiverKit's automatic preset waits one second on the Equipment page.
    equipment_time = equipment_time + dt
    if equipment_time < 1 then return false end
    local card, payload = M.equipment_context(screen)
    if not card or card[0x1EE0C] == 0 then return false end
    local opacity = ffi.cast('float *', card + 0x1B820 + 84)[0]
    if opacity < 0.995 then return false end
    M.apply_equipment(screen, card, payload)
    return true
end

return M
