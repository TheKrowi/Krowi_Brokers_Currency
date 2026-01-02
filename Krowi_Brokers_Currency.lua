local addonName, addon = ...;

local currency = LibStub("Krowi_Currency-1.0");

addon.L = LibStub(addon.Libs.AceLocale):GetLocale(addonName);

KrowiBCU_SavedData = KrowiBCU_SavedData or {
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
	local options = KrowiBCU_SavedData;
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

local function GetFormattedMoney()
	local displayMode = KrowiBCU_SavedData.ButtonDisplay;
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

local function CheckSessionExpiration()
	local currentTime = time();
	local lastUpdate = KrowiBCU_SavedData.SessionLastUpdate or 0;
	local duration = KrowiBCU_SavedData.SessionDuration or 3600;

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
	if change ~= 0 and KrowiBCU_SavedData.TrackSessionGold then
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
		addon.TradersTenderLDB.Update();
	elseif event == "PLAYER_ENTERING_WORLD" then
		if not sessionDataLoaded then
			CheckSessionExpiration();
			sessionDataLoaded = true;

			if not activityCheckTimer then
				local interval = KrowiBCU_SavedData.SessionActivityCheckInterval or 600;
				activityCheckTimer = C_Timer.NewTicker(interval, function()
					UpdateSessionActivity();
				end);
			end
		end

		UpdateCharacterData();
		addon.TradersTenderLDB.Update();
	end
end

-- local function OnShow(self)
-- 	print("LDB OnShow");
--     self:RegisterEvent("PLAYER_MONEY");
-- 	self:RegisterEvent("SEND_MAIL_MONEY_CHANGED");
-- 	self:RegisterEvent("SEND_MAIL_COD_CHANGED");
-- 	self:RegisterEvent("PLAYER_TRADE_MONEY");
-- 	self:RegisterEvent("TRADE_MONEY_CHANGED");
-- 	addon.TradersTenderLDB.Update();
-- end

-- local function OnHide(self)
-- 	print("LDB OnHide");
--     self:UnregisterEvent("PLAYER_MONEY");
-- 	self:UnregisterEvent("SEND_MAIL_MONEY_CHANGED");
-- 	self:UnregisterEvent("SEND_MAIL_COD_CHANGED");
-- 	self:UnregisterEvent("PLAYER_TRADE_MONEY");
-- 	self:UnregisterEvent("TRADE_MONEY_CHANGED");
-- end

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

local function ShowTooltip(self, forceType)
	local tooltipType = forceType;
	if not tooltipType then
		local defaultTooltip = KrowiBCU_SavedData.DefaultTooltip;
		local shiftPressed = IsShiftKeyDown();
		local ctrlPressed = IsLeftControlKeyDown() or IsRightControlKeyDown();

		if defaultTooltip == addon.L["Combined"] then
			if ctrlPressed then
				tooltipType = addon.L["Currency"];
			elseif shiftPressed then
				tooltipType = addon.L["Money"];
			else
				tooltipType = addon.L["Combined"];
			end
		elseif defaultTooltip == addon.L["Money"] then
			tooltipType = shiftPressed and addon.L["Currency"] or addon.L["Money"];
		else
			tooltipType = shiftPressed and addon.L["Money"] or addon.L["Currency"];
		end
	end

	if tooltipType == addon.L["Money"] then
		addon.Tooltip.GetDetailedMoneyTooltip(self);
	elseif tooltipType == addon.L["Combined"] then
		addon.Tooltip.GetCombinedTooltip(self);
	else
		addon.Tooltip.GetAllCurrenciesTooltip(self);
	end
end

local function OnEnter(self)
	ShowTooltip(self);

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
			ShowTooltip(frame);
		end
	end);
end

local function OnLeave(self)
	GameTooltip:Hide();
	self:SetScript("OnUpdate", nil);
end

local function Create_Frames()
	local LDB = LibStub("LibDataBroker-1.1", true);
	if not LDB then
		return;
	end

	addon.Menu.Init();

	local TradersTenderLDB = LDB:NewDataObject("Krowi_Brokers_Currency", {
		type = "data source",
		tocname = "Krowi_Brokers_Currency",
		text = GetFormattedMoney(),
		icon = addon.Util.IsMainline and "interface\\icons\\inv_misc_curiouscoin" or "interface\\icons\\inv_misc_coin_01",
		category = "Information",
		OnEnter = OnEnter,
		OnLeave = OnLeave,
		OnClick = OnClick,
	});

	-- TradersTenderLDB.OnShow = OnShow;
	-- TradersTenderLDB.OnHide = OnHide;
	TradersTenderLDB.Update = function()
		TradersTenderLDB.text = GetFormattedMoney();
	end
	addon.TradersTenderLDB = TradersTenderLDB;

	local ldbFrame = CreateFrame("Frame");
	ldbFrame:RegisterEvent("PLAYER_ENTERING_WORLD");
    ldbFrame:RegisterEvent("PLAYER_MONEY");
	ldbFrame:RegisterEvent("SEND_MAIL_MONEY_CHANGED");
	ldbFrame:RegisterEvent("SEND_MAIL_COD_CHANGED");
	ldbFrame:RegisterEvent("PLAYER_TRADE_MONEY");
	ldbFrame:RegisterEvent("TRADE_MONEY_CHANGED");
	ldbFrame:SetScript("OnEvent", OnEvent);
end

Create_Frames();