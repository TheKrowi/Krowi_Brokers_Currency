local addonName, addon = ...;

local currency = LibStub("Krowi_Currency-1.0");

addon.L = LibStub(addon.Libs.AceLocale):GetLocale(addonName);

KrowiBCU_Options = KrowiBCU_Options or {
	HeaderSettings = {},
	MoneyLabel = "Icon",
	MoneyAbbreviate = "None",
	ThousandsSeparator = "Space",
	CurrencyAbbreviate = "None",
	MoneyGoldOnly = false,
	MoneyColored = true,
	CurrencyGroupByHeader = true,
	CurrencyHideUnused = true,
	TrackAllRealms = true,
	MaxCharacters = 20,
	DefaultTooltip = addon.Util.IsMainline and addon.L["Currency"] or addon.L["Money"],
	ButtonDisplay = addon.L["Character Gold"],
	TrackSessionGold = true,
	SessionDuration = 3600,
	SessionActivityCheckInterval = 600,
	ShowWoWToken = true
};

KrowiBCU_SavedData = KrowiBCU_SavedData or {
	CharacterData = {},
	SessionProfit = 0,
	SessionSpent = 0,
	SessionLastUpdate = 0
};

local function GetFontSize()
	local fontSize = 12;
	if TitanPanelGetVar then
		return TitanPanelGetVar("FontSize") or fontSize;
	end
	return select(2, GameFontNormal:GetFont()) or fontSize;
end

function addon.GetOptionsForLib()
	local options = KrowiBCU_Options;
	return {
		MoneyLabel = options.MoneyLabel,
		MoneyAbbreviate = options.MoneyAbbreviate,
		ThousandsSeparator = options.ThousandsSeparator,
		MoneyGoldOnly = options.MoneyGoldOnly,
		MoneyColored = options.MoneyColored,
		CurrencyAbbreviate = options.CurrencyAbbreviate,
		GoldLabel = addon.L["Gold Label"],
		SilverLabel = addon.L["Silver Label"],
		CopperLabel = addon.L["Copper Label"],
		TextureSize = GetFontSize()
	};
end

function addon.GetHeaderSettingKey(headerName)
	return "ShowHeader_" .. headerName:gsub(" ", "_");
end

function addon.FormatMoney(value)
	return currency:FormatMoney(value, addon.GetOptionsForLib());
end

function addon.FormatCurrency(value)
	return currency:FormatCurrency(value, addon.GetOptionsForLib());
end

function addon.GetSessionProfit()
	return KrowiBCU_SavedData.SessionProfit or 0;
end

function addon.GetSessionSpent()
	return KrowiBCU_SavedData.SessionSpent or 0;
end

function addon.ResetSessionTracking()
	KrowiBCU_SavedData.SessionProfit = 0;
	KrowiBCU_SavedData.SessionSpent = 0;
	KrowiBCU_SavedData.SessionLastUpdate = time();
end

function addon.GetWarbandMoney()
	local warbandMoney = 0;
	if C_Bank and C_Bank.FetchDepositedMoney and Enum and Enum.BankType then
		local money = C_Bank.FetchDepositedMoney(Enum.BankType.Account);
		if type(money) == "number" then
			warbandMoney = money;
		end
	end
	return warbandMoney;
end

function addon.GetDisplayText()
	local displayMode = KrowiBCU_Options.ButtonDisplay;
	local currentRealmName = GetRealmName() or "Unknown";
	local currentFaction = UnitFactionGroup("player") or "Neutral";
	local characterData = KrowiBCU_SavedData.CharacterData or {};

	if displayMode == addon.L["Character Gold"] then
		return addon.FormatMoney(GetMoney());
	elseif displayMode == addon.L["Current Faction Total"] then
		local factionTotal = 0;
		for _, char in pairs(characterData) do
			if char.faction == currentFaction then
				factionTotal = factionTotal + (char.money or 0);
			end
		end
		return addon.FormatMoney(factionTotal);
	elseif displayMode == addon.L["Realm Total"] then
		local realmTotal = 0;
		for _, char in pairs(characterData) do
			if char.realm == currentRealmName then
				realmTotal = realmTotal + (char.money or 0);
			end
		end
		return addon.FormatMoney(realmTotal);
	elseif displayMode == addon.L["Account Total"] then
		local accountTotal = 0;
		for _, char in pairs(characterData) do
			accountTotal = accountTotal + (char.money or 0);
		end
		local warbandMoney = addon.GetWarbandMoney();
		return addon.FormatMoney(accountTotal + warbandMoney);
	elseif displayMode == addon.L["Warband Bank"] then
		local warbandMoney = addon.GetWarbandMoney();
		return addon.FormatMoney(warbandMoney);
	else
		return addon.FormatMoney(GetMoney());
	end
end

local function OnClick(self, button)
	if button == "LeftButton" then
		ToggleAllBags();
		return;
	end

	if button ~= "RightButton" then
		return;
	end

	addon.Menu.ShowPopup();
end

