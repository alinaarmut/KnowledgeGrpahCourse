-- Copyright 2017-2018, Firaxis Games
-- AKA: "City Details", (Left) side panel with details on a selected city

include( "AdjacencyBonusSupport" );		-- GetAdjacentYieldBonusString()
include( "Civ6Common" );				-- GetYieldString()
include( "InstanceManager" );
include( "ToolTipHelper" );	
include( "SupportFunctions" );			-- Round(), Clamp()
include( "TabSupport" );
include( "CitySupport" );
include( "EspionageViewManager" );

-- ===========================================================================
--	CONSTANTS
-- ===========================================================================
local DATA_DOMINANT_RELIGION		:string = "_DOMINANTRELIGION";
local RELOAD_CACHE_ID				:string = "CityPanelOverview";
local SIZE_LEADER_ICON				:number = 32;
local SIZE_CITYSTATE_ICON			:number = 30;
local SIZE_PRODUCTION_ICON			:number = 32;	-- TODO: Switch this to 38 when the icons go in.
local SIZE_PANEL_X					:number = 300;
local TXT_NO_PRODUCTION				:string = Locale.Lookup("LOC_HUD_CITY_PRODUCTION_NOTHING_PRODUCED");

local UV_CITIZEN_GROWTH_STATUS		:table	= {};
		UV_CITIZEN_GROWTH_STATUS[0] = {u=0, v=0  };		-- revolt
		UV_CITIZEN_GROWTH_STATUS[1] = {u=0, v=0 };		-- unrest
		UV_CITIZEN_GROWTH_STATUS[2] = {u=0, v=0};		-- unhappy
		UV_CITIZEN_GROWTH_STATUS[3] = {u=0, v=50};		-- displeased
		UV_CITIZEN_GROWTH_STATUS[4] = {u=0, v=100};		-- content (normal)
		UV_CITIZEN_GROWTH_STATUS[5] = {u=0, v=150};		-- happy
		UV_CITIZEN_GROWTH_STATUS[6] = {u=0, v=200};		-- ecstatic

local UV_HOUSING_GROWTH_STATUS		:table = {};
		UV_HOUSING_GROWTH_STATUS[0] = {u=0, v=0};		-- halted
		UV_HOUSING_GROWTH_STATUS[1] = {u=0, v=50};		-- slowed
		UV_HOUSING_GROWTH_STATUS[2] = {u=0, v=100};		-- normal

local UV_CITIZEN_STARVING_STATUS		:table = {};
		UV_CITIZEN_STARVING_STATUS[0] = {u=0, v=0};		-- starving
		UV_CITIZEN_STARVING_STATUS[1] = {u=0, v=100};	-- normal
		UV_CITIZEN_STARVING_STATUS[2] = {u=0, v=150};	-- growing


local YIELD_STATE :table = {
		NORMAL  = 0,
		FAVORED = 1,
		IGNORED = 2
}

-- ===========================================================================
--	GLOBALS
-- ===========================================================================
g_kAmenitiesIM			= InstanceManager:new( "AmenityInstance",			"Top", Controls.AmenityStack );

-- ===========================================================================
--	MEMBERS
-- ===========================================================================

local m_kBuildingsIM		:table = InstanceManager:new( "BuildingInstance",			"Top");
local m_kDistrictsIM		:table = InstanceManager:new( "DistrictInstance",			"Top", Controls.BuildingAndDistrictsStack );
local m_kHousingIM			:table = InstanceManager:new( "HousingInstance",			"Top", Controls.HousingStack );
local m_kOtherReligionsIM	:table = InstanceManager:new( "OtherReligionInstance",		"Top", Controls.OtherReligions );
local m_kProductionIM		:table = InstanceManager:new( "ProductionInstance",			"Top", Controls.ProductionQueueStack );
local m_kReligionsBeliefsIM	:table = InstanceManager:new( "ReligionBeliefsInstance",	"Top", Controls.ReligionBeliefsStack );
local m_kTradingPostsIM		:table = InstanceManager:new( "TradingPostInstance",		"Top", Controls.TradingPostsStack );
local m_kWondersIM			:table = InstanceManager:new( "WonderInstance",				"Top", Controls.WondersStack );
local m_kKeyStackIM			:table = InstanceManager:new( "KeyEntry",					"KeyColorImage", Controls.KeyStack );

local m_isInitializing	:boolean = false;		
local m_kData			:table = nil;
local m_pCity			:table = nil;
local m_pPlayer			:table = nil;
local m_desiredLens		:string = "Default";
 
local ms_eventID		:number = 0;
local m_isShowingPanel	:boolean = false;

local m_kTabButtonIM		= InstanceManager:new( "TabButtonInstance",	"Button", Controls.TabContainer );
local m_tabs				= nil;

local m_kEspionageViewManager = EspionageViewManager:CreateManager();

-- ===========================================================================
function HideAll()
	Controls.HealthButton:SetSelected(false);
	Controls.HealthIcon:SetColorByName("White");
	Controls.BuildingsButton:SetSelected(false);
	Controls.BuildingsIcon:SetColorByName("White");
	Controls.ReligionButton:SetSelected(false);
	Controls.ReligionIcon:SetColorByName("White");

	Controls.PanelBreakdown:SetHide(true);
	Controls.PanelReligion:SetHide(true);
	Controls.PanelAmenities:SetHide(true);
	Controls.PanelHousing:SetHide(true);
	Controls.PanelCitizensGrowth:SetHide(true);
	Controls.PanelProductionNow:SetHide(true);
	Controls.PanelQueue:SetHide(true);
	Controls.PanelDynamicTab:SetHide(true);
end

-- ===========================================================================
function OnSelectHealthTab()
	HideAll();
	Controls.HealthButton:SetSelected(true);
	Controls.HealthIcon:SetColorByName("DarkBlue");
	
	if(m_kData ~= nil) then
        UI.PlaySound("UI_CityPanel_ButtonClick");
		ViewPanelAmenities( m_kData );
		ViewPanelCitizensGrowth( m_kData );
		ViewPanelHousing( m_kData );

		if m_kData.Owner == Game.GetLocalPlayer() then
			UILens.SetActive("CityDetails");
		else
			UILens.SetActive("EnemyCityDetails");
			LuaEvents.ShowEnemyCityDetails( m_kData.Owner, m_kData.City:GetID() );
		end
	end

	Controls.PanelAmenities:SetHide(false);
	Controls.PanelHousing:SetHide(false);
	Controls.PanelCitizensGrowth:SetHide(false);
end

-- ===========================================================================
function OnSelectBuildingsTab()
	HideAll();

	Controls.BuildingsButton:SetSelected(true);
	Controls.BuildingsIcon:SetColorByName("DarkBlue");
	UI.PlaySound("UI_CityPanel_ButtonClick");
	
	if(m_kData ~= nil) then
		ViewPanelBreakdown( m_kData );

		if m_kData.Owner == Game.GetLocalPlayer() then
			UILens.SetActive("CityDetails");
		else
			UILens.SetActive("EnemyCityDetails");
			LuaEvents.ShowEnemyCityDetails( m_kData.Owner, m_kData.City:GetID() );
		end
	end

	Controls.PanelBreakdown:SetHide(false);
