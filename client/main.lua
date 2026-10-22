--[[
    logic-whip - client
    Author: StarK (Moayed)
    Team: logic
    https://github.com/i-StarKK/logic-whip
]]

local C = WhipConfig
local LC = C.lash
local sqrt, abs, max, min = math.sqrt, math.abs, math.max, math.min

local SetEntityMatrix = SetEntityMatrix
local GetOffsetFromEntityInWorldCoords = GetOffsetFromEntityInWorldCoords
local GetEntityCoords = GetEntityCoords
local GetFrameTime = GetFrameTime
local STEP = 1.0 / 60.0
local UNARMED = joaat('WEAPON_UNARMED')

local matOrder = nil
local loaded = {}
local whips = {}
local nextSwing, busyUntil = 0, 0
local holding = false
local equipped = false

local function ShowNotification(msg)
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(msg)
    EndTextCommandThefeedPostTicker(false, false)
end

local function LoadModel(name)
    local h = joaat(name)
    if loaded[name] then
        return h
    end
    if not IsModelInCdimage(h) then
        return nil
    end
    RequestModel(h)
    local deadline = GetGameTimer() + 8000
    while not HasModelLoaded(h) and GetGameTimer() < deadline do
        Wait(0)
    end
    if not HasModelLoaded(h) then
        return nil
    end
    loaded[name] = true
    return h
end

local function LoadAnimDict(dict)
    if HasAnimDictLoaded(dict) then
        return true
    end
    RequestAnimDict(dict)
    local deadline = GetGameTimer() + 5000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < deadline do
        Wait(0)
    end
    return HasAnimDictLoaded(dict)
end

local function SpawnLocalObject(name, pos)
    local h = LoadModel(name)
    if not h then
        return 0
    end
    local o = CreateObjectNoOffset(h, pos.x, pos.y, pos.z, false, false, false)
    if o ~= 0 then
        SetEntityCollision(o, false, false)
        FreezeEntityPosition(o, true)
        SetEntityLodDist(o, 80)
    end
    return o
end

local function DetectMatrixOrder()
    if matOrder then
        return
    end
    local o = SpawnLocalObject(C.models.handle, GetEntityCoords(PlayerPedId()))
    if o == 0 then
        return
    end
    SetEntityRotation(o, 0.0, 0.0, 90.0, 2, true)
    local a = GetEntityMatrix(o)
    matOrder = a.y > 0.5 and 'rf' or 'fr'
    DeleteEntity(o)
end

local function OrientSegment(e, ax, ay, az, bx, by, bz)
    local fx, fy, fz = bx - ax, by - ay, bz - az
    local l = sqrt(fx * fx + fy * fy + fz * fz)
    if l < 1e-6 then
        fx, fy, fz = 0.0, 0.0, -1.0
    else
        l = 1.0 / l
        fx, fy, fz = fx * l, fy * l, fz * l
    end

    local rx, ry
    if fz < 0.985 and fz > -0.985 then
        local h = 1.0 / sqrt(fx * fx + fy * fy)
        rx, ry = fy * h, -fx * h
    else
        rx, ry = 1.0, 0.0
    end

    if matOrder == 'fr' then
        SetEntityMatrix(e, fx, fy, fz, rx, ry, 0.0, ry * fz, -rx * fz, rx * fy - ry * fx, ax, ay, az)
    else
        SetEntityMatrix(e, rx, ry, 0.0, fx, fy, fz, ry * fz, -rx * fz, rx * fy - ry * fx, ax, ay, az)
    end
end

local function SolveLink(x, y, z, i, j, rest, a, b)
    local dx, dy, dz = x[j] - x[i], y[j] - y[i], z[j] - z[i]
    local d = sqrt(dx * dx + dy * dy + dz * dz)
    if d < 1e-7 then
        return
    end
    local diff = (d - rest) / d
    if a > 0.0 then
        local k = diff * a
        x[i], y[i], z[i] = x[i] + dx * k, y[i] + dy * k, z[i] + dz * k
    end
    local k = diff * b
    x[j], y[j], z[j] = x[j] - dx * k, y[j] - dy * k, z[j] - dz * k
end


