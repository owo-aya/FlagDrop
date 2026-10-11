-- HD2-Addon: mods/flagdrop/entry
-- F11 reaches drop-point selection; apply equipment after the player picks a point.
local ffi, bit = require('ffi'), require('bit')
ffi.cdef[[
void *flagdrop_GetModuleHandleA(const char *) __asm__("GetModuleHandleA");
short flagdrop_GetAsyncKeyState(int) __asm__("GetAsyncKeyState");
void *flagdrop_GetForegroundWindow(void) __asm__("GetForegroundWindow");
uint32_t flagdrop_GetWindowThreadProcessId(void *, uint32_t *) __asm__("GetWindowThreadProcessId");
uint32_t flagdrop_GetCurrentProcessId(void) __asm__("GetCurrentProcessId");
]]
local kernel, user = ffi.load('kernel32'), ffi.load('user32')
local game = ffi.cast('uint8_t *', kernel.flagdrop_GetModuleHandleA('game.dll'))
local process_id, focused_process = kernel.flagdrop_GetCurrentProcessId(), ffi.new('uint32_t[1]')
local function ptr(a) return ffi.cast('uint8_t **', a)[0] end
local function u32(a) return tonumber(ffi.cast('uint32_t *', a)[0]) end
local open_presenter = ffi.cast('void (*)(void *, int, void *)', game + 0x14c0350)

-- MODULES

local log = io.open(os.getenv('LOCALAPPDATA') .. '/CowboyBingus/Helldivers2/Logs/FlagDrop.log', 'w')
local function note(message) log:write(message .. '\n'); log:flush() end
local phase, held = 'idle', false
local function begin()
    note('F11: preparing fixed appearance')
    loadout.apply_ship_appearance()
    local manager = ptr(game + 0x347ce28) + 17032
    open_presenter(manager, 15, nil)
    phase = 'map'
    note('F11: appearance selection requested; opening Galactic Map')
end

local function frame(dt)
    user.flagdrop_GetWindowThreadProcessId(user.flagdrop_GetForegroundWindow(), focused_process)
    local pressed = focused_process[0] == process_id and bit.band(user.flagdrop_GetAsyncKeyState(0x7a), 0x8000) ~= 0
    if pressed and not held then begin() end
    held = pressed

    if phase == 'map' then
        local manager = ptr(game + 0x347ce28) + 17032
        if u32(manager + 12) == 15 then
            local planet = mission.start()
            note(mission.scan_info)
            phase = 'search'
            note('Planet ' .. planet .. ': searching for difficulty 10 Predator Strain / BugAcid / Spread Democracy')
        end
    elseif phase == 'search' then
        local result = mission.update(dt)
        if result then
            mission.select_mission(result)
            pod.enter()
            phase = 'pod'
            note('Selected mission ' .. result.mission_index .. '; entering Hellpod')
        end
    elseif phase == 'pod' then
        if pod.update(dt) then
            loadout.begin_equipment()
            phase = 'equipment'
            note('Drop-point selection open; waiting for the player to enter Equipment')
        end
    elseif phase == 'equipment' then
        local screen=pod.screen()
        if not screen then
            phase = 'idle'
            note('Hellpod screen closed; pending equipment selection cancelled')
        elseif loadout.step_equipment(screen, dt) then
            phase = 'idle'
            note('Equipment page detected; Sai, Ultimatum, Giga and four-stratagem native selection requested once; remaining on Equipment')
        end
    end
end

CowboyBingusModLoader.after_startup(function()
    local previous_update = update
    update = function(dt, ...)
        local result = previous_update(dt, ...)
        frame(dt)
        return result
    end
    note('FlagDrop v0.9 loaded; F11 reaches drop-point selection, then waits for Equipment')
end)
