local addonName, addon = ...

local menu = {}
addon.Menu = menu

local menuBuilder

function menu.RefreshBroker()
	addon.LDB:Update()
end

function menu.Init()
	local lib = LibStub('Krowi_MenuBuilder-1.0')

	menuBuilder = lib:New({
		uniqueTag = addon.Metadata.Prefix .. '_RIGHT_CLICK_MENU_OPTIONS',
		callbacks = {
			OnCheckboxSelect = function(filters, keys)
				addon.Util.WriteNestedKeys(filters, keys, not menuBuilder:KeyIsTrue(filters, keys))
				menu.RefreshBroker()
			end,

			OnRadioSelect = function(filters, keys, value)
				addon.Util.WriteNestedKeys(filters, keys, value)
				menu.RefreshBroker()
			end
		}
	})
end

local function CreateParentHeaderCheckbox(parentMenu, text, setKey, headerEntry)
	return menuBuilder:CreateCustomCheckbox(
		parentMenu,
		text,
		function()
            return menuBuilder:KeyIsTrue(KrowiBCU_Options, {'HeaderSettings', setKey})
        end,
		function()
			local filters, keys = KrowiBCU_Options, {'HeaderSettings', setKey}
			local currentValue = addon.Util.ReadNestedKeys(filters, keys)
			if currentValue == nil then currentValue = true end
			local newValue = not currentValue
			addon.Util.WriteNestedKeys(filters, keys, newValue)
			addon.Currency.UpdateChildHeaders(headerEntry, newValue)
			addon.LDB:Update()
		end
	)
end

local function CreateCharacterCheckbox(parentMenu, char, currentRealmName)
	local charKey = char.key
	if char.visible == nil then
		char.visible = true
	end
	
	local coloredText = addon.CharacterData.GetCharacterDisplayTextWithColor(char, true, currentRealmName)
	menuBuilder:CreateCustomCheckbox(
		parentMenu,
		coloredText,
		function()
			return KrowiBCU_SavedData.CharacterData[charKey].visible ~= false
		end,
		function()
			local charData = KrowiBCU_SavedData.CharacterData[charKey]
			if charData then
				charData.visible = not (charData.visible ~= false)
			end
		end
	)
end

local function AddCharacterCheckboxes(parentMenu, sortedCharacters, currentRealmName)
	local charactersPerMenu = 20
	local totalCharacters = #sortedCharacters
	
	if totalCharacters <= charactersPerMenu then
		-- Show all characters directly in the menu
		for _, char in ipairs(sortedCharacters) do
			CreateCharacterCheckbox(parentMenu, char, currentRealmName)
		end
	else
		-- Create submenus for groups of characters
		local groupStart = 1
		while groupStart <= totalCharacters do
			local groupEnd = math.min(groupStart + charactersPerMenu - 1, totalCharacters)
			local groupLabel = string.format('%d-%d', groupStart, groupEnd)
			local groupMenu = menuBuilder:CreateSubmenuButton(parentMenu, groupLabel)
			
			for i = groupStart, groupEnd do
				local char = sortedCharacters[i]
				CreateCharacterCheckbox(groupMenu, char, currentRealmName)
			end
			
			menuBuilder:AddChildMenu(parentMenu, groupMenu)
			groupStart = groupEnd + 1
		end
	end
end

local function CreateMaxCharactersMenu(parentMenu)
	local maxCharsMenu = menuBuilder:CreateSubmenuButton(parentMenu, addon.L['Max Characters'])
	menuBuilder:CreateRadio(maxCharsMenu, '5', KrowiBCU_Options, {'MaxCharacters'}, 5)
	menuBuilder:CreateRadio(maxCharsMenu, '10', KrowiBCU_Options, {'MaxCharacters'}, 10)
	menuBuilder:CreateRadio(maxCharsMenu, '15', KrowiBCU_Options, {'MaxCharacters'}, 15)
	menuBuilder:CreateRadio(maxCharsMenu, '20', KrowiBCU_Options, {'MaxCharacters'}, 20)
	menuBuilder:CreateRadio(maxCharsMenu, '25', KrowiBCU_Options, {'MaxCharacters'}, 25)
	menuBuilder:CreateRadio(maxCharsMenu, '30', KrowiBCU_Options, {'MaxCharacters'}, 30)
	menuBuilder:AddChildMenu(parentMenu, maxCharsMenu)
end

