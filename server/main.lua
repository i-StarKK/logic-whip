--[[
    logic-whip - server
    Author: StarK (Moayed)
    Team: logic
    https://github.com/i-StarKK/logic-whip
]]

local C = WhipConfig
local lastCrack, lastHit  =  {}, {}

local function HasPermission(src)
    return not C.ace or IsPlayerAceAllowed(src, C.ace)
end

local function TriggerNearby(eventName, origin, ...)
    local range = C.syncDistance + 10.0
    for _, id in ipairs(GetPlayers()) do
        local ped = GetPlayerPed(id)
        if ped ~= 0 and #(GetEntityCoords(ped) - origin) < range then
            TriggerClientEvent(eventName, id, ...)
        end
    end
end

local function IsHoldingWhip(src)
    return Player(src).state.logicWhip == true
end

RegisterCommand(C.command, function(src)
    if src <= 0 then
        return
    end
    if not HasPermission(src) then
        TriggerClientEvent('logic-whip:client:notify', src, C.text.denied)
        return
    end
    local on = not IsHoldingWhip(src)
    Player(src).state:set('logicWhip', on, true)
    TriggerClientEvent('logic-whip:client:notify', src, on and C.text.on or C.text.off)
end, false)


RegisterNetEvent('logic-whip:server:crack', function()
    local src = source
    local now = GetGameTimer()
    if not IsHoldingWhip(src) or (lastCrack[src] and now - lastCrack[src] < C.swing.cooldownMs - 150) then
        return
    end
    lastCrack[src] = now
    local ped = GetPlayerPed(src)
    if ped ~= 0 then
        TriggerNearby('logic-whip:client:cracked', GetEntityCoords(ped), src)
    end
end)


RegisterNetEvent('logic-whip:server:strike', function(target)
    local src = source
    target = tonumber(target)
    local now = GetGameTimer()
    if not target or target == src or not GetPlayerName(target) or not IsHoldingWhip(src) then
        return
    end
    if lastHit[src] and now - lastHit[src] < C.swing.cooldownMs - 150 then
        return
    end
    local a, b = GetPlayerPed(src), GetPlayerPed(target)
    if a == 0 or b == 0 or #(GetEntityCoords(a) - GetEntityCoords(b)) > C.hit.reach + 1.5 then
        return
    end
    lastHit[src] = now
    TriggerNearby('logic-whip:client:struck', GetEntityCoords(a), target, src)
end)

RegisterNetEvent('logic-whip:server:strikePed', function(netId)
    local src = source
    local now = GetGameTimer()
    netId = tonumber(netId)
    if not netId or not IsHoldingWhip(src) then
        return
    end
    if lastHit[src] and now - lastHit[src] < C.swing.cooldownMs - 150 then
        return
    end
    local a = GetPlayerPed(src)
    local victim = NetworkGetEntityFromNetworkId(netId)
    if a == 0 or victim == 0 or not DoesEntityExist(victim) or GetEntityType(victim) ~= 1 or IsPedAPlayer(victim) then
        return
    end
    local origin = GetEntityCoords(a)
    if #(origin - GetEntityCoords(victim)) > C.hit.reach + 1.5 then
        return
    end
    lastHit[src] = now
    TriggerNearby('logic-whip:client:struckPed', origin, netId, src)
end)


AddEventHandler('playerDropped', function()
    lastCrack[source] = nil
    lastHit[source] = nil
end)

CreateThread(function()
    for _, id in ipairs(GetPlayers()) do
        Player(id).state:set('logicWhip', false, true)
    end
end)

local resource = GetCurrentResourceName()
local version = GetResourceMetadata(resource, 'version', 0) or '0.0.0'

local function ParseVersion(v)
    local a, b, c = tostring(v or ''):match('(%d+)%.(%d+)%.(%d+)')
    return tonumber(a) or 0, tonumber(b) or 0, tonumber(c) or 0
end

local function IsNewerVersion(latest, current)
    local a1, b1, c1 = ParseVersion(latest)
    local a2, b2, c2 = ParseVersion(current)
    if a1 ~= a2 then
        return a1 > a2
    end
    if b1 ~= b2 then
        return b1 > b2
    end
    return c1 > c2
end

if C.checkUpdates then
    PerformHttpRequest('https://raw.githubusercontent.com/i-StarKK/logic-whip/main/version.txt', function(status, body)
        if status ~= 200 or not body then
            print('Update check failed.')
            return
        end
        local latest = body:match('%d+%.%d+%.%d+')
        if latest and IsNewerVersion(latest, version) then
            print(('Update available: v%s -> v%s  https://github.com/i-StarKK/logic-whip/releases/latest^7'):format(version, latest))
        else
            print(('Up to date (v%s).'):format(version))
        end
    end, 'GET')
end
