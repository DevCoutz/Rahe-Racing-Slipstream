--[[
    rahe-slipstream | client.lua
    Slipstream/Drafting system for FiveM races.
    Detects when a player is behind another racer and applies a speed boost.
    Only active during rahe-racing races.
]]

local cfg = SlipstreamConfig

-------------------------------------------------
-- STATE
-------------------------------------------------

local isInRace = false                  -- Is the local player currently in a race?
local racerServerIds = {}               -- List of server IDs of other racers
local slipstreamCharge = 0.0            -- Current charge level (0.0 to 1.0)
local isInSlipstream = false            -- Currently in someone's slipstream?
local residualTimer = 0.0               -- Time remaining for residual boost
local slipstreamTarget = nil            -- Entity of the vehicle we're drafting

-------------------------------------------------
-- RAHE-RACING INTEGRATION (Event Listeners)
-------------------------------------------------

-- Server tells us our race state changed
RegisterNetEvent('rahe-slipstream:client:raceStateChanged', function(racing)
    isInRace = racing
    if not racing then
        -- Reset all slipstream state
        slipstreamCharge = 0.0
        isInSlipstream = false
        residualTimer = 0.0
        slipstreamTarget = nil
        StopScreenEffect('RaceTurbo')
    end
end)

-- Server sends updated racer list
RegisterNetEvent('rahe-slipstream:client:updateRacers', function(participants)
    racerServerIds = participants or {}
end)

-- Listen to rahe-racing checkpoint event as a secondary trigger
AddEventHandler('rahe-racing:client:checkpointPassed', function()
    -- If we're receiving checkpoint events, we're definitely in a race
    if not isInRace then
        isInRace = true
        TriggerServerEvent('rahe-slipstream:server:amIRacing')
    end
end)

-- Periodically sync with server as a fallback
CreateThread(function()
    while true do
        Wait(cfg.syncInterval)
        if isInRace then
            TriggerServerEvent('rahe-slipstream:server:amIRacing')
        end
    end
end)

-------------------------------------------------
-- UTILITY FUNCTIONS
-------------------------------------------------

-- Convert speed from m/s to km/h
local function msToKmh(speed)
    return speed * 3.6
end

-- Get the forward vector of an entity (normalized, horizontal only)
local function getEntityForwardVector(entity)
    local heading = GetEntityHeading(entity)
    local rad = math.rad(heading)
    return vector3(-math.sin(rad), math.cos(rad), 0.0)
end

-- Check if a position is within the slipstream cone behind a target vehicle
local function isInDraftingCone(myPos, targetEntity)
    local targetPos = GetEntityCoords(targetEntity)
    local targetForward = getEntityForwardVector(targetEntity)

    -- Vector from target to us
    local toUs = myPos - targetPos
    local dist = #(vector2(toUs.x, toUs.y))

    -- Check distance bounds
    if dist < cfg.minDistance or dist > cfg.maxDistance then
        return false, dist
    end

    -- Normalize the horizontal vector
    local toUsNorm = vector2(toUs.x, toUs.y) / dist

    -- The "behind" direction is the negative forward vector
    local behindDir = vector2(-targetForward.x, -targetForward.y)

    -- Dot product to check angle
    local dot = toUsNorm.x * behindDir.x + toUsNorm.y * behindDir.y

    -- Convert cone angle to dot product threshold
    local angleThreshold = math.cos(math.rad(cfg.coneAngle))

    if dot >= angleThreshold then
        return true, dist
    end

    return false, dist
end

-- Get all vehicle entities belonging to other racers
local function getRacerVehicles()
    local vehicles = {}
    local myId = PlayerId()
    local myServerId = GetPlayerServerId(myId)

    for _, serverId in ipairs(racerServerIds) do
        if serverId ~= myServerId then
            local player = GetPlayerFromServerId(serverId)
            if player and player ~= -1 then
                local ped = GetPlayerPed(player)
                if ped and DoesEntityExist(ped) and IsPedInAnyVehicle(ped, false) then
                    local vehicle = GetVehiclePedIsIn(ped, false)
                    if vehicle and DoesEntityExist(vehicle) then
                        table.insert(vehicles, vehicle)
                    end
                end
            end
        end
    end

    return vehicles
end

-------------------------------------------------
-- VISUAL EFFECTS
-------------------------------------------------

local function startScreenEffect()
    if cfg.screenEffectIntensity > 0 and not IsScreenEffectActive('RaceTurbo') then
        StartScreenEffect('RaceTurbo', 0, true)
    end