local Lash = {}
Lash.__index = Lash

local function CreateLash(anchor)
    local n = #C.models.lash
    local l = setmetatable({
        n = n,
        N = n + 1,
        L = LC.pitch,
        ax = anchor.x,
        ay = anchor.y,
        az = anchor.z,
        x = {},
        y = {},
        z = {},
        px = {},
        py = {},
        pz = {},
        rx = {},
        ry = {},
        rz = {},
        lx = {},
        ly = {},
        lz = {},
        moved = {},
        ents = {},
        acc = 0.0,
        awake = true,
        still = 0,
        rest = 0,
        dirty = true,
        floor = anchor.z - 1.0,
    }, Lash)
    for i = 1, l.N do
        local z = anchor.z - LC.pitch * (i - 1)
        l.x[i], l.y[i], l.z[i] = anchor.x, anchor.y, z
        l.px[i], l.py[i], l.pz[i] = anchor.x, anchor.y, z
    end
    for i = 1, n do
        l.ents[i] = SpawnLocalObject(C.models.lash[i], anchor)
    end
    return l
end

function Lash:Destroy()
    for i = 1, #self.ents do
        if self.ents[i] ~= 0 and DoesEntityExist(self.ents[i]) then
            DeleteEntity(self.ents[i])
        end
    end
    self.ents = {}
end

function Lash:Wake()
    self.sx, self.sy, self.sz = nil, nil, nil
    self.cx, self.cy, self.cz = nil, nil, nil
    self.awake = true
    self.still = 0
    self.rest = 0
end

function Lash:SetAnchor(x, y, z)
    local dx, dy, dz = x - self.ax, y - self.ay, z - self.az
    self.anchorDelta = dx * dx + dy * dy + dz * dz
    self.ax, self.ay, self.az = x, y, z
end

function Lash:Kick(vx, vy, vz)
    for i = 2, self.N do
        local f = (i - 1) / self.n
        self.px[i] = self.px[i] - vx * f * STEP
        self.py[i] = self.py[i] - vy * f * STEP
        self.pz[i] = self.pz[i] - vz * f * STEP
    end
    self:Wake()
end

function Lash:Substep()
    local x, y, z, px, py, pz = self.x, self.y, self.z, self.px, self.py, self.pz
    local N, L = self.N, self.L
    local g = -LC.gravity * STEP * STEP
    local damp = LC.damping
    local moved = 0.0
    for i = 2, N do
        local vx, vy, vz = (x[i] - px[i]) * damp, (y[i] - py[i]) * damp, (z[i] - pz[i]) * damp
        px[i], py[i], pz[i] = x[i], y[i], z[i]
        x[i], y[i], z[i] = x[i] + vx, y[i] + vy, z[i] + vz + g
        local m = abs(vx) + abs(vy) + abs(vz)
        if m > moved then
            moved = m
        end
    end
    x[1], y[1], z[1] = self.ax, self.ay, self.az
    local floor = self.floor
    local fl = floor + 0.03
    local stiff, L2 = LC.stiffness, L * 2.0
    local halfStiff = stiff * 0.5
    local ground = floor + 0.012
    for it = 1, LC.iterations do
        SolveLink(x, y, z, 1, 2, L, 0.0, 1.0)
        for i = 2, N - 1 do
            SolveLink(x, y, z, i, i + 1, L, 0.5, 0.5)
        end
        if stiff > 0.0 and it % 2 == 1 then
            for i = 1, N - 2 do
                if z[i] > fl and z[i + 2] > fl then
                    if i == 1 then
                        SolveLink(x, y, z, i, i + 2, L2, 0.0, stiff)
                    else
                        SolveLink(x, y, z, i, i + 2, L2, halfStiff, halfStiff)
                    end
                end
            end
        end
        for i = 2, N do
            if z[i] < ground then
                z[i] = ground
                px[i] = x[i] - (x[i] - px[i]) * 0.5
                py[i] = y[i] - (y[i] - py[i]) * 0.5
            end
        end
    end
    return moved
end

