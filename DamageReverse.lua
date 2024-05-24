-- DamageReverse.lua

-- Create the main frame for the addon
local frame = CreateFrame("Frame", "DamageReverse Frame", UIParent)
frame:SetSize(200, 100)  -- Width, Height
frame:SetPoint("CENTER")  -- Position on screen
frame:EnableMouse(true)
frame:SetMovable(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

-- Create a background for the frame
frame.bg = frame:CreateTexture(nil, "BACKGROUND")
frame.bg:SetAllPoints(true)
frame.bg:SetColorTexture(0, 0, 0, 0.5)  -- Black with 50% opacity

-- Create a font string to display DPS
local dpsText = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
dpsText:SetPoint("CENTER", frame, "CENTER")
dpsText:SetText("DPS: 0")

-- Table to store damage data
local damageData = {}
local startTime = 0

-- Function to check if the GUID belongs to a party member
local function isPartyMember(guid)
    -- Check the player's own GUID
    if guid == UnitGUID("player") then
        return true
    end

    -- Check party members' GUIDs
    for i = 1, 4 do
        if guid == UnitGUID("party" .. i) then
            return true
        end
    end

    return false
end

-- Register the COMBAT_LOG_EVENT_UNFILTERED event
frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")

-- Event handler function
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local timestamp, subEvent, _, sourceGUID, sourceName, _, _, destGUID, destName, _, _, spellId, spellName, _, amount = CombatLogGetCurrentEventInfo()

        if subEvent == "SPELL_DAMAGE" or subEvent == "RANGE_DAMAGE" or subEvent == "SWING_DAMAGE" then
            if sourceName and amount and isPartyMember(sourceGUID) then
                if not damageData[sourceName] then
                    damageData[sourceName] = {total = 0, start = GetTime()}
                end
                damageData[sourceName].total = damageData[sourceName].total + amount
            end
        end
    elseif event == "PLAYER_REGEN_ENABLED" then  -- Combat ends
        frame:SetScript("OnUpdate", nil)  -- Stop updating DPS
    elseif event == "PLAYER_REGEN_DISABLED" then  -- Combat starts
        startTime = GetTime()
        damageData = {}
        frame:SetScript("OnUpdate", function(self, elapsed)
            local currentTime = GetTime()
            local totalTime = currentTime - startTime
            local dpsOutput = ""

            for name, data in pairs(damageData) do
                local dps = data.total / totalTime
                dpsOutput = dpsOutput .. name .. ": " .. string.format("%.2f", dps) .. " DPS\n"
            end

            dpsText:SetText(dpsOutput)
        end)
    end
end)

-- Slash command to display the frame (for testing purposes)
SLASH_SHOWDPSMETER1 = "/showdpsmeter"
SlashCmdList["SHOWDPSMETER"] = function()
    frame:Show()
    print("DPS Meter shown")
end



