local _, addon = ...

local tooltip = {}
addon.Tooltip = tooltip

function tooltip.Init()
	-- Initialize tooltip if needed
end

local function HeaderHasCurrencies(headerEntry)
	if #headerEntry.currencies > 0 then
		return true
	end
	for _, childHeader in pairs(headerEntry.children) do
		if HeaderHasCurrencies(childHeader) then
			return true
		end
	end

	return false
end

local function ShouldShowHeader(headerName)
	local settingKey = addon.GetHeaderSettingKey(headerName)
	local shouldShow = addon.Util.ReadNestedKeys(KrowiBCU_Options, {'HeaderSettings', settingKey})
	if shouldShow == nil then return true end
	return shouldShow
end

local function DisplayHeaderRecursive(headerEntry, depth)
	if not HeaderHasCurrencies(headerEntry) then
		return
	end

	if not ShouldShowHeader(headerEntry.name) then
		return
	end

	local indent = string.rep('  ', depth)

	GameTooltip:AddLine(indent .. headerEntry.name)
	if #headerEntry.currencies > 0 then
		local currencies = {}
		for _, currency in ipairs(headerEntry.currencies) do
			tinsert(currencies, currency)
		end
		table.sort(currencies, function(a, b) return a.name < b.name end)

		for _, currency in ipairs(currencies) do
			GameTooltip:AddDoubleLine(indent .. '  ' .. currency.name, addon.FormatCurrency(currency.quantity) .. ' |T' .. currency.iconFileID .. ':16|t', 1, 1, 1, 1, 1, 1)
		end
	end

	for _, childHeader in pairs(headerEntry.children) do
		if HeaderHasCurrencies(childHeader) then
			DisplayHeaderRecursive(childHeader, depth + 1)
		end
	end
end

local function GetAllCurrenciesWithHeaderSorted()
	local headers, orderedHeaderNames = addon.Currency.GetAllCurrenciesWithHeader()

	local hasDisplayedAnyHeader = false
	for _, headerName in ipairs(orderedHeaderNames) do
		local headerEntry = headers[headerName]
		if headerEntry then
			if HeaderHasCurrencies(headerEntry) and ShouldShowHeader(headerEntry.name) then
				if hasDisplayedAnyHeader then
					GameTooltip_AddBlankLineToTooltip(GameTooltip)
				end
				DisplayHeaderRecursive(headerEntry, 0)
				hasDisplayedAnyHeader = true
			end
		end
	end
end

local function GetAllCurrenciesSorted()
	local currencies = addon.Currency.GetAllCurrencies()

	table.sort(currencies, function(a, b) return a.name < b.name end)

	for _, currency in next, currencies do
		GameTooltip:AddDoubleLine(currency.name, addon.FormatCurrency(currency.quantity) .. ' |T' .. currency.iconFileID .. ':16|t', 1, 1, 1, 1, 1, 1)
	end
end