function Lash:Update(dt)
    if not self.awake then
        return
    end
    if (self.anchorDelta or 0.0) < 4e-4 and (self.speed or 1.0) < 0.002 then
        self.rest = self.rest + 1
        if self.rest > 30 then
            self:Sleep()
            return
        end
    else
        self.rest = 0
    end
    self.acc = min(self.acc + dt, STEP * 4)
    local moved = 0.0
    while self.acc >= STEP do
        self.acc = self.acc - STEP
        moved = max(moved, self:Substep())
    end
    self.speed = moved
    if moved < 0.0012 then
        self.still = self.still + 1
        if self.still > LC.sleepFrames then
            self:Sleep()
        end
    else
        self.still = 0
    end
    self.dirty = true
end

function Lash:Sleep()
    self.awake = false
    self.acc = 0.0
    self.sx, self.sy, self.sz = self.ax, self.ay, self.az
end

function Lash:IsDrifted()
    if not self.sx then
        return true
    end
    local dx, dy, dz = self.ax - self.sx, self.ay - self.sy, self.az - self.sz
    local w = LC.wakeDistance
    return dx * dx + dy * dy + dz * dz > w * w
end

function Lash:Reconnect()
    local e = self.ents[1]
    local cx, cy, cz = self.cx or self.sx, self.cy or self.sy, self.cz or self.sz
    local dx, dy, dz = self.ax - cx, self.ay - cy, self.az - cz
    if dx * dx + dy * dy + dz * dz < 2.5e-5 then
        return
    end
    self.cx, self.cy, self.cz = self.ax, self.ay, self.az
    self.lx[1], self.ly[1], self.lz[1] = self.ax, self.ay, self.az
    if e and e ~= 0 then
        OrientSegment(e, self.ax, self.ay, self.az, self.rx[2], self.ry[2], self.rz[2])
    end
end

function Lash:Render()
    if not self.dirty then
        return false
    end
    self.dirty = false
    local N, L = self.N, self.L
    local x, y, z = self.rx, self.ry, self.rz
    local sx, sy, sz = self.x, self.y, self.z
    local lx, ly, lz = self.lx, self.ly, self.lz
    local moved = self.moved

    x[1], y[1], z[1] = self.ax, self.ay, self.az
    for i = 2, N do
        local px, py, pz = x[i - 1], y[i - 1], z[i - 1]
        local dx, dy, dz = sx[i] - px, sy[i] - py, sz[i] - pz
        local d = sqrt(dx * dx + dy * dy + dz * dz)
        if d > 1e-7 then
            local k = L / d
            x[i], y[i], z[i] = px + dx * k, py + dy * k, pz + dz * k
        else
            x[i], y[i], z[i] = sx[i], sy[i], sz[i]
        end
    end

    local any = false
    for i = 1, N do
        local dx, dy, dz = x[i] - (lx[i] or 1e9), y[i] - (ly[i] or 1e9), z[i] - (lz[i] or 1e9)
        local m = dx * dx + dy * dy + dz * dz > 1e-6
        moved[i] = m
        if m then
            lx[i], ly[i], lz[i] = x[i], y[i], z[i]
            any = true
        end
    end
    if not any then
        return false
    end

    local ents = self.ents
    for i = 1, #ents do
        local e = ents[i]
        if e ~= 0 and (moved[i] or moved[i + 1]) then
            OrientSegment(e, x[i], y[i], z[i], x[i + 1], y[i + 1], z[i + 1])
        end
    end
    return moved[N] or moved[N - 1]
end

local function PlayWhipSound(kind, pos, volume)
    local S   = C.sounds
    local def = S[kind]
    local cam = GetFinalRenderedCamCoord()

    if not def or #(cam - pos) > S.maxDistance then
        return
    end

    local rot = GetFinalRenderedCamRot(2)
    local rx, rz = math.rad(rot.x), math.rad(rot.z)

    SendNUIMessage({
        whipAudio = true,
        type = 'listener',
        x = cam.x,
        y = cam.y,
        z = cam.z,
        fx = -math.sin(rz) * math.cos(rx),
        fy = math.cos(rz) * math.cos(rx),
        fz = math.sin(rx),
        ux = math.sin(rz) * math.sin(rx),
        uy = -math.cos(rz) * math.sin(rx),
        uz = math.cos(rx),
    })

    SendNUIMessage({
        whipAudio = true,
        type = 'play',
        file = ('whip_%s_%d'):format(kind, math.random(def.count)),
        x = pos.x,
        y = pos.y,
        z = pos.z,
        volume = (volume or 1.0) * def.volume * S.volume,
        ref = def.ref,
        max = S.maxDistance,
        rolloff = S.rolloff,
        rate = 0.94 + math.random() * 0.12,
    })
