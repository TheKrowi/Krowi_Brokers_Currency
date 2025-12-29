local _, addon = ...;

local menu = {};
addon.Menu = menu;

local menuBuilder;

function menu.Init()
	local lib = LibStub("Krowi_MenuBuilder-1.0");

	menuBuilder = lib:New({
		uniqueTag = "KBC_RIGHT_CLICK_MENU_OPTIONS",
		callbacks = {
			OnCheckboxSelect = function(filters, keys)
				addon.Util.WriteNestedKeys(filters, keys, not menuBuilder:KeyIsTrue(filters, keys));
				addon.TradersTenderLDB.Update();
			end,

			OnRadioSelect = function(filters, keys, value)
				addon.Util.WriteNestedKeys(filters, keys, value);
				addon.TradersTenderLDB.Update();
			end
		}
	});
end

-- Custom checkbox for parent headers that also update children
local function CreateParentHeaderCheckbox(parentMenu, text, setKey, headerEntry)
	return menuBuilder:CreateCustomCheckbox(
		parentMenu,
		text,
		function()
            return menuBuilder:KeyIsTrue(KrowiBCU_SavedData, {"HeaderSettings", setKey})
        end,
		function()
			local filters, keys = KrowiBCU_SavedData, {"HeaderSettings", setKey};
			local currentValue = addon.Util.ReadNestedKeys(filters, keys);
			if currentValue == nil then currentValue = true; end
			local newValue = not currentValue;
			addon.Util.WriteNestedKeys(filters, keys, newValue);
			addon.Currency.UpdateChildHeaders(headerEntry, newValue);
			addon.TradersTenderLDB.Update();
		end
	);
end

local function CreateHeaderMenu(parentMenu, headerEntry)
	local settingKey = addon.GetHeaderSettingKey(headerEntry.name);
	local hasChildren = next(headerEntry.children);

	if not hasChildren then
		menuBuilder:CreateCheckbox(parentMenu, headerEntry.name, KrowiBCU_SavedData, {"HeaderSettings", settingKey});
		return;
	end

	local headerSubmenu = menuBuilder:CreateSubmenuButton(parentMenu, headerEntry.name);
	CreateParentHeaderCheckbox(headerSubmenu, "Show " .. headerEntry.name, settingKey, headerEntry);
	menuBuilder:CreateDivider(headerSubmenu);

	for _, childHeader in pairs(headerEntry.children) do
		CreateHeaderMenu(headerSubmenu, childHeader);
	end

	menuBuilder:AddChildMenu(parentMenu, headerSubmenu);
end