end

-- ===========================================================================
function OnSelectReligionTab()
	HideAll();
	Controls.ReligionButton:SetSelected(true);
	Controls.ReligionIcon:SetColorByName("DarkBlue");
	UI.PlaySound("UI_CityPanel_ButtonClick");
	
	Controls.PanelReligion:SetHide(false);

	if(m_kData ~= nil) then
		ViewPanelReligion( m_kData );
	end
end

-- ===========================================================================
function ViewPanelBreakdown( data:table )	
	Controls.DistrictsNum:SetText( data.DistrictsNum );
	Controls.DistrictsConstructed:SetText( Locale.Lookup("LOC_HUD_CITY_DISTRICTS_CONSTRUCTED", data.DistrictsNum) );	
	Controls.DistrictsPossibleNum:SetText( data.DistrictsPossibleNum );

	m_kBuildingsIM:ResetInstances();
	m_kDistrictsIM:ResetInstances();	
	m_kTradingPostsIM:ResetInstances();
	m_kWondersIM:ResetInstances();
	local playerID = Game.GetLocalPlayer();

	-- Add districts (and their buildings)
	for _, district in ipairs(data.BuildingsAndDistricts) do
		if district.isBuilt then
			local kInstanceDistrict:table = m_kDistrictsIM:GetInstance();
			local districtName = district.Name;
			if district.isPillaged then
				districtName = districtName .. "[ICON_Pillaged]";
			end
			kInstanceDistrict.DistrictName:SetText( districtName );
			kInstanceDistrict.DistrictYield:SetText( district.YieldBonus );
			kInstanceDistrict.Icon:SetIcon( district.Icon );
			local sToolTip = ToolTipHelper.GetToolTip(district.Type, playerID)
			kInstanceDistrict.Top:SetToolTipString( sToolTip);
			for _,building in ipairs(district.Buildings) do
				if building.isBuilt then
					local kInstanceBuild:table = m_kBuildingsIM:GetInstance(kInstanceDistrict.BuildingStack);
					local buildingName = building.Name;
					if building.isPillaged then
						buildingName = buildingName .. "[ICON_Pillaged]";
					end
					kInstanceBuild.BuildingName:SetText( buildingName );
					kInstanceBuild.Icon:SetIcon( building.Icon );
					local pRow = GameInfo.Buildings[building.Type];
					local sToolTip = ToolTipHelper.GetBuildingToolTip( pRow.Hash, playerID, m_pCity );
					kInstanceBuild.Top:SetToolTipString( sToolTip);
					local yieldString:string = "";
					for _,kYield in ipairs(building.Yields) do
						yieldString = yieldString .. GetYieldString(kYield.YieldType,kYield.YieldChange);
					end
					kInstanceBuild.BuildingYield:SetText( yieldString );
					kInstanceBuild.BuildingYield:SetTruncateWidth( kInstanceBuild.Top:GetSizeX() - kInstanceBuild.BuildingName:GetSizeX() - 10 );
				end
			end
			kInstanceDistrict.BuildingStack:CalculateSize();
		end
	end

	-- Add wonders
	local hideWondersInfo :boolean = not GameCapabilities.HasCapability("CAPABILITY_CITY_HUD_WONDERS");
	local isHasWonders :boolean = (table.count(data.Wonders) > 0)
	Controls.NoWondersArea:SetHide(hideWondersInfo or isHasWonders);
	Controls.WondersArea:SetHide(hideWondersInfo or not isHasWonders);
	Controls.WondersHeader:SetHide(hideWondersInfo);

	for _, wonder in ipairs(data.Wonders) do
		local kInstanceWonder:table = m_kWondersIM:GetInstance();
		kInstanceWonder.WonderName:SetText( wonder.Name );
		local pRow = GameInfo.Buildings[wonder.Type];
		local sToolTip = ToolTipHelper.GetBuildingToolTip( pRow.Hash, playerID, m_pCity );
		kInstanceWonder.Top:SetToolTipString( sToolTip );
		local yieldString:string = "";
		for _,kYield in ipairs(wonder.Yields) do
			yieldString = yieldString .. GetYieldString(kYield.YieldType,kYield.YieldChange);
		end
		kInstanceWonder.WonderYield:SetText( yieldString );
		kInstanceWonder.Icon:SetIcon( wonder.Icon );
	end

	-- Add trading posts
	local hideTradingPostsInfo :boolean = not GameCapabilities.HasCapability("CAPABILITY_CITY_HUD_TRADING_POSTS");
	local isHasTradingPosts :boolean = (table.count(data.TradingPosts) > 0);
	Controls.NoTradingPostsArea:SetHide(hideTradingPostsInfo or isHasTradingPosts);
	Controls.TradingPostsArea:SetHide(hideTradingPostsInfo or not isHasTradingPosts);
	Controls.TradingPostsHeader:SetHide(hideTradingPostsInfo);

	if isHasTradingPosts then
		for _, tradePostPlayerId in ipairs(data.TradingPosts) do
			local pTradePostPlayer:table = Players[tradePostPlayerId]
			local pTradePostPlayerConfig:table = PlayerConfigurations[tradePostPlayerId];
			local kInstanceTradingPost	:table = m_kTradingPostsIM:GetInstance();		
			local playerName			:string = Locale.Lookup( pTradePostPlayerConfig:GetPlayerName() );

			local iconName:string = "";
			local iconSize:number = SIZE_LEADER_ICON;
			local iconColor = UI.GetColorValue("COLOR_WHITE");
			if pTradePostPlayer:IsMinor() then
				-- If we're a city-state display our city-state icon instead of leader since we don't have one
				local civType:string = pTradePostPlayerConfig:GetCivilizationTypeName();
				local primaryColor, secondaryColor = UI.GetPlayerColors(tradePostPlayerId);	
				iconName = "ICON_"..civType;
				iconColor = secondaryColor;
				iconSize = SIZE_CITYSTATE_ICON;
			else
				iconName = "ICON_"..pTradePostPlayerConfig:GetLeaderTypeName();
			end
			
			local textureOffsetX :number, textureOffsetY:number, textureSheet:string = IconManager:FindIconAtlas(iconName, iconSize);
			kInstanceTradingPost.LeaderPortrait:SetTexture(textureOffsetX, textureOffsetY, textureSheet);
			kInstanceTradingPost.LeaderPortrait:SetColor(iconColor);
			kInstanceTradingPost.LeaderPortrait:SetHide(false);
							
			if tradePostPlayerId == m_pPlayer:GetID() then
				playerName = playerName .. " (" .. Locale.Lookup("LOC_HUD_CITY_YOU") .. ")";
			end
			kInstanceTradingPost.TradingPostName:SetText( playerName );
		end
	end
end