end

local function ReadMatrix(e)
    local a, b, u, p = GetEntityMatrix(e)
    if matOrder == 'fr' then
        return b, a, u, p
    end
    return a, b, u, p
end

local function Dot(a, b)
    return a.x * b.x + a.y * b.y + a.z * b.z
end

local function GetGripFrame(w)
    local H = C.hand
    local ped = w.ped
    local wrist = GetWorldPositionOfEntityBone(ped, GetPedBoneIndex(ped, H.bone))
    local i0 = GetWorldPositionOfEntityBone(ped, GetPedBoneIndex(ped, H.index[1]))
    local i2 = GetWorldPositionOfEntityBone(ped, GetPedBoneIndex(ped, H.index[2]))
    local p0 = GetWorldPositionOfEntityBone(ped, GetPedBoneIndex(ped, H.pinky[1]))
    local p2 = GetWorldPositionOfEntityBone(ped, GetPedBoneIndex(ped, H.pinky[2]))

    local roots = (i0 + p0) / 2.0
    local tips  = (i2 + p2) / 2.0
    local axis  = i0 - p0
    local l = #axis
    if l < 1e-4 then
        return nil
    end
    axis = axis / l

    local G = C.grip
    local fwd = roots - wrist
    fwd = fwd - axis * Dot(fwd, axis)
    local fl = #fwd
    fwd = fl > 1e-4 and fwd / fl or vector3(0.0, 0.0, 1.0)

    local c = roots + (tips - roots) * G.curl + axis * G.along + fwd * G.palm
    local up = vector3(axis.y * fwd.z - axis.z * fwd.y, axis.z * fwd.x - axis.x * fwd.z, axis.x * fwd.y - axis.y * fwd.x)
    return c, axis, fwd, up
end

local function EulerYXZ(X, Y, Z)
    local sx = math.max(-1.0, math.min(1.0, Y.z))
    return math.deg(math.asin(sx)), math.deg(math.atan(-X.z, Z.z)), math.deg(math.atan(-Y.x, Y.y))
end

local function EulerXYZ(X, Y, Z)
    local sy = math.max(-1.0, math.min(1.0, -X.z))
    return math.deg(math.atan(Y.z, Z.z)), math.deg(math.asin(sy)), math.deg(math.atan(X.y, X.x))
end

local function Attach(w, bone, o, r)
    AttachEntityToEntity(w.obj, w.ped, bone, o.x, o.y, o.z, r.x, r.y, r.z, true, false, false, false, 2, true)
end

local function AttachWhipToHand(w)
    FreezeEntityPosition(w.obj, false)
    w.bone = GetPedBoneIndex(w.ped, C.hand.bone)
    Attach(w, w.bone, vector3(0.0, 0.0, 0.0), vector3(0.0, 0.0, 0.0))
    w.calibrateAt = GetGameTimer() + C.grip.delayMs
end

local function CalibrateGrip(w)
    w.calibrateAt = nil
    Attach(w, w.bone, vector3(0.0, 0.0, 0.0), vector3(0.0, 0.0, 0.0))
    Wait(0)
    Wait(0)

    local br, bf, bu, bp = ReadMatrix(w.obj)
    local c, a, f, u = GetGripFrame(w)
    if not c then
        return
    end

    local d = c - bp
    local offset = vector3(Dot(d, br), Dot(d, bf), Dot(d, bu))
    local X = vector3(Dot(a, br), Dot(a, bf), Dot(a, bu))
    local Y = vector3(Dot(f, br), Dot(f, bf), Dot(f, bu))
    local Z = vector3(Dot(u, br), Dot(u, bf), Dot(u, bu))

    local best, bestErr = nil, -1.0
    for _, solve in ipairs({ EulerYXZ, EulerXYZ }) do
        local rx, ry, rz = solve(X, Y, Z)
        local rot = vector3(rx, ry, rz)
        Attach(w, w.bone, offset, rot)
        Wait(0)
        Wait(0)
        local r2, f2 = ReadMatrix(w.obj)
        local score = Dot(r2, a) + Dot(f2, f)
        if score > bestErr then
            best, bestErr = rot, score
        end
        if score > 1.96 then
            break
        end
    end

    Attach(w, w.bone, offset, best)