end

local function stopScreenEffect()
    if IsScreenEffectActive('RaceTurbo') then
        StopScreenEffect('RaceTurbo')
    end
end

-- Draw the slipstream charge bar on the HUD
local function drawSlipstreamHUD(charge)
    if not cfg.enableHUD then return end

    local x = cfg.hudX
    local y = cfg.hudY

    local barWidth = 0.12
    local barHeight = 0.012

    -- Background
    DrawRect(x, y, barWidth + 0.004, barHeight + 0.006, 0, 0, 0, 150)

    -- Empty bar
    local ce = cfg.hudColorEmpty
    DrawRect(x, y, barWidth, barHeight, ce.r, ce.g, ce.b, ce.a)

    -- Filled portion
    if charge > 0.0 then
        local cf = cfg.hudColorFull
        local filledWidth = barWidth * charge
        local filledX = x - (barWidth / 2) + (filledWidth / 2)

        -- Interpolate color from empty to full
        local r = math.floor(ce.r + (cf.r - ce.r) * charge)
        local g = math.floor(ce.g + (cf.g - ce.g) * charge)
        local b = math.floor(ce.b + (cf.b - ce.b) * charge)
        local a = math.floor(ce.a + (cf.a - ce.a) * charge)

        DrawRect(filledX, y, filledWidth, barHeight, r, g, b, a)
    end

    -- Label text
    if charge > 0.0 then
        SetTextFont(4)
        SetTextScale(0.0, 0.28)
        SetTextColour(255, 255, 255, 200)
        SetTextCentre(true)
        SetTextOutline()
        SetTextEntry('STRING')
        AddTextComponentString('SLIPSTREAM')
        DrawText(x, y - 0.025)
    end
end

-------------------------------------------------
-- DEBUG DRAWING
-------------------------------------------------

local function drawDebugInfo(myPos, targetVehicle, inCone, dist, charge)
    if not cfg.debug then return end

    local targetPos = GetEntityCoords(targetVehicle)

    -- Draw line to target (green = in cone, red = out of cone)
    if inCone then
        DrawLine(myPos.x, myPos.y, myPos.z, targetPos.x, targetPos.y, targetPos.z, 0, 255, 0, 255)
    else
        DrawLine(myPos.x, myPos.y, myPos.z, targetPos.x, targetPos.y, targetPos.z, 255, 0, 0, 100)
    end

    -- Draw cone direction line
    local targetForward = getEntityForwardVector(targetVehicle)
    local behindDir = vector3(-targetForward.x, -targetForward.y, 0.0)
    local coneEnd = targetPos + behindDir * cfg.maxDistance

    DrawLine(targetPos.x, targetPos.y, targetPos.z + 1.0,
             coneEnd.x, coneEnd.y, coneEnd.z + 1.0,
             0, 200, 255, 150)

    -- Debug text overlay
    SetTextFont(0)
    SetTextScale(0.0, 0.35)
    SetTextColour(255, 255, 255, 255)
    SetTextOutline()
    SetTextEntry('STRING')
    AddTextComponentString(string.format('DIST: %.1fm | CHARGE: %.0f%% | %s',
        dist, charge * 100, inCone and '~g~IN CONE' or '~r~OUT'))
    DrawText(0.35, 0.05)
end

-------------------------------------------------
-- MAIN SLIPSTREAM TICK
-------------------------------------------------