-- ===========================================================================
function ViewPanelReligion( data:table )

	-- Precursor to religion:
	Controls.PantheonArea:SetHide( data.PantheonBelief == -1 );
	if data.PantheonBelief > -1 then
		local kPantheonBelief = GameInfo.Beliefs[data.PantheonBelief];
		Controls.PantheonBelief:SetText( Locale.Lookup(kPantheonBelief.Name) );
		Controls.PantheonBelief:SetToolTipString( Locale.Lookup(kPantheonBelief.Description) );
	end

	local isHasReligion :boolean = (table.count(data.Religions) > 0) or (data.PantheonBelief > -1);
	Controls.NoReligionArea:SetHide( isHasReligion );
	Controls.StackReligion:SetHide( not isHasReligion );

	if isHasReligion then

		m_kReligionsBeliefsIM:ResetInstances();
		m_kOtherReligionsIM:ResetInstances();

		for _, beliefIndex in ipairs(data.BeliefsOfDominantReligion) do
			local kBeliefInstance	:table = m_kReligionsBeliefsIM:GetInstance();
			local kBelief			:table = GameInfo.Beliefs[beliefIndex];
			kBeliefInstance.BeliefLabel:SetText( Locale.Lookup(kBelief.Name) );
			kBeliefInstance.Top:SetToolTipString( Locale.Lookup(kBelief.Description) );
		end

		-- Dominant religion
		local dominateReligion:table = nil;
		if data.Religions and data.Religions[DATA_DOMINANT_RELIGION] then
			dominateReligion = data.Religions[DATA_DOMINANT_RELIGION];
			local religionName	:string = Game.GetReligion():GetName(dominateReligion.ID);
			local iconName		:string = "ICON_" .. dominateReligion.ReligionType;
			local textureOffsetX:number, textureOffsetY:number, textureSheet:string = IconManager:FindIconAtlas(iconName, 22);

			Controls.DominantReligionGrid:SetHide(false);
			Controls.DominantReligionSymbol:SetHide(false);
			Controls.DominantReligionSymbol:SetTexture( textureSheet );
			Controls.DominantReligionSymbol:SetTextureOffsetVal( textureOffsetX, textureOffsetY );
			Controls.DominantReligionName:SetText( Locale.Lookup("LOC_HUD_CITY_RELIGIOUS_CITIZENS_NUMBER",dominateReligion.Followers,religionName) );
			Controls.DominantReligionGrid:SetHide(false);
		else
			Controls.DominantReligionGrid:SetHide(true);
		end

		-- Other religions
		for _,religion in ipairs(data.Religions) do		
			-- Don't show pantheons or dominate religions here. Dominate religion is handled above.
			if religion.ReligionType ~= "RELIGION_PANTHEON" and (dominateReligion == nil or religion.ReligionType ~= dominateReligion.ReligionType) then
				local religionName	:string = Game.GetReligion():GetName(religion.ID);
				local iconName		:string = "ICON_" .. religion.ReligionType;
				local textureOffsetX:number, textureOffsetY:number, textureSheet:string = IconManager:FindIconAtlas(iconName, 22);

				if textureSheet ~= nil then
					local religionInstance:table = m_kOtherReligionsIM:GetInstance();	
					religionInstance.ReligionSymbol:SetTexture( textureSheet );
					religionInstance.ReligionSymbol:SetTextureOffsetVal( textureOffsetX, textureOffsetY );
					religionInstance.ReligionName:SetText( Locale.Lookup("LOC_HUD_CITY_RELIGIOUS_CITIZENS_NUMBER",religion.Followers,religionName) );
				else
					error("Unable to find texture "..iconName.." in a texture sheet for a CityPanel's religion symbol.");
				end
			end
		end
	end

	--Add religions to the religion key
	m_kKeyStackIM:ResetInstances();
	local visibleTypesCount:number = 0;

	local numFoundedReligions	:number = 0;
	local pAllReligions			:table = Game.GetReligion():GetReligions();

	for _, religionInfo in ipairs(pAllReligions) do
		local religionType:number = religionInfo.Religion;
		religionData = GameInfo.Religions[religionType];
		if(religionData.Pantheon == false and Game.GetReligion():HasBeenFounded(religionType)) then
			-- Add key entry
			AddKeyEntry(Game.GetReligion():GetName(religionType), UI.GetColorValue(religionData.Color));
			visibleTypesCount = visibleTypesCount + 1;
			
		end
	end

	if visibleTypesCount > 0 then
		Controls.KeyPanel:SetHide(false);
		Controls.KeyScrollPanel:CalculateSize();
	else
		Controls.KeyPanel:SetHide(true);
	end
	
	if Controls.PanelReligion:IsVisible() then
		UILens.SetActive("Religion");
	end
end

-- ===========================================================================
--	Return ColorSet name
-- ===========================================================================
function GetHappinessColor( eHappiness:number )
	local happinessInfo = GameInfo.Happinesses[eHappiness];
	if (happinessInfo ~= nil) then
		if (happinessInfo.GrowthModifier < 0) then return "StatBadCSGlow"; end
		if (happinessInfo.GrowthModifier > 0) then return "StatGoodCSGlow"; end
	end
	return "StatNormalCSGlow";
end

-- ===========================================================================
--	Return ColorSet name
-- ===========================================================================
function GetTurnsUntilGrowthColor( turns:number )
	if	turns < 1	then return "StatBadCSGlow"; end
	return "StatGoodCSGlow";	
end

function GetPercentGrowthColor( percent:number )
	if percent == 0 then return "Error"; end
	if percent <= 0.25 then return "WarningMajor"; end
	if percent <= 0.5 then return "WarningMinor"; end
	return "StatNormalCSGlow";
end