end

local function GetWhipTip(w)
    return GetOffsetFromEntityInWorldCoords(w.obj, LC.tip, 0.0, 0.0)
end

local function CreateWhip(ped)
    local w = { ped = ped }
    w.obj = SpawnLocalObject(C.models.handle, GetEntityCoords(ped))
    if w.obj == 0 then
        return nil
    end
    AttachWhipToHand(w)
    local tip = GetWhipTip(w)
    w.lash = CreateLash(tip)
    w.popper = SpawnLocalObject(C.models.popper, tip)
    return w
end

local function DestroyWhip(w)
    if w.obj and DoesEntityExist(w.obj) then
        DeleteEntity(w.obj)
    end
    if w.lash then
        w.lash:Destroy()
    end
    if w.popper and w.popper ~= 0 and DoesEntityExist(w.popper) then
        DeleteEntity(w.popper)
    end
end

local function UpdateWhip(w, dt)
    local lash = w.lash
    w.frame = (w.frame or 0) + 1

    if w.calibrateAt and GetGameTimer() >= w.calibrateAt then
        CalibrateGrip(w)
        lash:Wake()
    end

    local tip = GetWhipTip(w)
    lash:SetAnchor(tip.x, tip.y, tip.z)

    if not lash.awake then
        local pos = GetEntityCoords(w.ped)
        local rp = w.restPos
        local dh = rp and abs((GetEntityHeading(w.ped) - w.restHeading + 180.0) % 360.0 - 180.0) or 999.0
        local bodyMoved = not rp or #(pos - rp) > 0.08 or dh > 6.0
        if bodyMoved or lash:IsDrifted() then
            w.restPos = nil
            lash:Wake()
        else
            lash:Reconnect()
            return
        end
    end

    if w.frame % 10 == 0 or not w.floorSet then
        w.floorSet = true
        lash.floor = GetEntityCoords(w.ped).z - 0.98
    end
    lash:Update(dt)
    if not lash.awake then
        w.restPos = GetEntityCoords(w.ped)
        w.restHeading = GetEntityHeading(w.ped)
    end
    if lash:Render() and w.popper ~= 0 then
        local N = lash.N
        local x, y, z = lash.rx[N], lash.ry[N], lash.rz[N]
        OrientSegment(w.popper, x, y, z, x + (x - lash.rx[N - 1]), y + (y - lash.ry[N - 1]), z + (z - lash.rz[N - 1]))
    end
end

local function CrackWhip(ped, silent)
    local w = whips[ped]
    if w then
        local f = GetEntityForwardVector(ped)
        w.lash:Kick(f.x * 7.0, f.y * 7.0, -4.0)
    end
    if not silent then
        PlayWhipSound('crack', GetEntityCoords(ped) + GetEntityForwardVector(ped) * 1.2, 1.0)
    end
end

local function GetNearbyHolders(origin)
    local list = {}
    for _, pl in ipairs(GetActivePlayers()) do
        local ped = GetPlayerPed(pl)
        if ped ~= 0 and #(GetEntityCoords(ped) - origin) < C.syncDistance then
            local st = Player(GetPlayerServerId(pl)).state
            if st and st.logicWhip and not IsPedInAnyVehicle(ped, false) and not IsEntityDead(ped) then
                list[ped] = true
            end
        end
    end
    return list
end


local function GetHitReaction(victim, attacker)
    local R = C.hit.reactions
    local d = GetEntityCoords(attacker) - GetEntityCoords(victim)
    local f = GetEntityForwardVector(victim)
    local fwd = d.x * f.x + d.y * f.y
    local side = d.x * f.y - d.y * f.x
    if abs(fwd) >= abs(side) then
        return fwd >= 0.0 and R.front or R.back
    end
    return side >= 0.0 and R.right or R.left