local function CreateCharacterListMenu(parentMenu)
	local characterListMenu = menuBuilder:CreateSubmenuButton(parentMenu, addon.L['Characters'])
	
	menuBuilder:CreateCheckbox(characterListMenu, addon.L['Show New Characters'], KrowiBCU_Options, {'ShowNewCharacters'})
	
	menuBuilder:CreateDivider(characterListMenu)
	
	if next(KrowiBCU_SavedData.CharacterData) then
		local currentRealmName = GetRealmName() or 'Unknown'
		local sortedCharacters = addon.CharacterData.SortCharactersByMoney(KrowiBCU_SavedData.CharacterData)
		AddCharacterCheckboxes(characterListMenu, sortedCharacters, currentRealmName)
	else
		menuBuilder:CreateButton(characterListMenu, addon.L['No character data available yet'], function() end)
	end

	menuBuilder:CreateDivider(characterListMenu)
	
	menuBuilder:CreateSelectDeselectAllButtons(
		characterListMenu,
		KrowiBCU_SavedData,
		{'CharacterData'},
		function(_, _, _, value)
			for _, char in pairs(KrowiBCU_SavedData.CharacterData) do
				char.visible = value
			end
		end
	)
	menuBuilder:AddChildMenu(parentMenu, characterListMenu)
end

local function CreateSessionDurationMenu(parentMenu)
	local sessionDuration = menuBuilder:CreateSubmenuButton(parentMenu, addon.L['Session Duration'])
	menuBuilder:CreateRadio(sessionDuration, addon.L['1 Hour'], KrowiBCU_Options, {'SessionDuration'}, 3600)
	menuBuilder:CreateRadio(sessionDuration, addon.L['2 Hours'], KrowiBCU_Options, {'SessionDuration'}, 7200)
	menuBuilder:CreateRadio(sessionDuration, addon.L['4 Hours'], KrowiBCU_Options, {'SessionDuration'}, 14400)
	menuBuilder:CreateRadio(sessionDuration, addon.L['8 Hours'], KrowiBCU_Options, {'SessionDuration'}, 28800)
	menuBuilder:CreateRadio(sessionDuration, addon.L['12 Hours'], KrowiBCU_Options, {'SessionDuration'}, 43200)
	menuBuilder:CreateRadio(sessionDuration, addon.L['24 Hours'], KrowiBCU_Options, {'SessionDuration'}, 86400)
	menuBuilder:CreateRadio(sessionDuration, addon.L['48 Hours'], KrowiBCU_Options, {'SessionDuration'}, 172800)
	menuBuilder:AddChildMenu(parentMenu, sessionDuration)
end

local function CreateSessionTrackingOptions(parentMenu)
	menuBuilder:CreateCheckbox(parentMenu, addon.L['Track All Realms'], KrowiBCU_Options, {'TrackAllRealms'})

	-- Custom checkbox with special handling for session tracking
	menuBuilder:CreateCustomCheckbox(
		parentMenu,
		addon.L['Track Session Gold'],
		function()
            return menuBuilder:KeyIsTrue(KrowiBCU_Options, {'TrackSessionGold'})
        end,
		function()
			local filters, keys = KrowiBCU_Options, {'TrackSessionGold'}
			local value = addon.Util.ReadNestedKeys(filters, keys)
			if value == nil then value = true end
			local newValue = not value
			addon.Util.WriteNestedKeys(filters, keys, newValue)

			if not newValue then
				addon.ResetSessionTracking()
			end
			addon.LDB.Update()
		end
	)

	CreateSessionDurationMenu(parentMenu)

	menuBuilder:CreateCheckbox(parentMenu, addon.L['Show WoW Token'], KrowiBCU_Options, {'ShowWoWToken'})
end

local function CreateMoneyMenu(parentMenu)
	local money = menuBuilder:CreateSubmenuButton(parentMenu, addon.L['Money'])
	local lib = LibStub('Krowi_Currency-1.0')
	lib:CreateMoneyOptionsMenu(money, menuBuilder, KrowiBCU_Options, false)

	CreateMaxCharactersMenu(money)
	CreateCharacterListMenu(money)
	CreateSessionTrackingOptions(money)

	menuBuilder:AddChildMenu(parentMenu, money)
end

local function CreateHeaderMenu(parentMenu, headerEntry)
	local settingKey = addon.GetHeaderSettingKey(headerEntry.name)
	local hasChildren = next(headerEntry.children)

	if addon.Util.ReadNestedKeys(KrowiBCU_Options, {'HeaderSettings', settingKey}) == nil then
		addon.Util.WriteNestedKeys(KrowiBCU_Options, {'HeaderSettings', settingKey}, true)
	end

	if not hasChildren then
		menuBuilder:CreateCheckbox(parentMenu, headerEntry.name, KrowiBCU_Options, {'HeaderSettings', settingKey})
		return
	end

	local headerSubmenu = menuBuilder:CreateSubmenuButton(parentMenu, headerEntry.name)
	CreateParentHeaderCheckbox(headerSubmenu, 'Show ' .. headerEntry.name, settingKey, headerEntry)
	menuBuilder:CreateDivider(headerSubmenu)

	for _, childHeader in pairs(headerEntry.children) do
		CreateHeaderMenu(headerSubmenu, childHeader)
	end

	menuBuilder:AddChildMenu(parentMenu, headerSubmenu)