-- ===========================================================================
function ViewPanelAmenities( data:table )
	Controls.AmenitiesAdvisorBubble:SetHide( m_kEspionageViewManager:IsEspionageView() );
	
	local colorName:string = GetHappinessColor(data.Happiness);
	Controls.AmenitiesConstructedLabel:SetText( Locale.Lookup( "LOC_HUD_CITY_AMENITY", data.AmenitiesNum) );
	Controls.AmenitiesConstructedNum:SetText( Locale.ToNumber(data.AmenitiesNum) );
	Controls.AmenityTotalNum:SetText( Locale.ToNumber(data.AmenitiesNum) );
	Controls.AmenitiesConstructedNum:SetColorByName( colorName );
	Controls.Mood:SetText( Locale.Lookup(GameInfo.Happinesses[data.Happiness].Name) );
	Controls.Mood:SetColorByName( colorName );
	 
	if data.HappinessGrowthModifier == 0 then
		Controls.CitizenGrowth:SetText( Locale.Lookup("LOC_HUD_CITY_CITIZENS_SATISFIED") );
		Controls.CitizenGrowth:SetFontSize(12);
	else
		Controls.CitizenGrowth:SetFontSize(12);
		local iGrowthPercent = Round(1 + (data.HappinessGrowthModifier/100), 2);
		local iYieldPercent = Round(1 + (data.HappinessNonFoodYieldModifier/100), 2);
		local growthInfo:string = 
			GetColorPercentString(iGrowthPercent) .. 
			" "..
			Locale.Lookup("LOC_HUD_CITY_CITIZEN_GROWTH") .. 
			"[NEWLINE]" ..
			GetColorPercentString(iYieldPercent) .. 
			" "..
			Locale.ToUpper( Locale.Lookup("LOC_HUD_CITY_ALL_YIELDS") );
			
		Controls.CitizenGrowth:SetText( growthInfo );
	end
	
	Controls.AmenityAdvice:SetText(data.AmenityAdvice);

	g_kAmenitiesIM:ResetInstances();
	local kInstance :table = g_kAmenitiesIM:GetInstance();
	kInstance.Amenity:SetText( Locale.Lookup("LOC_HUD_CITY_AMENITIES_FROM_LUXURIES") );
	kInstance.AmenityYield:SetText( Locale.ToNumber(data.AmenitiesFromLuxuries) );
	
	if GameCapabilities.HasCapability("CAPABILITY_CITY_HUD_AMENITIES_CIVICS") then
		kInstance = g_kAmenitiesIM:GetInstance();
		kInstance.Amenity:SetText( Locale.Lookup("LOC_HUD_CITY_AMENITIES_FROM_CIVICS") );
		kInstance.AmenityYield:SetText( Locale.ToNumber(data.AmenitiesFromCivics) );
	end
	
	kInstance = g_kAmenitiesIM:GetInstance();
	kInstance.Amenity:SetText( Locale.Lookup("LOC_HUD_CITY_AMENITIES_FROM_ENTERTAINMENT") );
	kInstance.AmenityYield:SetText( Locale.ToNumber(data.AmenitiesFromEntertainment) );
		
	if GameCapabilities.HasCapability("CAPABILITY_CITY_HUD_AMENITIES_GREAT_PEOPLE") then
		kInstance = g_kAmenitiesIM:GetInstance();
		kInstance.Amenity:SetText( Locale.Lookup("LOC_HUD_CITY_AMENITIES_FROM_GREAT_PEOPLE") );
		kInstance.AmenityYield:SetText( Locale.ToNumber(data.AmenitiesFromGreatPeople) );
	end

	if GameCapabilities.HasCapability("CAPABILITY_CITY_HUD_AMENITIES_CITY_STATES") then
		kInstance = g_kAmenitiesIM:GetInstance();
		kInstance.Amenity:SetText( Locale.Lookup("LOC_HUD_CITY_AMENITIES_FROM_CITY_STATES") );
		kInstance.AmenityYield:SetText( Locale.ToNumber(data.AmenitiesFromCityStates) );
	end

	if GameCapabilities.HasCapability("CAPABILITY_CITY_HUD_AMENITIES_RELIGION") then
		kInstance = g_kAmenitiesIM:GetInstance();
		kInstance.Amenity:SetText( Locale.Lookup("LOC_HUD_CITY_AMENITIES_FROM_RELIGION") );
		kInstance.AmenityYield:SetText( Locale.ToNumber(data.AmenitiesFromReligion) );
	end

	if GameCapabilities.HasCapability("CAPABILITY_CITY_HUD_AMENITIES_NATIONAL_PARKS") then
		if GameCapabilities.HasCapability("CAPABILITY_CITY_HUD_AMENITIES_NATIONAL_PARKS") then
			kInstance = g_kAmenitiesIM:GetInstance();
			kInstance.Amenity:SetText( Locale.Lookup("LOC_HUD_CITY_AMENITIES_FROM_NATIONAL_PARKS") );
			kInstance.AmenityYield:SetText( Locale.ToNumber(data.AmenitiesFromNationalParks) );
		end
	end

	if(data.AmenitiesFromStartingEra > 0) then 
		kInstance = g_kAmenitiesIM:GetInstance();
		kInstance.Amenity:SetText( Locale.Lookup("LOC_HUD_CITY_AMENITIES_FROM_STARTING_ERA") );
		kInstance.AmenityYield:SetText( Locale.ToNumber(data.AmenitiesFromStartingEra) );
	end
	
	if(data.AmenitiesFromImprovements > 0) then 
		kInstance = g_kAmenitiesIM:GetInstance();
		kInstance.Amenity:SetText( Locale.Lookup("LOC_HUD_CITY_AMENITIES_FROM_IMPROVEMENTS") );
		kInstance.AmenityYield:SetText( Locale.ToNumber(data.AmenitiesFromImprovements) );
	end

	if GameCapabilities.HasCapability("CAPABILITY_CITY_HUD_AMENITIES_WAR_WEARINESS") then
		kInstance = g_kAmenitiesIM:GetInstance();
		kInstance.Amenity:SetText( Locale.Lookup("LOC_HUD_CITY_AMENITIES_LOST_FROM_WAR_WEARINESS") );
		if data.AmenitiesLostFromWarWeariness == 0 then
			kInstance.AmenityYield:SetText( Locale.ToNumber(data.AmenitiesLostFromWarWeariness) );
		else
			kInstance.AmenityYield:SetText( Locale.ToNumber(-data.AmenitiesLostFromWarWeariness) );
		end
	end

	if GameCapabilities.HasCapability("CAPABILITY_CITY_HUD_AMENITIES_BANKRUPTCY") then
		kInstance = g_kAmenitiesIM:GetInstance();
		kInstance.Amenity:SetText( Locale.Lookup("LOC_HUD_CITY_AMENITIES_LOST_FROM_BANKRUPTCY") );
		if data.AmenitiesLostFromBankruptcy == 0 then
			kInstance.AmenityYield:SetText( Locale.ToNumber(data.AmenitiesLostFromBankruptcy) );
		else
			kInstance.AmenityYield:SetText( Locale.ToNumber(-data.AmenitiesLostFromBankruptcy) );
		end
	end

	data.AmenitiesFromDistricts = data.AmenitiesFromDistricts or 0;
	if(data.AmenitiesFromDistricts > 0) then 
		kInstance = g_kAmenitiesIM:GetInstance();
		kInstance.Amenity:SetText( Locale.Lookup("LOC_HUD_CITY_AMENITIES_FROM_DISTRICTS") );
		kInstance.AmenityYield:SetText( Locale.ToNumber(data.AmenitiesFromDistricts) );
	end

	data.AmenitiesFromNaturalWonders = data.AmenitiesFromNaturalWonders or 0;
	if(data.AmenitiesFromNaturalWonders > 0) then 
		kInstance = g_kAmenitiesIM:GetInstance();
		kInstance.Amenity:SetText( Locale.Lookup("LOC_HUD_CITY_AMENITIES_FROM_NATURAL_WONDERS") );
		kInstance.AmenityYield:SetText( Locale.ToNumber(data.AmenitiesFromNaturalWonders) );
	end

	data.AmenitiesFromTraits = data.AmenitiesFromTraits or 0;
	if(data.AmenitiesFromTraits > 0) then 
		kInstance = g_kAmenitiesIM:GetInstance();
		kInstance.Amenity:SetText( Locale.Lookup("LOC_HUD_CITY_AMENITIES_FROM_TRAITS") );
		kInstance.AmenityYield:SetText( Locale.ToNumber(data.AmenitiesFromTraits) );
	end

	Controls.AmenitiesRequiredNum:SetText( Locale.ToNumber(data.AmenitiesRequiredNum) );
	Controls.CitizenGrowthStatus:SetTextureOffsetVal( UV_CITIZEN_GROWTH_STATUS[data.Happiness].u, UV_CITIZEN_GROWTH_STATUS[data.Happiness].v );
	Controls.CitizenGrowthStatusIcon:SetColorByName( colorName );