CreateThread(function()
    while true do
        -- Sleep when not in a race to save performance
        if not isInRace then
            Wait(500)
            goto continue
        end

        Wait(cfg.tickInterval)

        local playerPed = PlayerPedId()

        -- Player must be in a vehicle
        if not IsPedInAnyVehicle(playerPed, false) then
            slipstreamCharge = 0.0
            isInSlipstream = false
            stopScreenEffect()
            goto continue
        end

        local myVehicle = GetVehiclePedIsIn(playerPed, false)
        if not myVehicle or not DoesEntityExist(myVehicle) then
            goto continue
        end

        -- Player must be the driver
        if GetPedInVehicleSeat(myVehicle, -1) ~= playerPed then
            goto continue
        end

        local mySpeed = msToKmh(GetEntitySpeed(myVehicle))

        -- Speed must be above the minimum threshold
        if mySpeed < cfg.minSpeed then
            slipstreamCharge = math.max(0.0, slipstreamCharge - GetFrameTime() * 2.0)
            if slipstreamCharge <= 0 then
                isInSlipstream = false
                stopScreenEffect()
            end
            drawSlipstreamHUD(slipstreamCharge)
            goto continue
        end

        local myPos = GetEntityCoords(myVehicle)
        local racerVehicles = getRacerVehicles()

        -- Find the best slipstream target among all other racers
        local bestInCone = false
        local bestDist = cfg.maxDistance + 1
        local bestTarget = nil

        for _, otherVehicle in ipairs(racerVehicles) do
            local inCone, dist = isInDraftingCone(myPos, otherVehicle)

            if cfg.debug then
                drawDebugInfo(myPos, otherVehicle, inCone, dist, slipstreamCharge)
            end

            if inCone and dist < bestDist then
                -- Also check that the target is actually moving (not parked)
                local targetSpeed = msToKmh(GetEntitySpeed(otherVehicle))
                if targetSpeed > cfg.minSpeed * 0.5 then
                    bestInCone = true
                    bestDist = dist
                    bestTarget = otherVehicle
                end
            end
        end

        local dt = GetFrameTime()

        if bestInCone and bestTarget then
            -- We're in someone's slipstream
            isInSlipstream = true
            slipstreamTarget = bestTarget
            residualTimer = cfg.residualDuration

            -- Charge up the slipstream over time
            slipstreamCharge = math.min(1.0, slipstreamCharge + dt / cfg.chargeTime)

            -- Calculate boost force based on charge level and distance
            local distanceFactor = 1.0 - ((bestDist - cfg.minDistance) / (cfg.maxDistance - cfg.minDistance))
            distanceFactor = math.max(0.3, distanceFactor) -- Minimum 30% effectiveness at max range

            local currentBoost = cfg.boostForce + (cfg.maxBoostForce - cfg.boostForce) * slipstreamCharge
            currentBoost = currentBoost * distanceFactor

            -- Apply boost in the vehicle's forward direction
            local forwardVec = getEntityForwardVector(myVehicle)
            ApplyForceToEntity(
                myVehicle,
                1,                      -- Force type: external force
                forwardVec.x * currentBoost,
                forwardVec.y * currentBoost,
                0.0,                    -- No vertical force
                0.0, 0.0, 0.0,         -- Offset
                0,                      -- Bone index
                false,                  -- isDirectionRel
                true,                   -- ignoreUpVec
                true,                   -- isForceRel
                false,                  -- p12
                true                    -- p13
            )

            -- Screen effect
            if cfg.enableVisualEffect then
                startScreenEffect()
            end

            -- Sound feedback on first contact
            if cfg.enableSound and slipstreamCharge < 0.05 then
                PlaySoundFrontend(-1, 'RACE_PLACED', 'HUD_AWARDS', false)
            end

        else
            -- Not in slipstream
            isInSlipstream = false
            slipstreamTarget = nil

            if residualTimer > 0 then
                -- Apply residual boost (slingshot effect for overtaking)
                residualTimer = residualTimer - dt
                local residualCharge = slipstreamCharge * cfg.residualMultiplier
                local residualBoost = cfg.boostForce * residualCharge * (residualTimer / cfg.residualDuration)

                if residualBoost > 0.01 then
                    local forwardVec = getEntityForwardVector(myVehicle)
                    ApplyForceToEntity(
                        myVehicle,
                        1,
                        forwardVec.x * residualBoost,
                        forwardVec.y * residualBoost,
                        0.0,
                        0.0, 0.0, 0.0,
                        0, false, true, true, false, true
                    )
                end
            else
                -- Decay the charge when not drafting
                slipstreamCharge = math.max(0.0, slipstreamCharge - dt * 1.5)
                if slipstreamCharge <= 0 then
                    stopScreenEffect()
                end
            end
        end

        -- Always draw HUD when in race and there's any charge
        drawSlipstreamHUD(slipstreamCharge)

        ::continue::
    end
end)

-------------------------------------------------
-- FALLBACK RACE DETECTION
-------------------------------------------------

-- Periodically verify race state with the server
CreateThread(function()
    while true do
        Wait(5000)
        if isInRace then
            TriggerServerEvent('rahe-slipstream:server:amIRacing')
        end
    end
end)

-------------------------------------------------
-- RESOURCE CLEANUP
-------------------------------------------------

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    stopScreenEffect()
    slipstreamCharge = 0.0
    isInSlipstream = false
    isInRace = false
end)

print('[rahe-slipstream] Client-side loaded. Slipstream system ready.')