end

local function PlayHitReaction(victim, attacker)
    local r = GetHitReaction(victim, attacker)
    if LoadAnimDict(r.dict) then
        TaskPlayAnim(victim, r.dict, r.clip, 8.0, -4.0, -1, 48, 0.0, false, false, false)
    end
    if C.hit.damage > 0 then
        ApplyDamageToPed(victim, C.hit.damage, false)
    end
end

local blood = {}

local function ApplyHitEffects(victim)
    PlayWhipSound('hit', GetPedBoneCoords(victim, 24817, 0.0, 0.0, 0.0), 1.0)
    if C.hit.bloodPack then
        blood[victim] = (blood[victim] or 0) + C.hit.bloodPerHit
        ApplyPedDamagePack(victim, C.hit.bloodPack, math.min(1.0, blood[victim]), 1.0)
    end
end

local function FindStrikeTarget(ped)
    local pos = GetEntityCoords(ped)
    local fwd = GetEntityForwardVector(ped)
    local reach = C.hit.reach
    local best, bd = nil, reach * reach
    local peds = GetGamePool('CPed')
    for i = 1, #peds do
        local other = peds[i]
        if other ~= ped then
            local o = GetEntityCoords(other)
            local dx, dy, dz = o.x - pos.x, o.y - pos.y, o.z - pos.z
            local d2 = dx * dx + dy * dy + dz * dz
            if d2 < bd and d2 > 0.0025 and (dx * fwd.x + dy * fwd.y) > 0.4 * sqrt(d2) and not IsEntityDead(other) then
                best, bd = other, d2
            end
        end
    end
    return best
end

local function SwingWhip()
    local now = GetGameTimer()
    local S = C.swing
    if now < nextSwing then
        return
    end
    nextSwing = now + S.cooldownMs
    busyUntil = now + S.durationMs
    local ped = PlayerPedId()
    if LoadAnimDict(S.dict) then
        TaskPlayAnim(ped, S.dict, S.clip, 8.0, -4.0, S.durationMs, S.flag, 0.0, false, false, false)
    end
    SetTimeout(S.hitMs, function()
        local target = FindStrikeTarget(ped)
        CrackWhip(ped, target ~= nil)
        if not target then
            TriggerServerEvent('logic-whip:server:crack')
            return
        end
        if IsPedAPlayer(target) then
            TriggerServerEvent('logic-whip:server:strike', GetPlayerServerId(NetworkGetPlayerIndexFromPed(target)))
        elseif NetworkGetEntityIsNetworked(target) then
            TriggerServerEvent('logic-whip:server:strikePed', PedToNet(target))
        else
            ApplyHitEffects(target)
            PlayHitReaction(target, ped)
            TriggerServerEvent('logic-whip:server:crack')
        end
    end)
end

local function UpdateHoldPose(ped, equipped)
    local H = C.hold
    local want = equipped
        and GetGameTimer() > busyUntil
        and not IsPedInAnyVehicle(ped, false)
        and not IsPedRagdoll(ped)
    if want then
        if not IsEntityPlayingAnim(ped, H.dict, H.clip, 3) and LoadAnimDict(H.dict) then
            TaskPlayAnim(ped, H.dict, H.clip, 4.0, -4.0, -1, H.flag, 0.0, false, false, false)
        end
        holding = true
    elseif holding then
        holding = false
        if IsEntityPlayingAnim(ped, H.dict, H.clip, 3) then
            StopAnimTask(ped, H.dict, H.clip, 2.0)
        end
    end
end


local DISABLE_MELEE_FLAG = 122
local canSwing = false
local meleeBlocked = false

local function SetMeleeBlocked(ped, state)
    if meleeBlocked ~= state then
        meleeBlocked = state
        SetPedConfigFlag(ped, DISABLE_MELEE_FLAG, state)
    end
end

RegisterCommand('+logic_whip_crack', function()
    if canSwing and equipped and not IsPauseMenuActive() then
        CreateThread(SwingWhip)
    end
end, false)

RegisterCommand('-logic_whip_crack', function() end, false)

