-- Build 25480438. Native board flow and enemy draws from MissionReroller.
-- https://github.com/lombax5832/MissionReroller
local ffi, bit = require('ffi'), require('bit')
ffi.cdef[[void *flagdrop_mission_GetModuleHandleA(const char *) __asm__("GetModuleHandleA");]]
local game = ffi.cast('uint8_t *', ffi.load('kernel32').flagdrop_mission_GetModuleHandleA('game.dll'))
local M = {state='idle', rerolls=0}
local function ptr(a) return ffi.cast('uint8_t **',a)[0] end
local function u32(a) return tonumber(ffi.cast('uint32_t *',a)[0]) end
local function u16(a) return tonumber(ffi.cast('uint16_t *',a)[0]) end
local function f32(a) return tonumber(ffi.cast('float *',a)[0]) end
local function put32(a,v) ffi.cast('uint32_t *',a)[0]=v end
local function board() return ptr(game+0x347cee8) end
local function ui() return ptr(game+0x3326aa0) end
local refresh = ffi.cast('void (*)(void *, uint8_t, uint8_t, uint8_t)',game+0x12d5670)
local view_planet = ffi.cast('void (*)(uintptr_t, uint32_t)',game+0x12d1cd0)
local select_operation = ffi.cast('void (*)(uintptr_t, uint32_t)',game+0x12d1d40)
-- The eight argument slots are read directly by 0x12d18f0.
local select_campaign_row = ffi.cast('uint8_t (*)(void *, uint32_t, uint32_t, uint32_t, int32_t, int32_t, uint8_t, uint64_t)',game+0x12d18f0)
local close_galactic_map = ffi.cast('void (*)(void)',game+0x148f090)
local spread_democracy = {[28]=true,[55]=true,[85]=true,[135]=true}
local scalar = ffi.new('float[1]')
local function single(n) scalar[0]=n;return tonumber(scalar[0]) end
local planet, pending_seed, matched
local campaign_cache, disabled_cache = {}, {}

-- Native configuration path folding, used to read disabled enemy types.
local function mul32(a,b) return tonumber(ffi.cast('uint32_t',ffi.new('uint64_t',a)*b)) end
local function configuration_key(words)
    local value=words[1]
    for i=2,#words do
        local k=mul32(words[i],0x5bd1e995)
        value=bit.bxor(mul32(value,0x5bd1e995),mul32(bit.bxor(bit.rshift(k,24),k)%4294967296,0x5bd1e995))%4294967296
    end
    return value
end
local function disabled(tag)
    if disabled_cache[tag]~=nil then return disabled_cache[tag] end
    local key=configuration_key({0xe165f457,0xec4e3719,u32(game+0x21e1920+tag*4)})
    local manager=ptr(game+0x347cdf8)
    for _,offset in ipairs({0x12078,0xc050}) do
        local map=manager+offset
        local capacity=u32(map+8)
        if capacity~=0 then
            local data,empty,start=ptr(map),u32(map+12),mul32(u32(map+16),key)
            for probe=0,capacity-1 do
                local found=u32(data+((start+probe)%capacity)*48)
                if found==key then disabled_cache[tag]=true;return true end
                if found==empty then break end
            end
        end
    end
    disabled_cache[tag]=false
    return false
end

local function campaign_tags(b,p,operation)
    local key=p..':'..operation
    if campaign_cache[key] then return campaign_cache[key] end
    local campaign=b+0x101438
    local manager=ptr(game+0x347cd98)
    local definitions,by_id,by_value=u32(manager+0xd000),{},{}
    local native_tags={}
    for tag=0,31 do native_tags[u32(game+0x21e1920+tag*4)]=tag end
    for i=0,definitions-1 do
        local row=manager+i*52
        local value=u32(row+8)
        if by_value[value]==nil then by_value[value]=u32(row) end
        if u32(row+4)==40 and u32(row+24)==13 then
            by_id[u32(row)]=native_tags[u32(row+28)]
        end
    end
    local tags={}
    local function add(id) local tag=by_id[id];if tag then tags[tag]=true end end
    for i=0,u32(campaign+0x78d14)-1 do
        local row=campaign+0x78c68+i*44
        if u32(row)==p then for j=0,u32(row+36)-1 do add(u32(row+4+j*4)) end end
    end
    local stats=campaign+p*0x130
    for i=0,u32(stats+0x46168)-1 do add(u32(stats+0x460e8+i*4)) end
    local definition=campaign+p*0x118
    for i=0,u32(definition+0xc8)-1 do add(u32(definition+0xb8+i*4)) end
    if operation~=4294967295 then
        for i=0,u32(campaign+0x26018)-1 do
            local binding=campaign+0x23018+i*24
            if u32(binding)==p and u32(binding+4)==operation then
                local template_id=u32(binding+8)
                local ids,values=ptr(b+0x1f8910),ptr(b+0x1f8908)
                for j=0,u32(b+0x1f8918)-1 do
                    if u32(ids+j*4)==template_id then
                        local template=ptr(values+j*8)
                        local modifiers=ptr(template+0x58)
                        for k=0,u32(template+0x60)-1 do
                            local id=by_value[u32(modifiers+k*4)]
                            if id then add(id) end
                        end
                        break
                    end
                end
                break
            end
        end
    end
    for i=0,u32(campaign+0x77a58)-1 do
        local event=campaign+0x72c58+i*0x9c0
        local count,applies=u32(event+0x9b0),false
        if count==0 then applies=true end
        for j=0,count-1 do if u32(event+0x930+j*4)==p then applies=true end end
        if applies then for j=0,u32(event+0x92c)-1 do add(u32(event+0x920+j*4)) end end
    end
    local dynamic=campaign+0x46020+p*0x130
    local faction,region=u32(dynamic+0x24),u32(dynamic+0x40)
    local globals=ptr(game+0x346d518)
    for i=0,31 do
        local row=globals+i*356
        local scope,value,filter=row[0x54],u32(row+0x58),u32(row+0x5c)
        local applies=scope==3 or scope==0 and value==p or scope==1 and value==region or scope==2 and value==faction
        if applies and (filter==0 or filter==faction) then
            for j=0,u32(row+0x50)-1 do
                local entry=row+j*16
                if entry[0]==17 then tags[u32(entry+4)]=true end
            end
        end
    end
    campaign_cache[key]=tags
    return tags