local function OnEnter(self)
	addon.Tooltip.Show(self);

	local lastShiftState = IsShiftKeyDown();
	local lastCtrlState = IsLeftControlKeyDown() or IsRightControlKeyDown();
	local throttle = 0;
	self:SetScript("OnUpdate", function(frame, elapsed)
		throttle = throttle + elapsed;
		if throttle < 0.1 then return; end
		throttle = 0;

		local currentShiftState = IsShiftKeyDown();
		local currentCtrlState = IsLeftControlKeyDown() or IsRightControlKeyDown();
		if currentShiftState ~= lastShiftState or currentCtrlState ~= lastCtrlState then
			lastShiftState = currentShiftState;
			lastCtrlState = currentCtrlState;
			addon.Tooltip.Show(frame);
		end
	end);
end

local function OnLeave(self)
	self:SetScript("OnUpdate", nil);
	GameTooltip:Hide();
end

function addon.Init()
	addon.Menu.Init();
	addon.Tooltip.Init();

	local dataObject = LibStub("LibDataBroker-1.1"):NewDataObject(addonName, {
		type = "data source",
		tocname = addonName,
		icon = addon.Util.IsMainline and "interface\\icons\\inv_misc_curiouscoin" or "interface\\icons\\inv_misc_coin_01",
		text = addon.Metadata.Title .. " " .. addon.Metadata.Version,
		category = "Information",
		OnEnter = OnEnter,
		OnLeave = OnLeave,
		OnClick = OnClick,
	});

	function dataObject:Update()
		self.text = addon.GetDisplayText();
	end

	dataObject:Update();

	addon.TradersTenderLDB = dataObject;
end

addon.Init()

local function CheckSessionExpiration()
	local currentTime = time();
	local lastUpdate = KrowiBCU_SavedData.SessionLastUpdate or 0;
	local duration = KrowiBCU_Options.SessionDuration or 3600;

	if currentTime - lastUpdate > duration then
		KrowiBCU_SavedData.SessionProfit = 0;
		KrowiBCU_SavedData.SessionSpent = 0;
		KrowiBCU_SavedData.SessionLastUpdate = currentTime;
		return true;
	end
	return false;
end

local function UpdateSessionActivity()
	KrowiBCU_SavedData.SessionLastUpdate = time();
end

local function UpdateCharacterData()
	local playerName = UnitName("player") or "Unknown";
	local realmName = GetRealmName() or "Unknown";
	local currentMoney = GetMoney();
	local faction = UnitFactionGroup("player") or "Neutral";
	local _, className = UnitClass("player");
	local characterKey = playerName .. "-" .. realmName;

	local characterData = KrowiBCU_SavedData.CharacterData or {};

	local oldData = characterData[characterKey];
	local oldMoney = (oldData and oldData.money) or currentMoney;

	local change = currentMoney - oldMoney;
	if change ~= 0 and KrowiBCU_Options.TrackSessionGold then
		if change > 0 then
			KrowiBCU_SavedData.SessionProfit = (KrowiBCU_SavedData.SessionProfit or 0) + change;
		elseif change < 0 then
			KrowiBCU_SavedData.SessionSpent = (KrowiBCU_SavedData.SessionSpent or 0) - change;
		end
		UpdateSessionActivity();
	end

	characterData[characterKey] = {
		name = playerName,
		realm = realmName,
		money = currentMoney,
		faction = faction,
		className = className,
	};

	KrowiBCU_SavedData.CharacterData = characterData;
end

local sessionDataLoaded = false;
local activityCheckTimer = nil;
local function OnEvent(self, event, ...)
	if event == "PLAYER_MONEY" or event == "SEND_MAIL_MONEY_CHANGED" or
	   event == "SEND_MAIL_COD_CHANGED" or event == "PLAYER_TRADE_MONEY" or
	   event == "TRADE_MONEY_CHANGED" then
		UpdateCharacterData();
		addon.TradersTenderLDB:Update();
	elseif event == "PLAYER_ENTERING_WORLD" then
		if not sessionDataLoaded then
			CheckSessionExpiration();
			sessionDataLoaded = true;

			if not activityCheckTimer then
				local interval = KrowiBCU_Options.SessionActivityCheckInterval or 600;
				activityCheckTimer = C_Timer.NewTicker(interval, function()
					UpdateSessionActivity();
				end);
			end
		end

		UpdateCharacterData();
		addon.TradersTenderLDB:Update();
	end
end

local eventFrame = Krowi_Brokers_EventFrame or CreateFrame("Frame", "Krowi_Brokers_EventFrame");
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD");
eventFrame:RegisterEvent("PLAYER_MONEY");
eventFrame:RegisterEvent("SEND_MAIL_MONEY_CHANGED");
eventFrame:RegisterEvent("SEND_MAIL_COD_CHANGED");
eventFrame:RegisterEvent("PLAYER_TRADE_MONEY");
eventFrame:RegisterEvent("TRADE_MONEY_CHANGED");
eventFrame:SetScript("OnEvent", OnEvent);