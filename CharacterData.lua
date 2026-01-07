local _, addon = ...

local characterData = {}
addon.CharacterData = characterData

-- Sort characters by money (descending)
function characterData.SortCharactersByMoney(charData)
	local sortedChars = {}
	for key, char in pairs(charData) do
		char.key = key
		tinsert(sortedChars, char)
	end

	table.sort(sortedChars, function(a, b)
		return (a.money or 0) > (b.money or 0)
	end)

	return sortedChars
end

-- Get faction icon for a character
function characterData.GetFactionIcon(faction)
	if faction == 'Alliance' then
		return '|A:worldquest-icon-alliance:15:16|a|T:1:8|t'
	elseif faction == 'Horde' then
		return '|A:worldquest-icon-horde:15:16|a|T:1:8|t'
	else
		return '|A:worldquest-questmarker-questionmark:15:16|a|T:1:8|t'
	end
end

-- Format character display name with faction icon and realm
function characterData.GetCharacterDisplayName(char, includeRealm, currentRealmName)
	local charName = char.name or 'Unknown'
	local realmName = char.realm or 'Unknown'
	local faction = char.faction or 'Neutral'
	
	local factionIcon = characterData.GetFactionIcon(faction)
	local displayName = factionIcon .. charName
	
	if includeRealm and realmName ~= currentRealmName then
		displayName = displayName .. ' - ' .. realmName
	end
	
	return displayName
end

-- Get class color for a character
function characterData.GetCharacterClassColor(char)
	local className = char.className or ''
	return RAID_CLASS_COLORS[className] or {r = 1, g = 1, b = 1}
end

-- Format character display with class color (for menu)
function characterData.GetCharacterDisplayTextWithColor(char, includeRealm, currentRealmName)
	local displayName = characterData.GetCharacterDisplayName(char, includeRealm, currentRealmName)
	local charMoney = char.money or 0
	local formattedMoney = addon.FormatMoney(charMoney)
	local classColor = characterData.GetCharacterClassColor(char)
	
	local coloredText = string.format('|cFF%02x%02x%02x%s|r: %s', 
		classColor.r * 255, classColor.g * 255, classColor.b * 255, 
		displayName, formattedMoney)
	
	return coloredText
end

-- Generate character key from name and realm
local function GetCharacterKey(playerName, realmName)
	return playerName .. '-' .. realmName
end

-- Update session tracking based on money change
local function UpdateSessionTracking(oldMoney, currentMoney)
	if not KrowiBCU_Options.TrackSessionGold then
		return
	end

	local change = currentMoney - oldMoney
	if change == 0 then
		return
	end

	if change > 0 then
		KrowiBCU_SavedData.SessionProfit = (KrowiBCU_SavedData.SessionProfit or 0) + change
	else
		KrowiBCU_SavedData.SessionSpent = (KrowiBCU_SavedData.SessionSpent or 0) - change
	end
	
	KrowiBCU_SavedData.SessionLastUpdate = time()
end

-- Determine default visibility for character
local function GetDefaultVisibility(oldData)
	if oldData and oldData.visible ~= nil then
		return oldData.visible
	end
	return KrowiBCU_Options.ShowNewCharacters
end

-- Update character data for current player
function characterData.UpdateCharacterData()
	local playerName = UnitName('player') or 'Unknown'
	local realmName = GetRealmName() or 'Unknown'
	local currentMoney = GetMoney()
	local faction = UnitFactionGroup('player') or 'Neutral'
	local _, className = UnitClass('player')
	
	local characterKey = GetCharacterKey(playerName, realmName)
	local charData = KrowiBCU_SavedData.CharacterData or {}
	local oldData = charData[characterKey]

	UpdateSessionTracking((oldData and oldData.money) or currentMoney, currentMoney)

	charData[characterKey] = {
		name = playerName,
		realm = realmName,
		money = currentMoney,
		faction = faction,
		className = className,
		visible = GetDefaultVisibility(oldData),
	}

	KrowiBCU_SavedData.CharacterData = charData
end

-- Calculate total money for a specific faction
function characterData.GetFactionTotal(faction)
	local total = 0
	local charData = KrowiBCU_SavedData.CharacterData or {}
	for _, char in pairs(charData) do
		if char.faction == faction then
			total = total + (char.money or 0)
		end
	end
	return total
end

-- Calculate total money for a specific realm
function characterData.GetRealmTotal(realmName)
	local total = 0
	local charData = KrowiBCU_SavedData.CharacterData or {}
	for _, char in pairs(charData) do
		if char.realm == realmName then
			total = total + (char.money or 0)
		end
	end
	return total
end

-- Calculate total money for all characters
function characterData.GetAccountTotal()
	local total = 0
	local charData = KrowiBCU_SavedData.CharacterData or {}
	for _, char in pairs(charData) do
		total = total + (char.money or 0)
	end
	return total
end