end

local function CreateHeaderVisibilityMenu(parentMenu)
	local headerVisibility = menuBuilder:CreateSubmenuButton(parentMenu, addon.L['Header Visibility'])
	local structuredHeaders, orderedHeaderNames = addon.Currency.GetAllCurrenciesWithHeader()
	for _, headerName in ipairs(orderedHeaderNames) do
		local headerEntry = structuredHeaders[headerName]
		if headerEntry then
			CreateHeaderMenu(headerVisibility, headerEntry)
		end
	end
	menuBuilder:AddChildMenu(parentMenu, headerVisibility)
end

local function CreateCurrencyMenu(parentMenu)
	local lib = LibStub('Krowi_Currency-1.0')
	local currency = menuBuilder:CreateSubmenuButton(parentMenu, addon.L['Currency'])
	lib:CreateCurrencyOptionsMenu(currency, menuBuilder, KrowiBCU_Options, false)

	menuBuilder:CreateCheckbox(currency, addon.L['Currency Group By Header'], KrowiBCU_Options, {'CurrencyGroupByHeader'})
	menuBuilder:CreateCheckbox(currency, addon.L['Currency Hide Unused'], KrowiBCU_Options, {'CurrencyHideUnused'})

	CreateHeaderVisibilityMenu(currency)
	menuBuilder:AddChildMenu(parentMenu, currency)
end

local function CreateShowOnButtonMenu(parentMenu)
	local showOnButton = menuBuilder:CreateSubmenuButton(parentMenu, addon.L['Show On Button'])
	menuBuilder:CreateRadio(showOnButton, addon.L['Character Gold'], KrowiBCU_Options, {'ButtonDisplay'}, 'CharacterGold')
	menuBuilder:CreateRadio(showOnButton, addon.L['Current Faction Total'], KrowiBCU_Options, {'ButtonDisplay'}, 'FactionTotal')
	menuBuilder:CreateRadio(showOnButton, addon.L['Realm Total'], KrowiBCU_Options, {'ButtonDisplay'}, 'RealmTotal')
	menuBuilder:CreateRadio(showOnButton, addon.L['Account Total'], KrowiBCU_Options, {'ButtonDisplay'}, 'AccountTotal')
	if addon.Util.IsMainline then
		menuBuilder:CreateRadio(showOnButton, addon.L['Warband Bank'], KrowiBCU_Options, {'ButtonDisplay'}, 'WarbandBank')
	end
	menuBuilder:AddChildMenu(parentMenu, showOnButton)
end

local function CreateDefaultTooltipMenu(parentMenu)
	local defaultTooltip = menuBuilder:CreateSubmenuButton(parentMenu, addon.L['Default Tooltip'])
	menuBuilder:CreateRadio(defaultTooltip, addon.L['Currency'], KrowiBCU_Options, {'DefaultTooltip'}, 'Currency')
	menuBuilder:CreateRadio(defaultTooltip, addon.L['Money'], KrowiBCU_Options, {'DefaultTooltip'}, 'Money')
	menuBuilder:CreateRadio(defaultTooltip, addon.L['Combined (Money First)'], KrowiBCU_Options, {'DefaultTooltip'}, 'CombinedMoneyFirst')
	menuBuilder:CreateRadio(defaultTooltip, addon.L['Combined (Currency First)'], KrowiBCU_Options, {'DefaultTooltip'}, 'CombinedCurrencyFirst')
	menuBuilder:AddChildMenu(parentMenu, defaultTooltip)
end

local function CreateMenu(menuObj, caller)
	menuBuilder:CreateTitle(menuObj, addon.Metadata.Title .. ' ' .. addon.Metadata.Version)

	menuBuilder:CreateDivider(menuObj)

	CreateShowOnButtonMenu(menuObj)
	CreateDefaultTooltipMenu(menuObj)
	CreateMoneyMenu(menuObj)
	CreateCurrencyMenu(menuObj)

	menu.CreateElvUIOptionsMenu(menuBuilder, menuObj, caller)
	menu.CreateTitanOptionsMenu(menuBuilder, menuObj, caller)
end

function menu.ShowPopup(caller)
	menuBuilder:ShowPopup(function()
		local menuObj = menuBuilder:GetMenu()
		CreateMenu(menuObj, caller)
	end)
end