end

-- ===========================================================================
function ViewPanelHousing( data:table )
	Controls.HousingAdvisorBubble:SetHide( m_kEspionageViewManager:IsEspionageView() );

	local colorName:string = GetPercentGrowthColor( data.HousingMultiplier ) ;
	Controls.HousingTotalNum:SetText( data.Housing );	
	Controls.HousingTotalNum:SetColorByName( colorName );
	Controls.HousingTotalNumLabel:SetText(Locale.Lookup("LOC_HUD_CITY_HOUSING_LABEL", data.Housing));

	local uv:number;

	if data.HousingMultiplier == 0 then
		Controls.HousingPopulationStatus:SetText(Locale.Lookup("LOC_HUD_CITY_POPULATION_GROWTH_HALTED"));	
		uv = 0;	
	elseif data.HousingMultiplier <= 0.25 then
	    local iPercent = (1 - data.HousingMultiplier) * 100;
		Controls.HousingPopulationStatus:SetText(Locale.Lookup("LOC_HUD_CITY_POPULATION_GROWTH_SLOWED", iPercent));		
		uv = 1;
	elseif data.HousingMultiplier <= 0.5 then
	    local iPercent = (1 - data.HousingMultiplier) * 100;
		Controls.HousingPopulationStatus:SetText(Locale.Lookup("LOC_HUD_CITY_POPULATION_GROWTH_SLOWED", iPercent));		
		uv = 1;
	else
		Controls.HousingPopulationStatus:SetText(Locale.Lookup("LOC_HUD_CITY_POPULATION_GROWTH_NORMAL"));
		uv = 2;
	end
	Controls.HousingPopulationStatus:SetColorByName( colorName );

	Controls.CitizensNum:SetText( data.Population );
	Controls.CitizensName:SetText(Locale.Lookup("LOC_HUD_CITY_CITIZENS_LABEL", data.Population));
	
	Controls.HousingTotalNum2:SetText( data.Housing );
	Controls.HousingTotalNum2:SetColorByName( colorName );
		
	--local uv:number = data.TurnsUntilGrowth > 0 and 1 or 0;
	Controls.HousingStatus:SetTextureOffsetVal( UV_HOUSING_GROWTH_STATUS[uv].u, UV_HOUSING_GROWTH_STATUS[uv].v );
	Controls.HousingStatusIcon:SetColorByName( colorName );

	Controls.HousingAdvice:SetText(data.HousingAdvice);

	m_kHousingIM:ResetInstances();
		
	local kInstance :table = m_kHousingIM:GetInstance();
	kInstance.HousingName:SetText( Locale.Lookup("LOC_HUD_CITY_HOUSING_FROM_BUILDINGS") );
	kInstance.HousingYield:SetText( Locale.ToNumber(data.HousingFromBuildings) );

	kInstance = m_kHousingIM:GetInstance();
	kInstance.HousingName:SetText( Locale.Lookup("LOC_HUD_CITY_HOUSING_FROM_CIVICS") );
	kInstance.HousingYield:SetText( Locale.ToNumber(data.HousingFromCivics) );

	if GameCapabilities.HasCapability("CAPABILITY_CITY_HUD_HOUSING_DISTRICTS") then
		kInstance = m_kHousingIM:GetInstance();
		kInstance.HousingName:SetText( Locale.Lookup("LOC_HUD_CITY_HOUSING_FROM_DISTRICTS") );
		kInstance.HousingYield:SetText( Locale.ToNumber(data.HousingFromDistricts) );
	end

	kInstance = m_kHousingIM:GetInstance();
	kInstance.HousingName:SetText( Locale.Lookup("LOC_HUD_CITY_HOUSING_FROM_IMPROVEMENTS") );
	kInstance.HousingYield:SetText( Locale.ToNumber(data.HousingFromImprovements) );

	kInstance = m_kHousingIM:GetInstance();
	kInstance.HousingName:SetText( Locale.Lookup("LOC_HUD_CITY_HOUSING_FROM_WATER") );
	kInstance.HousingYield:SetText( Locale.ToNumber(data.HousingFromWater) );

	if GameCapabilities.HasCapability("CAPABILITY_CITY_HUD_HOUSING_GREAT_PEOPLE") then
		kInstance = m_kHousingIM:GetInstance();
		kInstance.HousingName:SetText( Locale.Lookup("LOC_HUD_CITY_HOUSING_FROM_GREAT_PEOPLE") );
		kInstance.HousingYield:SetText( Locale.ToNumber(data.HousingFromGreatPeople) );
	end

	--Housing from Advanced Starts it is zero in the Ancient Era so we do not want to display it
	if(data.HousingFromStartingEra > 0 ) then
		kInstance = m_kHousingIM:GetInstance();
		kInstance.HousingName:SetText( Locale.Lookup("LOC_HUD_CITY_HOUSING_FROM_STARTING_ERA") );
		kInstance.HousingYield:SetText( Locale.ToNumber(data.HousingFromStartingEra) );
	end

	if (data.HousingFromGreatWorks > 0) then
		kInstance = m_kHousingIM:GetInstance();
		kInstance.HousingName:SetText( Locale.Lookup("LOC_HUD_CITY_HOUSING_FROM_GREATWORKS") );
		kInstance.HousingYield:SetText( Locale.ToNumber(data.HousingFromGreatWorks) );
	end
end

-- ===========================================================================
function UpdateCitizenGrowthStatusIcon( turnsUntilGrowth:number, bOccupied:boolean )

	local color;
	if turnsUntilGrowth < 0 then
		-- Starving
		statusIndex = 0;
		color = "StatBadCSGlow";
	elseif turnsUntilGrowth == 0 or bOccupied then
		-- Neutral
		statusIndex = 1;
		color = "StatNormalCSGlow";
	else
		-- Growing
		statusIndex = 2;
		color = "StatGoodCSGlow";
	end

	Controls.CitizenGrowthStatus2:SetColorByName(color);
	Controls.CitizenGrowthStatusIcon2:SetColorByName(color);

	local uv = UV_CITIZEN_STARVING_STATUS[statusIndex];
	Controls.CitizenGrowthStatus2:SetTextureOffsetVal( uv.u, uv.v );
end

