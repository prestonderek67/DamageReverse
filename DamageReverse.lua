--DamageReverse.lua

-- Create the main frame for the addon
local frame = CreateFrame("Frame", "DamageReverseFrame", UIParent)
frame:SetSize(200, 200)  -- Increased height to fit more rows
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

-- Table to store damage data
local damageData = {}
local spellData = {}
local startTime = 0
local dpsRows = {}
local updateInterval = 2  -- Update DPS every 2 seconds
local timeSinceLastUpdate = 0

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

-- Function to sort damage data by DPS
local function getSortedDamageData()
    local currentTime = GetTime()
    local totalTime = currentTime - startTime
    local sortedData = {}

    for name, data in pairs(damageData) do
        local dps = data.total / totalTime
        table.insert(sortedData, {name = name, dps = dps})
    end

    table.sort(sortedData, function(a, b) return a.dps > b.dps end)
    return sortedData
end

-- Function to reverse the sorted damage data
local function getReversedDamageData(sortedData)
    local reversedData = {}
    for i = #sortedData, 1, -1 do
        table.insert(reversedData, sortedData[i])
    end
    return reversedData
end

-- Function to modify DPS values
local function modifyDpsValues(sortedData)
    local n = #sortedData
    local modifiedData = {}

    for i, entry in ipairs(sortedData) do
        modifiedData[i] = {name = entry.name, dps = sortedData[n - i + 1].dps}
    end

    return modifiedData
end

-- Create a function to update the DPS rows
local function updateDpsRows()
    local sortedData = getSortedDamageData()
    local displayData

    if frame.reverseCheckbox:GetChecked() then
        displayData = modifyDpsValues(sortedData)
    else
        displayData = sortedData
    end

    local index = 1
    for _, entry in ipairs(displayData) do
        local name = entry.name
        local dps = entry.dps

        if not dpsRows[index] then
            -- Create a frame for the row
            local rowFrame = CreateFrame("Frame", nil, frame)
            rowFrame:SetSize(180, 20)
            rowFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -30 - (index - 1) * 25)

            -- Create a border for the row frame
            local border = rowFrame:CreateTexture(nil, "BACKGROUND")
            border:SetColorTexture(1, 1, 1, 1)  -- White border
            border:SetPoint("TOPLEFT", -1, 1)
            border:SetPoint("BOTTOMRIGHT", 1, -1)

            -- Create a background for the row frame
            rowFrame.bg = rowFrame:CreateTexture(nil, "BACKGROUND")
            rowFrame.bg:SetAllPoints(true)
            rowFrame.bg:SetColorTexture(0, 0, 0, 0.5)  -- Black with 50% opacity

            -- Create a font string for the DPS text
            rowFrame.text = rowFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
            rowFrame.text:SetPoint("LEFT", rowFrame, "LEFT", 5, 0)

            -- Add mouse events for tooltip
            rowFrame:SetScript("OnEnter", function(self)
                if not frame.reverseCheckbox:GetChecked() then
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetText(name .. " Spell Details")
                    if spellData[name] then
                        for spellName, spellDamage in pairs(spellData[name]) do
                            GameTooltip:AddLine(spellName .. ": " .. spellDamage)
                        end
                    end
                    GameTooltip:Show()
                end
            end)
            rowFrame:SetScript("OnLeave", function(self)
                GameTooltip:Hide()
            end)

            dpsRows[index] = rowFrame
        end

        dpsRows[index].text:SetText(name .. ": " .. string.format("%.2f", dps) .. " DPS")
        dpsRows[index]:Show()
        index = index + 1
    end

    -- Hide unused rows
    for i = index, #dpsRows do
        dpsRows[i]:Hide()
    end
end

-- Create the checkbox
frame.reverseCheckbox = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
frame.reverseCheckbox:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -10)
frame.reverseCheckbox.text = frame.reverseCheckbox:CreateFontString(nil, "ARTWORK", "GameFontNormal")
frame.reverseCheckbox.text:SetPoint("LEFT", frame.reverseCheckbox, "RIGHT", 0, 1)
frame.reverseCheckbox.text:SetText("Reverse DPS")

-- Event handler function
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local _, subEvent, _, sourceGUID, sourceName, _, _, _, _, _, _, spellId, spellName, _, amount = CombatLogGetCurrentEventInfo()

        if (subEvent == "SPELL_DAMAGE" or subEvent == "RANGE_DAMAGE" or subEvent == "SWING_DAMAGE") and amount then
            if sourceName and isPartyMember(sourceGUID) then
                if not damageData[sourceName] then
                    damageData[sourceName] = {total = 0, start = GetTime()}
                end
                damageData[sourceName].total = damageData[sourceName].total + amount

                if not spellData[sourceName] then
                    spellData[sourceName] = {}
                end
                if not spellData[sourceName][spellName] then
                    spellData[sourceName][spellName] = 0
                end
                spellData[sourceName][spellName] = spellData[sourceName][spellName] + amount
            end
        end
    elseif event == "PLAYER_REGEN_ENABLED" then  -- Combat ends
        frame:SetScript("OnUpdate", nil)  -- Stop updating DPS
    elseif event == "PLAYER_REGEN_DISABLED" then  -- Combat starts
        startTime = GetTime()
        damageData = {}
        spellData = {}
        timeSinceLastUpdate = 0
        frame:SetScript("OnUpdate", function(self, elapsed)
            timeSinceLastUpdate = timeSinceLastUpdate + elapsed
            if timeSinceLastUpdate >= updateInterval then
                updateDpsRows()
                timeSinceLastUpdate = 0
            end
        end)
    end
end)

-- Slash command to display the frame (for testing purposes)
SLASH_SHOWDPSMETER1 = "/showdpsmeter"
SlashCmdList["SHOWDPSMETER"] = function()
    frame:Show()
    print("DPS Meter shown")
end