RegisterKeyMapping('+logic_whip_crack', 'Whip: crack', 'MOUSE_BUTTON', 'MOUSE_LEFT')

CreateThread(function()
    local lastPed = 0
    while true do
        local ped = PlayerPedId()

        if ped ~= lastPed then
            lastPed = ped
            meleeBlocked = nil
        end

        if equipped or holding then
            UpdateHoldPose(ped, equipped)
            if equipped and GetSelectedPedWeapon(ped) ~= UNARMED then
                SetCurrentPedWeapon(ped, UNARMED, true)
            end
        end

        SetMeleeBlocked(ped, equipped)
        canSwing = equipped and not IsPedInAnyVehicle(ped, false)
        Wait(equipped and 250 or 500)
    end
end)

CreateThread(function()
    local lastScan = 0
    while true do
        local now = GetGameTimer()
        if now - lastScan > 300 then
            lastScan = now
            local list = GetNearbyHolders(GetEntityCoords(PlayerPedId()))
            if next(list) then
                DetectMatrixOrder()
            end
            for ped in pairs(list) do
                if not whips[ped] then
                    whips[ped] = CreateWhip(ped)
                end
            end
            for ped, w in pairs(whips) do
                if not list[ped] or not DoesEntityExist(ped) or not DoesEntityExist(w.obj) then
                    DestroyWhip(w)
                    whips[ped] = nil
                end
            end
        end

        local awake = false
        if next(whips) then
            local dt = GetFrameTime()
            for _, w in pairs(whips) do
                UpdateWhip(w, dt)
                if w.lash.awake then
                    awake = true
                end
            end
        end

        if awake then
            Wait(0)
        elseif next(whips) then
            Wait(50)
        else
            Wait(300)
        end
    end
end)

AddStateBagChangeHandler('logicWhip', ('player:%d'):format(GetPlayerServerId(PlayerId())), function(_, _, value)
    equipped = value == true
end)

CreateThread(function()
    equipped = LocalPlayer.state.logicWhip == true
end)

RegisterNetEvent('logic-whip:client:notify', function(msg)
    ShowNotification(msg)
end)

RegisterNetEvent('logic-whip:client:cracked', function(sid)
    if sid == GetPlayerServerId(PlayerId()) then
        return
    end
    local pl = GetPlayerFromServerId(sid)
    if pl ~= -1 then
        CrackWhip(GetPlayerPed(pl), false)
    end
end)

RegisterNetEvent('logic-whip:client:struck', function(victimSid, attackerSid)
    local vp, ap = GetPlayerFromServerId(victimSid), GetPlayerFromServerId(attackerSid)
    if vp == -1 then
        return
    end
    local victim = GetPlayerPed(vp)
    ApplyHitEffects(victim)
    if ap ~= -1 and attackerSid ~= GetPlayerServerId(PlayerId()) then
        CrackWhip(GetPlayerPed(ap), true)
    end
    if victimSid == GetPlayerServerId(PlayerId()) then
        if ap ~= -1 then
            PlayHitReaction(victim, GetPlayerPed(ap))
        end
        ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', C.hit.shake)
    end
end)

RegisterNetEvent('logic-whip:client:struckPed', function(netId, attackerSid)
    if not NetworkDoesNetworkIdExist(netId) then
        return
    end
    local victim = NetToPed(netId)
    if victim == 0 or not DoesEntityExist(victim) then
        return
    end
    ApplyHitEffects(victim)
    local ap = GetPlayerFromServerId(attackerSid)
    if ap == -1 then
        return
    end
    local attacker = GetPlayerPed(ap)
    if attackerSid ~= GetPlayerServerId(PlayerId()) then
        CrackWhip(attacker, true)
    end
    if NetworkHasControlOfEntity(victim) then
        PlayHitReaction(victim, attacker)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then
        return
    end

    for _, w in pairs(whips) do
        DestroyWhip(w)
    end

    if holding then
        StopAnimTask(PlayerPedId(), C.hold.dict, C.hold.clip, 2.0)
    end

    if meleeBlocked then
        SetPedConfigFlag(PlayerPedId(), DISABLE_MELEE_FLAG, false)
    end
end)
