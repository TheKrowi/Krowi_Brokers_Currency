local addonName, addon = ...;

addon.L = LibStub(addon.Libs.AceLocale):GetLocale(addonName);

KrowiBCU_SavedData = KrowiBCU_SavedData or {
	HeaderSettings = {},
	MoneyLabel = addon.L["Icon"],
	MoneyAbbreviate = addon.L["None"],
	ThousandsSeparator = addon.L["Space"],
	CurrencyAbbreviate = addon.L["None"],
	MoneyGoldOnly = false,
	MoneyColored = true,
	CurrencyGroupByHeader = true,
	CurrencyHideUnused = true,
	TrackAllRealms = true,
	MaxCharacters = 20,
	DefaultTooltip = addon.L["Currency"],
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

function addon.AbbreviateValue(value, abbreviateK, abbreviateM)
	if abbreviateK and value >= 1000 then
		return math.floor(value / 1000), "k";
	elseif abbreviateM and value >= 1000000 then
		return math.floor(value / 1000000), "m";
	end
	return value, "";
end

function addon.GetSeparators()
	if (KrowiBCU_SavedData.ThousandsSeparator == addon.L["Space"]) then
		return " ", ".";
	elseif (KrowiBCU_SavedData.ThousandsSeparator == addon.L["Period"]) then
		return ".", ",";
	elseif (KrowiBCU_SavedData.ThousandsSeparator == addon.L["Comma"]) then
		return ",", ".";
	end
	return "", "";
end

function addon.GetHeaderSettingKey(headerName)
	return "ShowHeader_" .. headerName:gsub(" ", "_");
end

local function BreakMoney(value)
	return math.floor(value / 10000), math.floor((value % 10000) / 100), value % 100;
end

local function GetFontSize()
	local fontSize = 12;
	if TitanPanelGetVar then
		return TitanPanelGetVar("FontSize") or fontSize;
	end
	return select(2, GameFontNormal:GetFont()) or fontSize;
end

function addon.NumToString(amount, thousands_separator, decimal_separator)
	if type(amount) ~= "number" then
		return "0";
	end

	if amount > 99999999999999 then
		return tostring(amount);
	end

	local sign, int, frac = tostring(amount):match('([-]?)(%d+)([.]?%d*)');
	int = int:reverse():gsub("(%d%d%d)", "%1|");
	int = int:reverse():gsub("^|", "");
	int = int:gsub("%.", decimal_separator);
	int = int:gsub("|", thousands_separator);

	return sign .. int .. frac;
end

function addon.FormatMoney(value)
	local thousandsSeparator, decimalSeparator = addon.GetSeparators();

	local gold, silver, copper, abbr = BreakMoney(value);

	local moneyAbbreviateK = KrowiBCU_SavedData.MoneyAbbreviate == addon.L["1k"];
	local moneyAbbreviateM = KrowiBCU_SavedData.MoneyAbbreviate == addon.L["1m"];
	gold, abbr = addon.AbbreviateValue(gold, moneyAbbreviateK, moneyAbbreviateM);
	gold = addon.NumToString(gold, thousandsSeparator, decimalSeparator);

	local goldLabel, silverLabel, copperLabel = "", "", "";
	if KrowiBCU_SavedData.MoneyLabel == addon.L["Text"] then
		goldLabel = addon.L["Gold Label"];
		silverLabel = addon.L["Silver Label"];
		copperLabel = addon.L["Copper Label"];
	elseif KrowiBCU_SavedData.MoneyLabel == addon.L["Icon"] then
		local font_size = GetFontSize();
		local icon_pre = "|TInterface\\MoneyFrame\\";
		local icon_post = ":" .. font_size .. ":" .. font_size .. ":2:0|t";
		goldLabel = icon_pre .. "UI-GoldIcon" .. icon_post;
		silverLabel = icon_pre .. "UI-SilverIcon" .. icon_post;
		copperLabel = icon_pre .. "UI-CopperIcon" .. icon_post;
	end

	local colors = KrowiBCU_SavedData.MoneyColored and {
		coin_gold = "ffd100",
		coin_silver = "e6e6e6",
		coin_copper = "c8602c",
	} or {
        coin_gold = "ffffff",
        coin_silver = "ffffff",
        coin_copper = "ffffff",
    };

	local outstr = "|cff" .. colors.coin_gold .. gold .. abbr .. goldLabel .. "|r";

	if not KrowiBCU_SavedData.MoneyGoldOnly then
		outstr = outstr .. " " .. "|cff" .. colors.coin_silver .. silver .. silverLabel .. "|r";
		outstr = outstr .. " " .. "|cff" .. colors.coin_copper .. copper .. copperLabel .. "|r";
	end

	return outstr;
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

local function OnShow(self)
    self:RegisterEvent("PLAYER_MONEY");
	self:RegisterEvent("SEND_MAIL_MONEY_CHANGED");
	self:RegisterEvent("SEND_MAIL_COD_CHANGED");
	self:RegisterEvent("PLAYER_TRADE_MONEY");
	self:RegisterEvent("TRADE_MONEY_CHANGED");
	addon.TradersTenderLDB.Update();
end

local function OnHide(self)
    self:UnregisterEvent("PLAYER_MONEY");
	self:UnregisterEvent("SEND_MAIL_MONEY_CHANGED");
	self:UnregisterEvent("SEND_MAIL_COD_CHANGED");
	self:UnregisterEvent("PLAYER_TRADE_MONEY");
	self:UnregisterEvent("TRADE_MONEY_CHANGED");
end

local function OnClick(self, button)
	if button == "LeftButton" then
		ToggleAllBags();
		return;
	end

	if button ~= "RightButton" then
		return;
	end

	if addon.Util.IsTheWarWithin then
		MenuUtil.CreateContextMenu(self, function(owner, menuObj)
			menuObj:SetTag("KTPC_RIGHT_CLICK_MENU_OPTIONS");
			addon.Menu.CreateMenu(self, menuObj);
		end);
	else
		local rightClickMenu = LibStub("Krowi_Menu-1.0");
		rightClickMenu:Clear();
		addon.Menu.CreateMenu(self, rightClickMenu);
		rightClickMenu:Open();
	end
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

	local TradersTenderLDB = LDB:NewDataObject("Krowi_Brokers_Currency", {
		type = "data source",
		tocname = "Krowi_Brokers_Currency",
		text = GetFormattedMoney(),
		icon = "interface\\icons\\inv_misc_curiouscoin",
		category = "Information",
	});

	TradersTenderLDB.OnShow = OnShow;
	TradersTenderLDB.OnHide = OnHide;
	TradersTenderLDB.OnClick = OnClick;
	TradersTenderLDB.OnEnter = OnEnter;
	TradersTenderLDB.OnLeave = OnLeave;
	TradersTenderLDB.Update = function()
		TradersTenderLDB.text = GetFormattedMoney();
	end
	addon.TradersTenderLDB = TradersTenderLDB;

	local ldbFrame = CreateFrame("Frame");
	ldbFrame:RegisterEvent("PLAYER_ENTERING_WORLD");
	ldbFrame:SetScript("OnEvent", OnEvent);
end

Create_Frames();