local function DisplayMoneyContent()
	local currentPlayerName = UnitName('player') or 'Unknown'
	local currentRealmName = GetRealmName() or 'Unknown'
	local currentKey = currentPlayerName .. '-' .. currentRealmName

	local characterData = KrowiBCU_SavedData.CharacterData or {}
	local maxChars = KrowiBCU_Options.MaxCharacters or 20

	if not next(characterData) then
		GameTooltip:AddLine(addon.L['No character data available yet'], 0.7, 0.7, 0.7)
		GameTooltip:AddLine(addon.L['Data will be collected as you play'], 0.7, 0.7, 0.7)
		return
	end

	local sortedCharacters = addon.CharacterData.SortCharactersByMoney(characterData)
	local totalMoney = 0
	local allianceTotal = 0
	local hordeTotal = 0
	local warbandMoney = addon.GetWarbandMoney()

	local sessionProfit = addon.GetSessionProfit()
	local sessionSpent = addon.GetSessionSpent()

	if sessionProfit > 0 or sessionSpent > 0 then
		GameTooltip:AddLine(addon.L['Session:'])

		if sessionProfit > 0 then
			local profitFormatted = addon.FormatMoney(sessionProfit)
			GameTooltip:AddDoubleLine(addon.L['Earned:'], profitFormatted, 0.5, 1, 0.5, 1, 1, 1)
		end

		if sessionSpent > 0 then
			local spentFormatted = addon.FormatMoney(sessionSpent)
			GameTooltip:AddDoubleLine(addon.L['Spent:'], spentFormatted, 1, 0.5, 0.5, 1, 1, 1)
		end

		GameTooltip_AddBlankLineToTooltip(GameTooltip)
	end

	GameTooltip:AddLine(addon.L['Characters:'])

	local count = 0
	for _, char in ipairs(sortedCharacters) do
		-- Default to visible if not set
		if char.visible == nil then
			char.visible = true
		end
		
		-- Skip hidden characters
		if char.visible then
			count = count + 1
			if count > maxChars then
				local remaining = #sortedCharacters - maxChars
				GameTooltip:AddLine(string.format('+%d %s', remaining, remaining > 1 and addon.L['more characters'] or addon.L['more character']), 0.7, 0.7, 0.7)
				break
			end

			local money = char.money or 0
			totalMoney = totalMoney + money

			if char.faction == 'Alliance' then
				allianceTotal = allianceTotal + money
			elseif char.faction == 'Horde' then
				hordeTotal = hordeTotal + money
			end

			local formattedMoney = addon.FormatMoney(money)
			local displayName = addon.CharacterData.GetCharacterDisplayName(char, true, currentRealmName)

			if char.key == currentKey then
				displayName = displayName .. ' |TInterface\\COMMON\\Indicator-Green:14|t'
			end

			local classColor = addon.CharacterData.GetCharacterClassColor(char)
			GameTooltip:AddDoubleLine(displayName, formattedMoney, classColor.r, classColor.g, classColor.b, 1, 1, 1)
		end
	end

	if allianceTotal > 0 and hordeTotal > 0 then
		GameTooltip_AddBlankLineToTooltip(GameTooltip)
		GameTooltip:AddLine(addon.L['Faction Totals:'])

		if allianceTotal > 0 then
			local allianceFormatted = addon.FormatMoney(allianceTotal)
			GameTooltip:AddDoubleLine(addon.L['Alliance:'], allianceFormatted, 0, 0.376, 1, 1, 1, 1)
		end

		if hordeTotal > 0 then
			local hordeFormatted = addon.FormatMoney(hordeTotal)
			GameTooltip:AddDoubleLine(addon.L['Horde:'], hordeFormatted, 1, 0.2, 0.2, 1, 1, 1)
		end
	end

	if addon.Util.IsMainline then
		GameTooltip_AddBlankLineToTooltip(GameTooltip)
		local warbandFormatted = addon.FormatMoney(warbandMoney)
		GameTooltip:AddDoubleLine(addon.L['Warband Bank:'], warbandFormatted, 0.8, 0.6, 1, 1, 1, 1)
		totalMoney = totalMoney + warbandMoney
	end

	GameTooltip_AddBlankLineToTooltip(GameTooltip)
	local totalFormatted = addon.FormatMoney(totalMoney)
	GameTooltip:AddDoubleLine(addon.L['Total:'], totalFormatted)

	if KrowiBCU_Options.ShowWoWToken then
		C_WowTokenPublic.UpdateMarketPrice()
		local tokenPrice = C_WowTokenPublic.GetCurrentMarketPrice()
		if tokenPrice and tokenPrice > 0 then
			local tokenFormatted = addon.FormatMoney(tokenPrice)
			GameTooltip_AddBlankLineToTooltip(GameTooltip)
			GameTooltip:AddDoubleLine(addon.L['WoW Token:'], tokenFormatted, 0, 0.8, 1, 1, 1, 1)
		end
	end
end

local function DisplayCurrencyContent()
	if KrowiBCU_Options.CurrencyGroupByHeader then
		GetAllCurrenciesWithHeaderSorted()
	else
		GetAllCurrenciesSorted()
	end
end