-- ===========================================================================
function ViewPanelCitizensGrowth( data:table )

	Controls.FoodPerTurnNum:SetText( toPlusMinusString(data.FoodPerTurn) );
	Controls.FoodConsumption:SetText( toPlusMinusString(-(data.FoodPerTurn - data.FoodSurplus)) );
	Controls.NetFoodPerTurn:SetText( toPlusMinusString(data.FoodSurplus) );	
	if data.FoodSurplus > 0 then
		Controls.GrowthLongLabel:LocalizeAndSetText("{LOC_HUD_CITY_GROWTH_IN:upper}");
	else
		Controls.GrowthLongLabel:LocalizeAndSetText("{LOC_HUD_CITY_LOSS_IN:upper}");
	end

	Controls.GrowthLongNum:SetText( not data.Occupied and math.abs(data.TurnsUntilGrowth) or 0);
	Controls.FoodNeededForGrowth:SetText( Locale.ToNumber(data.GrowthThreshold, "#,###.#") );
	
	local iModifiedFood;
	local total :number;

	if data.Occupied then
		local iOccupationGrowthPercent = data.OccupationMultiplier * 100;
	    Controls.OccupationMultiplier:SetText( Locale.ToNumber(iOccupationGrowthPercent));
	else
	    Controls.OccupationMultiplier:LocalizeAndSetText("LOC_HUD_CITY_NOT_APPLICABLE");
	end

	if data.TurnsUntilGrowth > -1 then
		
		-- Set bonuses and multipliers
		local iHappinessPercent = data.HappinessGrowthModifier;
		Controls.HappinessBonus:SetText( toPlusMinusString(Round(iHappinessPercent, 0)) .. "%");
		local iOtherGrowthPercent = data.OtherGrowthModifiers * 100;
		Controls.OtherGrowthBonuses:SetText( toPlusMinusString(Round(iOtherGrowthPercent, 0)) .. "%");
		Controls.HousingMultiplier:SetText( Locale.ToNumber( data.HousingMultiplier));
		local growthModifier =  math.max(1 + (data.HappinessGrowthModifier/100) + data.OtherGrowthModifiers, 0); -- This is unintuitive but it's in parity with the logic in City_Growth.cpp
		iModifiedFood = Round(data.FoodSurplus * growthModifier, 2);
		total = iModifiedFood * data.HousingMultiplier;		
		if data.Occupied then
			total = iModifiedFood * data.OccupationMultiplier;
			Controls.TurnsUntilBornLost:SetText( Locale.Lookup("LOC_HUD_CITY_GROWTH_OCCUPIED"));
		else
			Controls.TurnsUntilBornLost:SetText( Locale.Lookup("LOC_HUD_CITY_TURNS_UNTIL_CITIZEN_BORN", data.TurnsUntilGrowth));
		end
		Controls.FoodSurplusDeficitLabel:LocalizeAndSetText("LOC_HUD_CITY_TOTAL_FOOD_SURPLUS");
	else
		-- In a deficit, no bonuses or multipliers apply
		Controls.HappinessBonus:LocalizeAndSetText("LOC_HUD_CITY_NOT_APPLICABLE");
		Controls.OtherGrowthBonuses:LocalizeAndSetText("LOC_HUD_CITY_NOT_APPLICABLE");
		Controls.HousingMultiplier:LocalizeAndSetText("LOC_HUD_CITY_NOT_APPLICABLE");
		iModifiedFood = data.FoodSurplus;
		total = iModifiedFood;		

		Controls.TurnsUntilBornLost:SetText( Locale.Lookup("LOC_HUD_CITY_TURNS_UNTIL_CITIZEN_LOST", math.abs(data.TurnsUntilGrowth)));
		Controls.FoodSurplusDeficitLabel:LocalizeAndSetText("LOC_HUD_CITY_TOTAL_FOOD_DEFICIT");
	end	

	Controls.ModifiedGrowthFoodPerTurn:SetText( toPlusMinusString(iModifiedFood) );
	local totalString:string = toPlusMinusString(total) .. (total <= 0 and "[Icon_FoodDeficit]" or "[Icon_FoodSurplus]");
	Controls.TotalFoodSurplus:SetText( totalString );
	Controls.CitizensStarving:SetHide( data.TurnsUntilGrowth > -1);
	UpdateCitizenGrowthStatusIcon( data.TurnsUntilGrowth, data.Occupied);
end

-- ===========================================================================
function ViewPanelProductionNow( data:table )	
	Controls.ProductionNowHeader:SetText( data.CurrentProductionName );
	
	-- If a unit is building built; show it's stats before the description:	
	Controls.UnitStatsStack:SetHide( data.UnitStats == nil );
	if data.UnitStats ~= nil then
		Controls.IconStrength:SetHide( data.UnitStats.Combat <= 0 );
		Controls.IconBombardStrength:SetHide( data.UnitStats.Bombard <= 0 );
		Controls.IconRange:SetHide( data.UnitStats.Range <= 0 );
		Controls.IconRangedStrength:SetHide( data.UnitStats.RangedCombat <= 0 );

		Controls.LabelStrength:SetHide( data.UnitStats.Combat <= 0 );
		Controls.LabelRangedStrength:SetHide( data.UnitStats.RangedCombat <= 0 );
		Controls.LabelBombardStrength:SetHide( data.UnitStats.Bombard <= 0 );
		Controls.LabelRange:SetHide( data.UnitStats.Range <= 0 );
				
		Controls.LabelStrength:SetText( Locale.ToNumber(data.UnitStats.Combat ) );
		Controls.LabelRangedStrength:SetText( Locale.ToNumber(data.UnitStats.RangedCombat ) );
		Controls.LabelBombardStrength:SetText( Locale.ToNumber(data.UnitStats.Bombard ) );
		Controls.LabelRange:SetText( Locale.ToNumber(data.UnitStats.Range ) );
	end

	Controls.ProductionDescription:SetText( data.CurrentProductionDescription );
end


-- ===========================================================================
function CreateQueueItem( index:number, kProductionInfo:table )
	local kInstance :table = m_kProductionIM:GetInstance();
	kInstance.Index:SetText( tostring(index).."." );
	kInstance.Close:RegisterCallback( Mouse.eLClick,
		function()
			m_kProductionIM:ReleaseInstance( kInstance );			
			Controls.PanelStack:CalculateSize();
		end
	);
	if (kProductionInfo.Icon ~= nil) then
		kInstance.Icon:SetHide(false);
		kInstance.Icon:SetIcon( kProductionInfo.Icon);
	else
		kInstance.Icon:SetHide(true);
	end
	kInstance.Name:SetText( kProductionInfo.Name  );
	kInstance.Turns:SetText( Locale.Lookup("LOC_HUD_CITY_IN_TURNS",kProductionInfo.Turns) );
end

-- ===========================================================================
function ViewPanelQueue( data:table )	
	m_kProductionIM:ResetInstances();
	for i:number,kProductionInfo:table in ipairs( data.ProductionQueue ) do
		CreateQueueItem(i, kProductionInfo );
	end
end

-- ===========================================================================
function RenameCity(city, new_name)
	-- Do nothing if the city names match or new name is blank or invalid.
	local old_name = city:GetName();
	if(new_name == nil or new_name == old_name or new_name == Locale.Lookup(old_name)) then
		return;
	else
		-- Send net message to change name.
		local params = {};
		params[CityCommandTypes.PARAM_NAME] = new_name;
	
		CityManager.RequestCommand(city, CityCommandTypes.NAME_CITY, params);
	end