function menu.CreateMenu(self, menuObj)
	menuBuilder:CreateTitle(menuObj, addon.L["Currency by Krowi"]);

	menuBuilder:CreateDivider(menuObj);
	menuBuilder:CreateTitle(menuObj, addon.L["Button Display"]);

	local buttonDisplay = menuBuilder:CreateSubmenuButton(menuObj, addon.L["Show On Button"]);
	menuBuilder:CreateRadio(buttonDisplay, addon.L["Character Gold"], KrowiBCU_SavedData, {"ButtonDisplay"});
	menuBuilder:CreateRadio(buttonDisplay, addon.L["Current Faction Total"], KrowiBCU_SavedData, {"ButtonDisplay"});
	menuBuilder:CreateRadio(buttonDisplay, addon.L["Realm Total"], KrowiBCU_SavedData, {"ButtonDisplay"});
	menuBuilder:CreateRadio(buttonDisplay, addon.L["Account Total"], KrowiBCU_SavedData, {"ButtonDisplay"});
	if addon.Util.IsMainline then
		menuBuilder:CreateRadio(buttonDisplay, addon.L["Warband Bank"], KrowiBCU_SavedData, {"ButtonDisplay"});
	end
	menuBuilder:AddChildMenu(menuObj, buttonDisplay);

	menuBuilder:CreateDivider(menuObj);
	menuBuilder:CreateTitle(menuObj, addon.L["Tooltip Options"]);

	local defaultTooltip = menuBuilder:CreateSubmenuButton(menuObj, addon.L["Default Tooltip"]);
	menuBuilder:CreateRadio(defaultTooltip, addon.L["Currency"], KrowiBCU_SavedData, {"DefaultTooltip"});
	menuBuilder:CreateRadio(defaultTooltip, addon.L["Money"], KrowiBCU_SavedData, {"DefaultTooltip"});
	menuBuilder:CreateRadio(defaultTooltip, addon.L["Combined"], KrowiBCU_SavedData, {"DefaultTooltip"});
	menuBuilder:AddChildMenu(menuObj, defaultTooltip);

	menuBuilder:CreateDivider(menuObj);
	menuBuilder:CreateTitle(menuObj, addon.L["Money Options"]);

	local moneyLabel = menuBuilder:CreateSubmenuButton(menuObj, addon.L["Money Label"]);
	menuBuilder:CreateRadio(moneyLabel, addon.L["None"], KrowiBCU_SavedData, {"MoneyLabel"});
	menuBuilder:CreateRadio(moneyLabel, addon.L["Text"], KrowiBCU_SavedData, {"MoneyLabel"});
	menuBuilder:CreateRadio(moneyLabel, addon.L["Icon"], KrowiBCU_SavedData, {"MoneyLabel"});
	menuBuilder:AddChildMenu(menuObj, moneyLabel);

	local moneyAbbreviate = menuBuilder:CreateSubmenuButton(menuObj, addon.L["Money Abbreviate"]);
	menuBuilder:CreateRadio(moneyAbbreviate, addon.L["None"], KrowiBCU_SavedData, {"MoneyAbbreviate"});
	menuBuilder:CreateRadio(moneyAbbreviate, addon.L["1k"], KrowiBCU_SavedData, {"MoneyAbbreviate"});
	menuBuilder:CreateRadio(moneyAbbreviate, addon.L["1m"], KrowiBCU_SavedData, {"MoneyAbbreviate"});
	menuBuilder:AddChildMenu(menuObj, moneyAbbreviate);

	local thousandsSeparator = menuBuilder:CreateSubmenuButton(menuObj, addon.L["Thousands Separator"]);
	menuBuilder:CreateRadio(thousandsSeparator, addon.L["Space"], KrowiBCU_SavedData, {"ThousandsSeparator"});
	menuBuilder:CreateRadio(thousandsSeparator, addon.L["Period"], KrowiBCU_SavedData, {"ThousandsSeparator"});
	menuBuilder:CreateRadio(thousandsSeparator, addon.L["Comma"], KrowiBCU_SavedData, {"ThousandsSeparator"});
	menuBuilder:AddChildMenu(menuObj, thousandsSeparator);

	menuBuilder:CreateCheckbox(menuObj, addon.L["Money Gold Only"], KrowiBCU_SavedData, {"MoneyGoldOnly"});
	menuBuilder:CreateCheckbox(menuObj, addon.L["Money Colored"], KrowiBCU_SavedData, {"MoneyColored"});

	local maxCharsMenu = menuBuilder:CreateSubmenuButton(menuObj, addon.L["Max Characters"]);
	menuBuilder:CreateRadio(maxCharsMenu, "5", KrowiBCU_SavedData, {"MaxCharacters"}, 5);
	menuBuilder:CreateRadio(maxCharsMenu, "10", KrowiBCU_SavedData, {"MaxCharacters"}, 10);
	menuBuilder:CreateRadio(maxCharsMenu, "15", KrowiBCU_SavedData, {"MaxCharacters"}, 15);
	menuBuilder:CreateRadio(maxCharsMenu, "20", KrowiBCU_SavedData, {"MaxCharacters"}, 20);
	menuBuilder:CreateRadio(maxCharsMenu, "25", KrowiBCU_SavedData, {"MaxCharacters"}, 25);
	menuBuilder:CreateRadio(maxCharsMenu, "30", KrowiBCU_SavedData, {"MaxCharacters"}, 30);
	menuBuilder:AddChildMenu(menuObj, maxCharsMenu);

	menuBuilder:CreateCheckbox(menuObj, addon.L["Track All Realms"], KrowiBCU_SavedData, {"TrackAllRealms"});

	-- Custom checkbox with special handling for session tracking
	menuBuilder:CreateCustomCheckbox(
		menuObj,
		addon.L["Track Session Gold"],
		function()
            return menuBuilder:KeyIsTrue(KrowiBCU_SavedData, {"TrackSessionGold"})
        end,
		function()
			local filters, keys = KrowiBCU_SavedData, {"TrackSessionGold"};
			local value = addon.Util.ReadNestedKeys(filters, keys);
			if value == nil then value = true; end
			local newValue = not value;
			addon.Util.WriteNestedKeys(filters, keys, newValue);

			if not newValue then
				addon.ResetSessionTracking();
			end
			addon.TradersTenderLDB.Update();
		end
	);

	local sessionDuration = menuBuilder:CreateSubmenuButton(menuObj, addon.L["Session Duration"]);
	menuBuilder:CreateRadio(sessionDuration, addon.L["1 Hour"], KrowiBCU_SavedData, {"SessionDuration"}, 3600);
	menuBuilder:CreateRadio(sessionDuration, addon.L["2 Hours"], KrowiBCU_SavedData, {"SessionDuration"}, 7200);
	menuBuilder:CreateRadio(sessionDuration, addon.L["4 Hours"], KrowiBCU_SavedData, {"SessionDuration"}, 14400);
	menuBuilder:CreateRadio(sessionDuration, addon.L["8 Hours"], KrowiBCU_SavedData, {"SessionDuration"}, 28800);
	menuBuilder:CreateRadio(sessionDuration, addon.L["12 Hours"], KrowiBCU_SavedData, {"SessionDuration"}, 43200);
	menuBuilder:CreateRadio(sessionDuration, addon.L["24 Hours"], KrowiBCU_SavedData, {"SessionDuration"}, 86400);
	menuBuilder:CreateRadio(sessionDuration, addon.L["48 Hours"], KrowiBCU_SavedData, {"SessionDuration"}, 172800);
	menuBuilder:AddChildMenu(menuObj, sessionDuration);

	menuBuilder:CreateCheckbox(menuObj, addon.L["Show WoW Token"], KrowiBCU_SavedData, {"ShowWoWToken"});

	menuBuilder:CreateDivider(menuObj);
	menuBuilder:CreateTitle(menuObj, addon.L["Currency Options"]);

	local currencyAbbreviate = menuBuilder:CreateSubmenuButton(menuObj, addon.L["Currency Abbreviate"]);
	menuBuilder:CreateRadio(currencyAbbreviate, addon.L["None"], KrowiBCU_SavedData, {"CurrencyAbbreviate"});
	menuBuilder:CreateRadio(currencyAbbreviate, addon.L["1k"], KrowiBCU_SavedData, {"CurrencyAbbreviate"});
	menuBuilder:CreateRadio(currencyAbbreviate, addon.L["1m"], KrowiBCU_SavedData, {"CurrencyAbbreviate"});
	menuBuilder:AddChildMenu(menuObj, currencyAbbreviate);

	menuBuilder:CreateCheckbox(menuObj, addon.L["Currency Group By Header"], KrowiBCU_SavedData, {"CurrencyGroupByHeader"});
	menuBuilder:CreateCheckbox(menuObj, addon.L["Currency Hide Unused"], KrowiBCU_SavedData, {"CurrencyHideUnused"});

	local headerVisibility = menuBuilder:CreateSubmenuButton(menuObj, addon.L["Header Visibility"]);
	local structuredHeaders, orderedHeaderNames = addon.Currency.GetAllCurrenciesWithHeader();
	for _, headerName in ipairs(orderedHeaderNames) do
		local headerEntry = structuredHeaders[headerName];
		if headerEntry then
			CreateHeaderMenu(headerVisibility, headerEntry);
		end
	end
	menuBuilder:AddChildMenu(menuObj, headerVisibility);
end

-- Show the menu popup
function menu.ShowPopup()
	menuBuilder:ShowPopup(function()
		local menuObj = menuBuilder:GetMenu();
		menu.CreateMenu(nil, menuObj);
	end);
end