local function GetDetailedMoneyTooltip()
	DisplayMoneyContent()

	GameTooltip_AddBlankLineToTooltip(GameTooltip)
	local defaultTooltip = KrowiBCU_Options.DefaultTooltip
	if defaultTooltip == 'CombinedMoneyFirst' or defaultTooltip == 'CombinedCurrencyFirst' then
		GameTooltip:AddLine(addon.L['Release Shift: Show combined'], 0.5, 0.8, 1)
	elseif defaultTooltip == 'Money' then
		GameTooltip:AddLine(addon.L['Hold Shift: Show currencies'], 0.5, 0.8, 1)
	else
		GameTooltip:AddLine(addon.L['Release Shift: Show currencies'], 0.5, 0.8, 1)
	end
end

local function GetAllCurrenciesTooltip()
	DisplayCurrencyContent()

	GameTooltip_AddBlankLineToTooltip(GameTooltip)
	local defaultTooltip = KrowiBCU_Options.DefaultTooltip
	if defaultTooltip == 'CombinedMoneyFirst' or defaultTooltip == 'CombinedCurrencyFirst' then
		GameTooltip:AddLine(addon.L['Release Ctrl: Show combined'], 0.5, 0.8, 1)
	elseif defaultTooltip == 'Money' then
		GameTooltip:AddLine(addon.L['Release Shift: Show money'], 0.5, 0.8, 1)
	else
		GameTooltip:AddLine(addon.L['Hold Shift: Show money'], 0.5, 0.8, 1)
	end
end

local function GetCombinedTooltip(showMoneyFirst)
	if showMoneyFirst then
		DisplayMoneyContent()
		GameTooltip_AddBlankLineToTooltip(GameTooltip)
		GameTooltip:AddLine('--------------------------------------------------', 0.5, 0.5, 0.5)
		GameTooltip_AddBlankLineToTooltip(GameTooltip)
		DisplayCurrencyContent()
	else
		DisplayCurrencyContent()
		GameTooltip_AddBlankLineToTooltip(GameTooltip)
		GameTooltip:AddLine('--------------------------------------------------', 0.5, 0.5, 0.5)
		GameTooltip_AddBlankLineToTooltip(GameTooltip)
		DisplayMoneyContent()
	end

	GameTooltip_AddBlankLineToTooltip(GameTooltip)
	GameTooltip:AddLine(addon.L['Hold Ctrl: Show currencies'], 0.5, 0.8, 1)
	GameTooltip:AddLine(addon.L['Hold Shift: Show money'], 0.5, 0.8, 1)
end

function tooltip.Show(frame)
	local defaultTooltip = KrowiBCU_Options.DefaultTooltip
	local shiftPressed = IsShiftKeyDown()
	local ctrlPressed = IsLeftControlKeyDown() or IsRightControlKeyDown()
	local tooltipType

	if defaultTooltip == 'CombinedMoneyFirst' or defaultTooltip == 'CombinedCurrencyFirst' then
		if ctrlPressed then
			tooltipType = 'Currency'
		elseif shiftPressed then
			tooltipType = 'Money'
		else
			tooltipType = defaultTooltip
		end
	elseif defaultTooltip == 'Money' then
		tooltipType = shiftPressed and 'Currency' or 'Money'
	else
		tooltipType = shiftPressed and 'Money' or 'Currency'
	end

	GameTooltip:SetOwner(frame, 'ANCHOR_NONE')
	GameTooltip:SetPoint('TOPLEFT', frame, 'BOTTOMLEFT')
	GameTooltip:AddLine(addon.Metadata.Title .. ' ' .. addon.Metadata.Version)
	GameTooltip_AddBlankLineToTooltip(GameTooltip)

	if tooltipType == 'Money' then
		GetDetailedMoneyTooltip()
	elseif tooltipType == 'CombinedMoneyFirst' then
		GetCombinedTooltip(true)
	elseif tooltipType == 'CombinedCurrencyFirst' then
		GetCombinedTooltip(false)
	else
		GetAllCurrenciesTooltip()
	end
	GameTooltip:AddLine(addon.L['Right-Click: Options'], 0.5, 0.8, 1)

	GameTooltip:Show()
end