end

-- ===========================================================================
--	Add a tab group to the left panel. (Function abstraction for MODs)
-- ===========================================================================
function AddTab( uiButton:table, callback:ifunction)
	if m_tabs == nil then
		m_tabs = CreateTabs( Controls.TabContainer,44,44);
	end
	m_tabs.AddTab( uiButton, callback );
end

-- ===========================================================================
--	Hand out a tab button instance. (Function abstraction for MODs)
-- ===========================================================================
function GetTabButtonInstance()
	return m_kTabButtonIM:GetInstance();
end

-- ===========================================================================
--	Get the selected tab button instance. (Function abstraction for MODs)
-- ===========================================================================
function GetSelectedTabButton()
	return m_tabs.selectedControl;
end

-- ===========================================================================
--	Call after all tabs are setup.
-- ===========================================================================
function FinalizeTabs()
	m_tabs.CenterAlignTabs(0);
	m_tabs.SelectTab( Controls.HealthButton );
	m_tabs.AddAnimDeco(Controls.TabAnim, Controls.TabArrow, 0, -21);
end

-- ===========================================================================
function AutoSizeControls()
	local screenX, screenY:number = UIManager:GetScreenSizeVal()
end

-- ===========================================================================
function Close()
	if m_isShowingPanel == false then
		return;
	end
	m_isShowingPanel = false;
	local offsetx = Controls.OverviewSlide:GetOffsetX();
	if(offsetx ~= 0) then
		Controls.OverviewSlide:SetToEnd();
	end
	Controls.OverviewSlide:Reverse();
	UI.PlaySound("UI_CityPanel_Closed");
	UILens.SetActive("Default");
	UI.SetInterfaceMode(InterfaceModeTypes.SELECTION);
end

-- ===========================================================================
function OnClose()
	Close();
end

-- ===========================================================================
function OnCloseButtonClicked()
	LuaEvents.CityPanelOverview_CloseButton();
	Close();
	UI.PlaySound("UI_CityPanel_Closed"); -- This is also being called in the Close function? but its in an if
end

-- ===========================================================================
function View(data)
	Controls.OverviewSubheader:SetText(Locale.ToUpper(Locale.Lookup(data.CityName)));

	local canChangeName = GameCapabilities.HasCapability("CAPABILITY_RENAME");
	if(canChangeName and not m_kEspionageViewManager:IsEspionageView()) then
		Controls.RenameCityButton:RegisterCallback(Mouse.eLClick, function()
			Controls.OverviewSubheader:SetHide(true);

			Controls.EditCityName:SetText(Controls.OverviewSubheader:GetText());
			Controls.EditCityName:SetHide(false);
			Controls.EditCityName:TakeFocus();
		end);

		local city = data.City;
		Controls.EditCityName:RegisterCommitCallback(function(editBox)
			local userInput:string = Controls.EditCityName:GetText();
			RenameCity(city, userInput);
			data.CityName = userInput;
			Controls.EditCityName:SetHide(true);
			Controls.OverviewSubheader:SetHide(false);
		end);
		Controls.RenameCityButton:SetDisabled(false);
	else
		Controls.RenameCityButton:SetDisabled(true);
	end

end

-- ===========================================================================
function Refresh()
	if m_isShowingPanel==false then
		return;	-- Only refresh if panel is visible
	end

	m_pPlayer = Players[Game.GetLocalPlayer()];
	m_pCity	  = UI.GetHeadSelectedCity();

	-- If we don't have a city selected see if we want to see details on an enemy city
	if m_pCity == nil then
		m_pCity = m_kEspionageViewManager:GetEspionageViewCity();
		if m_pCity ~= nil then
			m_kData = GetCityData( m_pCity );
		end
	else
		m_kEspionageViewManager:ClearEspionageViewCity();
	end

	if m_kData == nil then
		return;
	end
		
	if m_pPlayer ~= nil and m_pCity ~= nil then
		-- Trigger selection callback
		View( m_kData );
		if m_tabs.selectedControl then
			m_tabs.SelectTab(m_tabs.selectedControl);
		end
	end
end

-- ===========================================================================
function OnShowEnemyCityOverview( ownerID:number, cityID:number)
	m_kEspionageViewManager:SetEspionageViewCity( ownerID, cityID );
	OnShowOverviewPanel(true);
end

-- ===========================================================================
--	Input
--	UI Event Handler
-- ===========================================================================
function OnInputHandler( pInputStruct:table )
	local uiMsg = pInputStruct:GetMessageType();
	if (uiMsg == MouseEvents.RButtonUp) or (uiMsg == KeyEvents.KeyUp and pInputStruct:GetKey() == Keys.VK_ESCAPE) then
		if ( m_isShowingPanel ) then
			OnCloseButtonClicked();
			return true;
		end
	end
	return false;
end 

-- Resize Handler
function OnUpdateUI( type:number, tag:string, iData1:number, iData2:number, strData1:string )   
  if type == SystemUpdateUI.ScreenResize then
    Resize();
  end
end

-- Called whenever CityPanel is refreshed
function OnLiveCityDataChanged( data:table, isSelected:boolean) 
	if (not isSelected) then
		if m_kEspionageViewManager:GetEspionageViewCity() == nil then
			Close();
		end
	else
		m_kData = data;
		Refresh();
	end
end

function OnCityNameChanged( playerID: number, cityID : number )
	if(m_pCity and playerID == m_pCity:GetOwner() and cityID == m_pCity:GetID()) then
		Controls.OverviewSubheader:SetText(Locale.ToUpper(Locale.Lookup(m_pCity:GetName())));
	end
end

function OnLocalPlayerTurnEnd()
	if(GameConfiguration.IsHotseat()) then
		Close();
	end
end

function OnResearchCompleted( ePlayer:number )
	if m_pPlayer ~= nil and ePlayer == m_pPlayer:GetID() then
		Refresh();
	end
end

function OnPolicyChanged( ePlayer:number )
	if m_pPlayer ~= nil and ePlayer == m_pPlayer:GetID() then
		Refresh();
	end
end

function OnGreatWorkChanged( playerID:number, creatorID:number, cityX:number, cityY:number, buildingID:number, greatWorkIndex:number )
	if m_pPlayer ~= nil and playerID == m_pPlayer:GetID() then
		Refresh();
	end
end

function Resize()
	local screenX, screenY:number = UIManager:GetScreenSizeVal();
	Controls.OverviewSlide:SetSizeY(screenY);
	Controls.PanelScrollPanel:SetSizeY(screenY-120);
end

function OnUpdateUI( type:number, tag:string, iData1:number, iData2:number, strData1:string )   
  if type == SystemUpdateUI.ScreenResize then
    Resize();
  end
end

