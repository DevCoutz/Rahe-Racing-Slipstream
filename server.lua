--[[
    rahe-slipstream | server.lua
    Tracks which players are in active races by listening to rahe-racing events.
    Syncs this information to clients so slipstream only activates during races.
]]

-- Table of active races: raceId -> { participants = { serverId = true, ... } }
local activeRaces = {}

-- Quick lookup: serverId -> true/false (is the player in any active race?)
local playersInRace = {}

-- Counter to generate unique race IDs since rahe-racing events don't provide one
local raceIdCounter = 0

-------------------------------------------------
-- RAHE-RACING EVENT HANDLERS
-------------------------------------------------

-- When a race starts, register all participants
AddEventHandler('rahe-racing:server:raceStarted', function(startCoords, participants)
    raceIdCounter = raceIdCounter + 1
    local raceId = raceIdCounter

    activeRaces[raceId] = {
        startCoords = startCoords,
        participants = {},
    }

    if participants then
        for _, participant in pairs(participants) do
            -- Participants can be a table of server IDs or a table of objects.
            -- We handle multiple formats for compatibility.
            local serverId = nil
            if type(participant) == 'number' then
                serverId = participant
            elseif type(participant) == 'table' and participant.source then
                serverId = participant.source
            elseif type(participant) == 'table' and participant.serverId then
                serverId = participant.serverId
            elseif type(participant) == 'table' and participant.id then
                serverId = participant.id
            end

            if serverId then
                activeRaces[raceId].participants[serverId] = true
                playersInRace[serverId] = true
                TriggerClientEvent('rahe-slipstream:client:raceStateChanged', serverId, true)
            end
        end
    end

    -- Notify all participants about each other (for slipstream detection)
    local participantList = {}
    for sid, _ in pairs(activeRaces[raceId].participants) do
        table.insert(participantList, sid)
    end

    for _, sid in ipairs(participantList) do
        TriggerClientEvent('rahe-slipstream:client:updateRacers', sid, participantList)
    end

    print('[rahe-slipstream] Race #' .. raceId .. ' started with ' .. #participantList .. ' participants.')
end)

-- When a player joins a race mid-way (if rahe-racing supports it)
AddEventHandler('rahe-racing:server:playerJoinedRace', function(playerId)
    if playerId then
        playersInRace[playerId] = true
        TriggerClientEvent('rahe-slipstream:client:raceStateChanged', playerId, true)

        -- Find the most recent active race and add this player to it
        local addedToRace = false
        for raceId, raceData in pairs(activeRaces) do
            if next(raceData.participants) then
                raceData.participants[playerId] = true
                addedToRace = true

                -- Update all participants in this race
                local participantList = {}
                for sid, _ in pairs(raceData.participants) do
                    table.insert(participantList, sid)
                end
                for _, sid in ipairs(participantList) do
                    TriggerClientEvent('rahe-slipstream:client:updateRacers', sid, participantList)
                end
                break
            end
        end

        if not addedToRace then
            print('[rahe-slipstream] Player ' .. playerId .. ' joined race (no active race context found).')
        end
    end
end)

-- When a race finishes, clean up all participants
AddEventHandler('rahe-racing:server:raceFinished', function(raceData)
    -- Since rahe-racing doesn't provide a raceId, we clear all active races.
    -- This is safe because races finish atomically.
    for raceId, race in pairs(activeRaces) do
        for sid, _ in pairs(race.participants) do
            playersInRace[sid] = nil
            TriggerClientEvent('rahe-slipstream:client:raceStateChanged', sid, false)
            TriggerClientEvent('rahe-slipstream:client:updateRacers', sid, {})
        end
    end

    activeRaces = {}
    print('[rahe-slipstream] Race finished. All slipstream effects disabled.')
end)

-------------------------------------------------
-- CLIENT COMMUNICATION
-------------------------------------------------

-- Client asks if they're currently in a race (fallback sync)
RegisterNetEvent('rahe-slipstream:server:amIRacing', function()
    local src = source
    local isRacing = playersInRace[src] == true
    TriggerClientEvent('rahe-slipstream:client:raceStateChanged', src, isRacing)

    if isRacing then
        -- Also send the participant list
        for _, raceData in pairs(activeRaces) do
            if raceData.participants[src] then
                local participantList = {}
                for sid, _ in pairs(raceData.participants) do
                    table.insert(participantList, sid)
                end
                TriggerClientEvent('rahe-slipstream:client:updateRacers', src, participantList)
                break
            end
        end
    end
end)

-------------------------------------------------
-- CLEANUP
-------------------------------------------------

-- When a player disconnects, remove them from all race tracking
AddEventHandler('playerDropped', function()
    local src = source
    playersInRace[src] = nil

    for raceId, raceData in pairs(activeRaces) do
        raceData.participants[src] = nil

        -- Update remaining participants
        local participantList = {}
        for sid, _ in pairs(raceData.participants) do
            table.insert(participantList, sid)
        end

        -- If race is now empty, clean it up
        if #participantList == 0 then
            activeRaces[raceId] = nil
        else
            for _, sid in ipairs(participantList) do
                TriggerClientEvent('rahe-slipstream:client:updateRacers', sid, participantList)
            end
        end
    end
end)

print('[rahe-slipstream] Server-side loaded. Listening for rahe-racing events.')