end

local function mission_tags(b,operation,mission)
    local p,kind=u16(operation+16),u32(mission+48)
    local effect=4294967295
    local category=u32(operation+28)
    if category<14 and (game+0x32e98e0+category*168)[9]~=0 then effect=operation[24] end
    local tags={}
    for tag in pairs(campaign_tags(b,p,effect)) do tags[tag]=true end
    local config=game+0x3773420+kind*896
    local faction=u32(config+8)
    local difficulty=game+0x328d2a0+9*816
    local first=0x114+(faction-2)*0x60
    local fallback=0x234+(faction-2)*0x24
    local pool,total,empty={},0,next(tags)==nil
    for i=0,7 do
        local row=difficulty+first+i*12
        local tag,weight=u32(row),f32(row+4)
        if tag~=0 and (row[8]==0 or empty) then
            pool[#pool+1]={tag=tag,weight=weight};total=single(total+weight)
        end
    end
    local state=ffi.new('uint64_t',u32(mission+52))
    for _=1,u32(difficulty+0x110) do
        if #pool==0 or total<=0 then break end
        state=state*6364136223846793005ULL+1442695040888963407ULL
        local target=single(single(single(tonumber(bit.rshift(state,32)))*single(1/4294967296))*total)
        local sum=0
        for _,row in ipairs(pool) do
            sum=single(sum+row.weight)
            if target<=sum then tags[row.tag]=true;break end
        end
    end
    local fallback_tag=u32(difficulty+fallback+32)
    local use_fallback=fallback_tag~=0 and not tags[fallback_tag]
    for i=0,7 do
        local blocker=u32(difficulty+fallback+i*4)
        if blocker==0 then break end
        if tags[blocker] then use_fallback=false end
    end
    if use_fallback then tags[fallback_tag]=true end
    for i=0,7 do
        local excluded=u32(config+0x14+i*4)
        if excluded==0 then break end
        tags[excluded]=nil
    end
    for tag in pairs(tags) do if disabled(tag) then tags[tag]=nil end end
    return tags
end

local function find_match(b)
    local operations,missions=b+0xf7280,b+0xf9a10
    for row=0,109 do
        local operation=operations+row*92
        if operation[52]~=0 and operation[32]==10 and u16(operation+16)==planet and u32(operation+36)==2 then
            for slot=0,operation[88]-1 do
                local index=operation[85+slot]
                local mission=missions+index*76
                local kind=u32(mission+48)
                if spread_democracy[kind] then
                    local tags=mission_tags(b,operation,mission)
                    if tags[2] and tags[9] then
                        return {planet=planet,row=row,mission_index=index,slot=slot,kind=kind,level_index=u32(mission+44),
                            seed=u32(mission+52),difficulty=u32(mission+60)}
                    end
                end
            end
        end
    end
end

function M.start()
    planet=171 -- GACRUX / 十字架一
    M.scan_info='Target: GACRUX (171)'
    local map=ui()
    put32(map+0x4ef8,planet)
    put32(map+0x4f14,10)
    put32(map+0x4f00,4294967295)
    put32(map+0x4f04,4294967295)
    view_planet(0,planet)
    campaign_cache,disabled_cache={},{}
    pending_seed,matched=nil,nil
    M.state,M.rerolls,M.match='searching',0,nil
    return planet
end

function M.select_mission(result)
    -- The normal Galactic UI path at 0x148f45f uses the mission's level
    -- index (+44) and difficulty (+60). Both planet words become its planet.
    local map=ui()
    put32(map+0x4f08,result.level_index)
    put32(map+0x4f0c,4294967295)
    select_campaign_row(board(),result.planet,result.planet,result.row,
        result.level_index,result.difficulty,0,0)
    -- The same UI path ends at 0x148f83c with this no-argument wrapper.
    -- It releases the Galactic UI; ordinary selection/FTL updates continue.
    close_galactic_map()
    M.state='selected'
end

function M.update(dt)
    if M.state~='searching' and M.state~='selecting' then return end
    local b=board()
    -- Owner replication and board generation finish on later game updates.
    if pending_seed and u32(b+0x17a2bc)~=pending_seed then return end
    if u32(b+0xf9a08)~=planet or b[0xf9a0c]~=0 or u32(b+0xffc0c)~=planet then return end
    if M.state=='selecting' then
        if u32(ui()+0x4f98)==matched.row then
            M.state,M.match='matched',matched
            return matched
        end
        return
    end
    pending_seed=nil
    local found=find_match(b)
    if found then
        matched=found
        put32(ui()+0x4f00,found.row)
        put32(ui()+0x4f04,4294967295)
        select_operation(0,found.row)
        M.state='selecting'
        return
    end
    local backend=ptr(game+0x347cee0)
    if u32(backend+0x31c48)~=0 then return end
    refresh(b,1,0,0)
    pending_seed=u32(b+0x78e84)
    M.rerolls=M.rerolls+1
end

return M