function OnShowOverviewPanel( isShowing: boolean )
	if (isShowing) then
		m_isShowingPanel = true;
		Refresh();
		Controls.OverviewSlide:SetToBeginning();
		Controls.OverviewSlide:Play();
		UI.PlaySound("UI_CityPanel_Open");
		UI.SetInterfaceMode(InterfaceModeTypes.CITY_SELECTION);
	else
		local offsetx = Controls.OverviewSlide:GetOffsetX();
		if(offsetx == 0) then
			Close();
		end
	end
	-- Ensure button state in CityPanel is correct
	LuaEvents.CityPanel_SetOverViewState(m_isShowingPanel);
	LuaEvents.CityPanelOverview_Opened();
end

function ToggleOverviewTab(tabButton:table)
 	if m_isShowingPanel and m_tabs.selectedControl == tabButton and m_pCity	== UI.GetHeadSelectedCity() then
		OnCloseButtonClicked();
	else
		if not m_isShowingPanel then
			OnShowOverviewPanel(true);
		end
		if m_tabs.selectedControl ~= tabButton then
			m_tabs.SelectTab( tabButton );
		end
	end
end

function OnToggleCitizensTab()
	ToggleOverviewTab( Controls.HealthButton );
end

function OnToggleBuildingsTab()
	ToggleOverviewTab( Controls.BuildingsButton );
end

function OnToggleReligionTab()
	ToggleOverviewTab( Controls.ReligionButton );
end

-- ===========================================================================
function AddKeyEntry(textString:string, colorValue:number)
	local keyEntryInstance:table = m_kKeyStackIM:GetInstance();

	-- Update key text
	keyEntryInstance.KeyLabel:SetText(Locale.Lookup(textString));

	-- Update key color
	keyEntryInstance.KeyColorImage:SetColor(colorValue);
end

-- ===========================================================================
function OnLensChanged( newLensName:string, oldLensName:string )
	-- When a new city is selected we're always sent back to Default lens which overrides Overview lenses
	-- This switches back to the proper Overview lens we were forced to switch away from
	if m_isShowingPanel and newLensName == "Default" then
		UILens.SetActive(oldLensName);
	end
end

-- ===========================================================================
--	UI Callback
-- ===========================================================================
function OnInit( isReload:boolean )
	LateInitialize();
	FinalizeTabs();
	if isReload then
		LuaEvents.GameDebug_GetValues(RELOAD_CACHE_ID);
	end
end

-- ===========================================================================
function LateInitialize()	
	Controls.Close:RegisterCallback(Mouse.eLClick, OnCloseButtonClicked);
	Controls.Close:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	
	LuaEvents.Tutorial_ResearchOpen.Add(OnClose);
	LuaEvents.ActionPanel_OpenChooseResearch.Add(OnClose);
	LuaEvents.ActionPanel_OpenChooseCivic.Add(OnClose);
	LuaEvents.CityPanel_ShowOverviewPanel.Add( OnShowOverviewPanel );	
	LuaEvents.CityPanel_ToggleOverviewCitizens.Add( OnToggleCitizensTab );
	LuaEvents.CityPanel_ToggleOverviewBuildings.Add( OnToggleBuildingsTab );
	LuaEvents.CityPanel_ToggleOverviewReligion.Add( OnToggleReligionTab );
	LuaEvents.CityPanel_LiveCityDataChanged.Add( OnLiveCityDataChanged );
	LuaEvents.CityBannerManager_ShowEnemyCityOverview.Add( OnShowEnemyCityOverview );
	LuaEvents.CityBannerManager_CityPanelOverview.Add( OnToggleCitizensTab );
	LuaEvents.DiploScene_SceneOpened.Add(OnClose); --We don't want this UI open when we return from Diplomacy

	Events.SystemUpdateUI.Add( OnUpdateUI );
	Events.CityNameChanged.Add(OnCityNameChanged);
	Events.LocalPlayerTurnEnd.Add( OnLocalPlayerTurnEnd );
	Events.ResearchCompleted.Add( OnResearchCompleted );
	Events.GovernmentPolicyChanged.Add( OnPolicyChanged );
	Events.GovernmentPolicyObsoleted.Add( OnPolicyChanged );
	Events.LensChanged.Add( OnLensChanged );
	Events.GreatWorkCreated.Add( OnGreatWorkChanged );
	Events.GreatWorkMoved.Add( OnGreatWorkChanged );

	-- Populate tabs	
	AddTab( Controls.HealthButton,		OnSelectHealthTab );
	AddTab( Controls.BuildingsButton,	OnSelectBuildingsTab );
	if GameCapabilities.HasCapability("CAPABILITY_CITY_HUD_RELIGION_TAB") then
		AddTab( Controls.ReligionButton,OnSelectReligionTab );
	else
		Controls.ReligionButton:SetHide(true);
	end
end

-- ===========================================================================
function OnGameDebugReturn(context:string, contextTable:table)
	if context == RELOAD_CACHE_ID then
		m_isShowingPanel = contextTable["m_isShowingPanel"];
		Refresh();
	end
end

-- ===========================================================================
function OnShutdown()
	LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "m_isShowingPanel", m_isShowingPanel);

	LuaEvents.Tutorial_ResearchOpen.Remove(OnClose);
	LuaEvents.ActionPanel_OpenChooseResearch.Remove(OnClose);
	LuaEvents.ActionPanel_OpenChooseCivic.Remove(OnClose);
	LuaEvents.CityPanel_ShowOverviewPanel.Remove( OnShowOverviewPanel );	
	LuaEvents.CityPanel_ToggleOverviewCitizens.Remove( OnToggleCitizensTab );
	LuaEvents.CityPanel_ToggleOverviewBuildings.Remove( OnToggleBuildingsTab );
	LuaEvents.CityPanel_ToggleOverviewReligion.Remove( OnToggleReligionTab );
	LuaEvents.CityPanel_LiveCityDataChanged.Remove( OnLiveCityDataChanged );
	LuaEvents.CityBannerManager_ShowEnemyCityOverview.Remove( OnShowEnemyCityOverview );
	LuaEvents.CityBannerManager_CityPanelOverview.Remove( OnToggleCitizensTab );
	LuaEvents.DiploScene_SceneOpened.Remove(OnClose); --We don't want this UI open when we return from Diplomacy

	Events.SystemUpdateUI.Remove( OnUpdateUI );
	Events.CityNameChanged.Remove(OnCityNameChanged);
	Events.LocalPlayerTurnEnd.Remove( OnLocalPlayerTurnEnd );
	Events.ResearchCompleted.Remove( OnResearchCompleted );
	Events.GovernmentPolicyChanged.Remove( OnPolicyChanged );
	Events.GovernmentPolicyObsoleted.Remove( OnPolicyChanged );
	Events.LensChanged.Remove( OnLensChanged );
end

-- ===========================================================================
function Initialize()
	ContextPtr:SetInputHandler( OnInputHandler, true );
	ContextPtr:SetInitHandler( OnInit );
	ContextPtr:SetHide(false);
	ContextPtr:SetShutdown(OnShutdown);
	LuaEvents.GameDebug_Return.Add(OnGameDebugReturn);	
end
Initialize();