local addonName, addon = ...

print('currency formatmoney addon', addon.Currency, addon.Currency.FormatMoney)

local defaultOptions = {
	HeaderSettings = {},
	MoneyLabel = 'Icon',
	MoneyAbbreviate = 'None',
	ThousandsSeparator = 'Space',
	CurrencyAbbreviate = 'None',
	MoneyGoldOnly = false,
	MoneyColored = true,
	CurrencyGroupByHeader = true,
	CurrencyHideUnused = true,
	TrackAllRealms = true,
	MaxCharacters = 20,
	DefaultTooltip = addon.Util.IsMainline and 'Currency' or 'Money',
	ButtonDisplay = 'CharacterGold',
	TrackSessionGold = true,
	SessionDuration = 3600,
	SessionActivityCheckInterval = 600,
	ShowWoWToken = true,
	ShowNewCharacters = true
}

KrowiBCU_Options = KrowiBCU_Options or {}
for k, v in pairs(defaultOptions) do
	if KrowiBCU_Options[k] == nil then
		KrowiBCU_Options[k] = v
	end
end

local defaultSavedData = {
	CharacterData = {},
	SessionProfit = 0,
	SessionSpent = 0,
	SessionLastUpdate = 0
}

KrowiBCU_SavedData = KrowiBCU_SavedData or {}
for k, v in pairs(defaultSavedData) do
	if KrowiBCU_SavedData[k] == nil then
		KrowiBCU_SavedData[k] = v
	end
end

local function GetFontSize()
	local fontSize = 12
	if TitanPanelGetVar then
		return TitanPanelGetVar('FontSize') or fontSize
	end
	return select(2, GameFontNormal:GetFont()) or fontSize
end

function addon.GetOptionsForLib()
	local options = KrowiBCU_Options
	return {
		MoneyLabel = options.MoneyLabel,
		MoneyAbbreviate = options.MoneyAbbreviate,
		ThousandsSeparator = options.ThousandsSeparator,
		MoneyGoldOnly = options.MoneyGoldOnly,
		MoneyColored = options.MoneyColored,
		CurrencyAbbreviate = options.CurrencyAbbreviate,
		GoldLabel = addon.L['Gold Label'],
		SilverLabel = addon.L['Silver Label'],
		CopperLabel = addon.L['Copper Label'],
		TextureSize = GetFontSize()
	}
end

function addon.GetHeaderSettingKey(headerName)
	return 'ShowHeader_' .. headerName:gsub(' ', '_')
end

function addon:FormatMoney(value)
	return self.CurrencyLib:FormatMoney(value, self.GetOptionsForLib())
end

function addon:FormatCurrency(value)
	return self.CurrencyLib:FormatCurrency(value, self.GetOptionsForLib())
end

function addon.GetSessionProfit()
	return KrowiBCU_SavedData.SessionProfit or 0
end

function addon.GetSessionSpent()
	return KrowiBCU_SavedData.SessionSpent or 0
end

function addon.ResetSessionTracking()
	KrowiBCU_SavedData.SessionProfit = 0
	KrowiBCU_SavedData.SessionSpent = 0
	KrowiBCU_SavedData.SessionLastUpdate = time()
end

function addon.GetWarbandMoney()
	local warbandMoney = 0
	if C_Bank and C_Bank.FetchDepositedMoney and Enum and Enum.BankType then
		local money = C_Bank.FetchDepositedMoney(Enum.BankType.Account)
		if type(money) == 'number' then
			warbandMoney = money
		end
	end
	return warbandMoney
end

function addon:GetDisplayText()
	local displayMode = KrowiBCU_Options.ButtonDisplay
	local currentRealmName = GetRealmName() or 'Unknown'
	local currentFaction = UnitFactionGroup('player') or 'Neutral'

	if displayMode == 'CharacterGold' then
		return self:FormatMoney(GetMoney())
	elseif displayMode == 'FactionTotal' then
		return self:FormatMoney(self.CharacterData.GetFactionTotal(currentFaction))
	elseif displayMode == 'RealmTotal' then
		return self:FormatMoney(self.CharacterData.GetRealmTotal(currentRealmName))
	elseif displayMode == 'AccountTotal' then
		local accountTotal = self.CharacterData.GetAccountTotal()
		local warbandMoney = self.GetWarbandMoney()
		return self:FormatMoney(accountTotal + warbandMoney)
	elseif displayMode == 'WarbandBank' then
		local warbandMoney = self.GetWarbandMoney()
		return self:FormatMoney(warbandMoney)
	else
		return self:FormatMoney(GetMoney())
	end
end

local function OnClick(self, button)
	if button == 'LeftButton' then
		ToggleAllBags()
		return
	end

	if button ~= 'RightButton' then
		return
	end

	addon.Menu.ShowPopup(self)
end

local function OnEnter(self)
	addon.Tooltip.Show(self)

	local lastShiftState = IsShiftKeyDown()
	local lastCtrlState = IsLeftControlKeyDown() or IsRightControlKeyDown()
	local throttle = 0
	self:SetScript('OnUpdate', function(frame, elapsed)
		throttle = throttle + elapsed
		if throttle < 0.1 then return end
		throttle = 0

		local currentShiftState = IsShiftKeyDown()
		local currentCtrlState = IsLeftControlKeyDown() or IsRightControlKeyDown()
		if currentShiftState ~= lastShiftState or currentCtrlState ~= lastCtrlState then
			lastShiftState = currentShiftState
			lastCtrlState = currentCtrlState
			addon.Tooltip.Show(frame)
		end
	end)
end

local function OnLeave(self)
	self:SetScript('OnUpdate', nil)
	GameTooltip:Hide()
end

local function CheckSessionExpiration()
	local currentTime = time()
	local lastUpdate = KrowiBCU_SavedData.SessionLastUpdate or 0
	local duration = KrowiBCU_Options.SessionDuration or 3600

	if currentTime - lastUpdate > duration then
		KrowiBCU_SavedData.SessionProfit = 0
		KrowiBCU_SavedData.SessionSpent = 0
		KrowiBCU_SavedData.SessionLastUpdate = currentTime
		return true
	end
	return false
end

local sessionDataLoaded = false
local activityCheckTimer = nil
local function OnEvent(event, ...)
	if event == 'PLAYER_MONEY' or event == 'SEND_MAIL_MONEY_CHANGED' or
	   event == 'SEND_MAIL_COD_CHANGED' or event == 'PLAYER_TRADE_MONEY' or
	   event == 'TRADE_MONEY_CHANGED' then
		addon.CharacterData.UpdateCharacterData()
		addon.LDB:Update()
	elseif event == 'PLAYER_ENTERING_WORLD' then
		addon.CharacterData.UpdateCharacterData()
		addon.LDB:Update()

		if sessionDataLoaded then
			return
		end

		CheckSessionExpiration()
		sessionDataLoaded = true

		if activityCheckTimer then
			return
		end

		local interval = KrowiBCU_Options.SessionActivityCheckInterval or 600
		activityCheckTimer = C_Timer.NewTicker(interval, function()
			KrowiBCU_SavedData.SessionLastUpdate = time()
		end)
	end
end

addon.Broker:InitBroker(
	addonName,
	addon,
	OnEnter,
	OnLeave,
	OnClick,
	OnEvent
)
addon.Broker:RegisterEvents(
	'PLAYER_ENTERING_WORLD',
	'PLAYER_MONEY',
	'SEND_MAIL_MONEY_CHANGED',
	'SEND_MAIL_COD_CHANGED',
	'PLAYER_TRADE_MONEY',
	'TRADE_MONEY_CHANGED'
)