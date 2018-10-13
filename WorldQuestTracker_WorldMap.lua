

--world quest tracker object
local WorldQuestTracker = WorldQuestTrackerAddon
if (not WorldQuestTracker) then
	return
end

--framework
local DF = _G ["DetailsFramework"]
if (not DF) then
	print ("|cFFFFAA00World Quest Tracker: framework not found, if you just installed or updated the addon, please restart your client.|r")
	return
end

--localization
local L = LibStub ("AceLocale-3.0"):GetLocale ("WorldQuestTrackerAddon", true)
if (not L) then
	return
end

local HereBeDragons = LibStub ("HereBeDragons-2.0")

local ff = WorldQuestTrackerFinderFrame
local rf = WorldQuestTrackerRareFrame

local _
local QuestMapFrame_IsQuestWorldQuest = QuestMapFrame_IsQuestWorldQuest or QuestUtils_IsQuestWorldQuest
local GetNumQuestLogRewardCurrencies = GetNumQuestLogRewardCurrencies
local GetQuestLogRewardInfo = GetQuestLogRewardInfo
local GetQuestLogRewardCurrencyInfo = GetQuestLogRewardCurrencyInfo
local GetQuestLogRewardMoney = GetQuestLogRewardMoney
local GetQuestTagInfo = GetQuestTagInfo
local GetNumQuestLogRewards = GetNumQuestLogRewards
local GetQuestInfoByQuestID = C_TaskQuest.GetQuestInfoByQuestID
local GetQuestTimeLeftMinutes = C_TaskQuest.GetQuestTimeLeftMinutes
local GetQuestsForPlayerByMapID = C_TaskQuest.GetQuestsForPlayerByMapID

local MapRangeClamped = DF.MapRangeClamped
local FindLookAtRotation = DF.FindLookAtRotation
local GetDistance_Point = DF.GetDistance_Point

local faction_frames = {}
local WorldWidgetPool = {}
local all_widgets = {}
WorldQuestTracker.WorldMapWidgets = all_widgets
local extra_widgets = {}

local forceRetryForHub = {}
local forceRetryForHubAmount = 2

local UpdateDebug = false

----------------------------------------------------------------------------------------------------------------------------------------------------------------
--> world map widgets

--se a janela do world map esta em modo janela
WorldQuestTracker.InWindowMode = not WorldMapFrame.isMaximized
WorldQuestTracker.LastUpdate = 0
local worldFramePOIs = WorldQuestTrackerWorldMapPOI

--store the amount os quests for each faction on each map
local factionAmountForEachMap = {}

worldFramePOIs.mouseoverHighlight = worldFramePOIs:CreateTexture (nil, "background")
worldFramePOIs.mouseoverHighlight:SetTexture ([[Interface\Worldmap\QuestPoiGlow]])
worldFramePOIs.mouseoverHighlight:SetSize (64, 64)
worldFramePOIs.mouseoverHighlight:SetAlpha (0.843215)
worldFramePOIs.mouseoverHighlight:SetBlendMode ("ADD")

--when a square is hover hovered in the world map, find the circular quest button in the world map and highlight it
function WorldQuestTracker.HighlightOnWorldMap (questID)
	for questCounter, button in pairs (WorldQuestTracker.WorldMapSmallWidgets) do
		if (button.questID == questID) then
			worldFramePOIs.mouseoverHighlight:Show()
			worldFramePOIs.mouseoverHighlight:SetParent (button)
			worldFramePOIs.mouseoverHighlight:ClearAllPoints()
			worldFramePOIs.mouseoverHighlight:SetPoint ("center", button, "center", 0, 0)
		end
	end
end

--local onenter function for worldmap buttons
local questButton_OnEnter = function (self)
	if (self.questID) then
		WorldQuestTracker.CurrentHoverQuest = self.questID
		self.UpdateTooltip = TaskPOI_OnEnter -- function()end
		TaskPOI_OnEnter (self)
		WorldQuestTracker.HighlightOnWorldMap (self.questID)
	end
end

local questButton_OnLeave = function (self)
	TaskPOI_OnLeave (self)
	WorldQuestTracker.CurrentHoverQuest = nil
	worldFramePOIs.mouseoverHighlight:Hide()
end

WorldQuestTracker.TaskPOI_OnEnterFunc = questButton_OnEnter
WorldQuestTracker.TaskPOI_OnLeaveFunc = questButton_OnLeave

--esconde todos os widgets do world map
function WorldQuestTracker.HideWorldQuestsOnWorldMap()
	--old squares (deprecated)
	for _, widget in ipairs (all_widgets) do
		widget:Hide()
		widget.isArtifact = nil
		widget.questID = nil
	end
	--faction lines (deprecated)
	for _, widget in ipairs (extra_widgets) do --linhas e bolas de fac��es
		widget:Hide()
	end
	
	--world summary in the left side of the world map
	if (WorldQuestTracker.WorldSummary) then
		WorldQuestTracker.WorldSummary.HideSummary()
	end
end

local worldSquareBackdrop = {edgeFile = [[Interface\Buttons\WHITE8X8]], edgeSize = 1.5, bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", tile = true, tileSize = 16}

--cria uma square widget no world map ~world ~createworld ~createworldwidget
local create_worldmap_square = function (mapName, index, parent)
	local button = CreateFrame ("button", "WorldQuestTrackerWorldMapPOI" .. mapName .. "POI" .. index, parent or worldFramePOIs)
	button:SetSize (WorldQuestTracker.Constants.WorldMapSquareSize, WorldQuestTracker.Constants.WorldMapSquareSize)
	button.IsWorldQuestButton = true
	button:SetFrameLevel (302)
	button:SetBackdrop (worldSquareBackdrop)
	button:SetBackdropColor (.1, .1, .1, .6)
	
	button:SetScript ("OnEnter", questButton_OnEnter)
	button:SetScript ("OnLeave", questButton_OnLeave)
	button:SetScript ("OnClick", WorldQuestTracker.OnQuestButtonClick)
	
	button:RegisterForClicks ("LeftButtonDown", "MiddleButtonDown", "RightButtonDown")
	
	local fadeInAnimation = button:CreateAnimationGroup()
	local step1 = fadeInAnimation:CreateAnimation ("Alpha")
	step1:SetOrder (1)
	step1:SetFromAlpha (0)
	step1:SetToAlpha (1)
	step1:SetDuration (0.1)
	button.fadeInAnimation = fadeInAnimation
	
	tinsert (all_widgets, button)
	
	local background = button:CreateTexture (nil, "background", -3)
	background:SetAllPoints()	
	
	local texture = button:CreateTexture (nil, "background", -2)
	texture:SetAllPoints()
	
	--borders
	local commonBorder = button:CreateTexture (nil, "artwork", 1)
	commonBorder:SetPoint ("topleft", button, "topleft")
	commonBorder:SetTexture ([[Interface\AddOns\WorldQuestTracker\media\border_whiteT]])
	commonBorder:SetSize (WorldQuestTracker.Constants.WorldMapSquareSize, WorldQuestTracker.Constants.WorldMapSquareSize)
	
	local rareBorder = button:CreateTexture (nil, "artwork", 1)
	rareBorder:SetPoint ("topleft", button, "topleft")
	rareBorder:SetTexture ([[Interface\AddOns\WorldQuestTracker\media\border_blueT]])
	rareBorder:SetSize (WorldQuestTracker.Constants.WorldMapSquareSize, WorldQuestTracker.Constants.WorldMapSquareSize)
	
	local epicBorder = button:CreateTexture (nil, "artwork", 1)
	epicBorder:SetPoint ("topleft", button, "topleft")
	epicBorder:SetTexture ([[Interface\AddOns\WorldQuestTracker\media\border_pinkT]])
	epicBorder:SetSize (WorldQuestTracker.Constants.WorldMapSquareSize, WorldQuestTracker.Constants.WorldMapSquareSize)
	
	local invasionBorder = button:CreateTexture (nil, "artwork", 1)
	invasionBorder:SetPoint ("topleft", button, "topleft")
	invasionBorder:SetTexture ([[Interface\AddOns\WorldQuestTracker\media\border_legionT]])
	invasionBorder:SetSize (WorldQuestTracker.Constants.WorldMapSquareSize, WorldQuestTracker.Constants.WorldMapSquareSize)
	invasionBorder:Hide()
	
	local trackingBorder = button:CreateTexture (nil, "artwork", 1)
	trackingBorder:SetPoint ("topleft", button, "topleft", -5, 5)
	trackingBorder:SetTexture ([[Interface\Artifacts\Artifacts]])
	trackingBorder:SetTexCoord (491/1024, 569/1024, 76/1024, 153/1024)
	trackingBorder:SetBlendMode ("ADD")
	trackingBorder:SetSize (WorldQuestTracker.Constants.WorldMapSquareSize+10, WorldQuestTracker.Constants.WorldMapSquareSize+10)
	
	local factionBorder = button:CreateTexture (nil, "artwork", 1)
	factionBorder:SetPoint ("center")
	factionBorder:SetTexture ([[Interface\Artifacts\Artifacts]])
	--factionBorder:SetTexCoord (491/1024, 569/1024, 76/1024, 153/1024)
	factionBorder:SetTexCoord (137/1024, 195/1024, 920/1024, 978/1024)
	--factionBorder:SetBlendMode ("ADD")
	factionBorder:Hide()
	factionBorder:SetAlpha (1)
	factionBorder:SetSize (WorldQuestTracker.Constants.WorldMapSquareSize+2, WorldQuestTracker.Constants.WorldMapSquareSize+2)
	
	local borderAnimation = CreateFrame ("frame", "$parentBorderShineAnimation", button, "AutoCastShineTemplate")
	borderAnimation:SetFrameLevel (303)
	borderAnimation:SetPoint ("topleft", 2, -2)
	borderAnimation:SetPoint ("bottomright", -2, 2)
	borderAnimation:SetAlpha (.05)
	borderAnimation:Hide()
	button.borderAnimation = borderAnimation
	
	local shineAnimation = CreateFrame ("frame", "$parentShine", button, "AnimatedShineTemplate")
	shineAnimation:SetFrameLevel (303)
	--shineAnimation:SetAllPoints()
	shineAnimation:SetPoint ("topleft", 4, -2)
	shineAnimation:SetPoint ("bottomright", 0, 1)
	shineAnimation:Hide()
	button.shineAnimation = shineAnimation
	
	--animation
	WorldQuestTracker.CreateStartTrackingAnimation (button, nil, 5)
	
	local trackingGlowInside = button:CreateTexture (nil, "overlay", 1)
	trackingGlowInside:SetPoint ("center", button, "center")
	trackingGlowInside:SetColorTexture (1, 1, 1, .03)
	trackingGlowInside:SetSize (WorldQuestTracker.Constants.WorldMapSquareSize * 0.8, WorldQuestTracker.Constants.WorldMapSquareSize * 0.8)
	trackingGlowInside:Hide()
	
	local trackingGlowBorder = button:CreateTexture (nil, "overlay", 1)
	trackingGlowBorder:SetPoint ("center", button, "center")
	trackingGlowBorder:SetTexture ([[Interface\AddOns\WorldQuestTracker\media\glow_yellow_squareT]])
	trackingGlowBorder:SetBlendMode ("ADD")
	trackingGlowBorder:SetSize (55, 55)
	trackingGlowBorder:SetAlpha (1)
	trackingGlowBorder:SetDrawLayer ("BACKGROUND", -5)
	trackingGlowBorder:Hide()
	
	local flashTexture = button:CreateTexture (nil, "overlay")
	flashTexture:SetDrawLayer ("overlay", 7)
	flashTexture:Hide()
	flashTexture:SetColorTexture (1, 1, 1)
	flashTexture:SetAllPoints()
	button.FlashTexture = flashTexture
	
	button.QuickFlash = DF:CreateAnimationHub (flashTexture, function() flashTexture:Show() end, function() flashTexture:Hide() end)
	WorldQuestTracker:CreateAnimation (button.QuickFlash, "Alpha", 1, .15, 0, 1)
	WorldQuestTracker:CreateAnimation (button.QuickFlash, "Alpha", 2, .15, 1, 0)
	
	button.LoopFlash = DF:CreateAnimationHub (flashTexture, function() flashTexture:Show() end, function() flashTexture:Hide() end)
	WorldQuestTracker:CreateAnimation (button.LoopFlash, "Alpha", 1, .35, 0, .5)
	WorldQuestTracker:CreateAnimation (button.LoopFlash, "Alpha", 2, .35, .5, 0)
	button.LoopFlash:SetLooping ("REPEAT")
	
	local smallFlashOnTrack = button:CreateTexture (nil, "overlay", 7)
	smallFlashOnTrack:Hide()
	smallFlashOnTrack:SetColorTexture (1, 1, 1)
	smallFlashOnTrack:SetAllPoints()
	
	local onFlashTrackAnimation = DF:CreateAnimationHub (smallFlashOnTrack, nil, function(self) self:GetParent():Hide() end)
	onFlashTrackAnimation.FlashTexture = smallFlashOnTrack
	WorldQuestTracker:CreateAnimation (onFlashTrackAnimation, "Alpha", 1, .15, 0, 1)
	WorldQuestTracker:CreateAnimation (onFlashTrackAnimation, "Alpha", 2, .15, 1, 0)
	
	local onStartTrackAnimation = DF:CreateAnimationHub (trackingGlowBorder, WorldQuestTracker.OnStartClickAnimation)
	onStartTrackAnimation.OnFlashTrackAnimation = onFlashTrackAnimation
	WorldQuestTracker:CreateAnimation (onStartTrackAnimation, "Scale", 1, .1, .9, .9, 1.1, 1.1)
	WorldQuestTracker:CreateAnimation (onStartTrackAnimation, "Scale", 2, .1, 1.2, 1.2, 1, 1)
	
	local onEndTrackAnimation = DF:CreateAnimationHub (trackingGlowBorder, WorldQuestTracker.OnStartClickAnimation, WorldQuestTracker.OnEndClickAnimation)
	WorldQuestTracker:CreateAnimation (onEndTrackAnimation, "Scale", 1, .5, 1, 1, .6, .6)
	button.onStartTrackAnimation = onStartTrackAnimation
	button.onEndTrackAnimation = onEndTrackAnimation
	
	local onShowAnimation = DF:CreateAnimationHub (button) --, WorldQuestTracker.OnStartClickAnimation, WorldQuestTracker.OnEndClickAnimation
	WorldQuestTracker:CreateAnimation (onShowAnimation, "Scale", 1, .1, 1, 1, 1.2, 1.2)
	WorldQuestTracker:CreateAnimation (onShowAnimation, "Scale", 2, .1, 1.1, 1.1, 1, 1)
	WorldQuestTracker:CreateAnimation (onShowAnimation, "Alpha", 1, .1, 0, .5)
	WorldQuestTracker:CreateAnimation (onShowAnimation, "Alpha", 2, .1, .5, 1)
	button.OnShowAnimation = onShowAnimation
	
	local shadow = button:CreateTexture (nil, "BACKGROUND")
	shadow:SetTexture ([[Interface\COMMON\icon-shadow]])
	shadow:SetAlpha (0)
	local shadow_offset = 8
	shadow:SetPoint ("topleft", -shadow_offset, shadow_offset)
	shadow:SetPoint ("bottomright", shadow_offset, -shadow_offset)
	
	local criteriaFrame = CreateFrame ("frame", nil, button)
	--local criteriaIndicator = criteriaFrame:CreateTexture (nil, "OVERLAY", 2)
	local criteriaIndicator = criteriaFrame:CreateTexture (nil, "OVERLAY", 2)
	--criteriaIndicator:SetPoint ("bottomleft", button, "bottomleft", 1, 2)
	criteriaIndicator:SetPoint ("topleft", button, "topleft", 1, -1)
	criteriaIndicator:SetSize (28*.32, 34*.32) --original sizes: 23 37
	criteriaIndicator:SetAlpha (.893)
	criteriaIndicator:SetTexture (WorldQuestTracker.MapData.GeneralIcons.CRITERIA.icon)
	criteriaIndicator:SetTexCoord (unpack (WorldQuestTracker.MapData.GeneralIcons.CRITERIA.coords))
	criteriaIndicator:Hide()
	
	criteriaFrame.Texture = criteriaIndicator
	local criteriaIndicatorGlow = criteriaFrame:CreateTexture (nil, "OVERLAY", 1)
	criteriaIndicatorGlow:SetPoint ("center", criteriaIndicator, "center")
	criteriaIndicatorGlow:SetSize (16, 16)
	criteriaIndicatorGlow:SetTexture ([[Interface\AddOns\WorldQuestTracker\media\criteriaIndicatorGlowT]])
	criteriaIndicatorGlow:SetTexCoord (0, 1, 0, 1)
	criteriaIndicatorGlow:SetVertexColor (1, .8, 0, 0)
	criteriaIndicatorGlow:Hide()
	criteriaFrame.Glow = criteriaIndicatorGlow
	
	local criteriaAnimation = DF:CreateAnimationHub (criteriaFrame)
	DF:CreateAnimation (criteriaAnimation, "Scale", 1, .15, 1, 1, 1.1, 1.1)
	DF:CreateAnimation (criteriaAnimation, "Scale", 2, .15, 1.2, 1.2, 1, 1)
	button.CriteriaAnimation = criteriaAnimation

	local criteriaHighlight = button:CreateTexture (nil, "highlight")
	criteriaHighlight:SetPoint ("center", criteriaIndicator, "center")
	criteriaHighlight:SetSize (28*.32, 36*.32)
	criteriaHighlight:SetAlpha (.8)
	criteriaHighlight:SetTexture (WorldQuestTracker.MapData.GeneralIcons.CRITERIA.icon)
	criteriaHighlight:SetTexCoord (unpack (WorldQuestTracker.MapData.GeneralIcons.CRITERIA.coords))
	
	commonBorder:Hide()
	rareBorder:Hide()
	epicBorder:Hide()
	trackingBorder:Hide()
	
--	local timeBlip = button:CreateTexture (nil, "overlay", 2)
--	timeBlip:SetPoint ("bottomright", button, "bottomright", 2, -2)
--	timeBlip:SetSize (WorldQuestTracker.Constants.TimeBlipSize, WorldQuestTracker.Constants.TimeBlipSize)
	
	--blip do tempo restante
	button.timeBlipRed = button:CreateTexture (nil, "OVERLAY")
	button.timeBlipRed:SetPoint ("bottomright", button, "bottomright", 4, -4)
	button.timeBlipRed:SetSize (WorldQuestTracker.Constants.TimeBlipSize, WorldQuestTracker.Constants.TimeBlipSize)
	button.timeBlipRed:SetTexture ([[Interface\COMMON\Indicator-Red]])
	button.timeBlipRed:SetVertexColor (1, 1, 1)
	button.timeBlipRed:SetAlpha (1)
	
	button.timeBlipOrange = button:CreateTexture (nil, "OVERLAY")
	button.timeBlipOrange:SetPoint ("bottomright", button, "bottomright", 4, -4)
	button.timeBlipOrange:SetSize (WorldQuestTracker.Constants.TimeBlipSize, WorldQuestTracker.Constants.TimeBlipSize)
	button.timeBlipOrange:SetTexture ([[Interface\COMMON\Indicator-Yellow]])
	button.timeBlipOrange:SetVertexColor (1, .7, 0)
	button.timeBlipOrange:SetAlpha (.95)
	
	button.timeBlipYellow = button:CreateTexture (nil, "OVERLAY")
	button.timeBlipYellow:SetPoint ("bottomright", button, "bottomright", 4, -4)
	button.timeBlipYellow:SetSize (WorldQuestTracker.Constants.TimeBlipSize, WorldQuestTracker.Constants.TimeBlipSize)
	button.timeBlipYellow:SetTexture ([[Interface\COMMON\Indicator-Yellow]])
	button.timeBlipYellow:SetVertexColor (1, 1, 1)
	button.timeBlipYellow:SetAlpha (.9)
	
	button.timeBlipGreen = button:CreateTexture (nil, "OVERLAY")
	button.timeBlipGreen:SetPoint ("bottomright", button, "bottomright", 4, -4)
	button.timeBlipGreen:SetSize (WorldQuestTracker.Constants.TimeBlipSize, WorldQuestTracker.Constants.TimeBlipSize)
	button.timeBlipGreen:SetTexture ([[Interface\COMMON\Indicator-Green]])
	button.timeBlipGreen:SetVertexColor (1, 1, 1)
	button.timeBlipGreen:SetAlpha (.6)	
	
	button.questTypeBlip = button:CreateTexture (nil, "OVERLAY", 2)
	button.questTypeBlip:SetPoint ("topright", button, "topright", 2, 4)
	button.questTypeBlip:SetSize (12, 12)
	
	local amountText = button:CreateFontString (nil, "overlay", "GameFontNormal", 1)
	amountText:SetPoint ("top", button, "bottom", 1, 0)
	DF:SetFontSize (amountText, 9)
	
	local timeLeftText = button:CreateFontString (nil, "overlay", "GameFontNormal", 1)
	timeLeftText:SetPoint ("bottom", button, "bottom", 0, 1)
	--timeLeftText:SetPoint ("top", button, "top", 0, -2)
	--timeLeftText:SetPoint ("bottomright", button, "bottomright", 0, 0)
	timeLeftText:SetJustifyH ("center")
	DF:SetFontOutline (timeLeftText, true)
	DF:SetFontSize (timeLeftText, 9)
	DF:SetFontColor (timeLeftText, {1, 1, 0})
	--
	local timeLeftBackground = button:CreateTexture (nil, "background", 0)
	timeLeftBackground:SetPoint ("center", timeLeftText, "center")
	timeLeftBackground:SetTexture ([[Interface\AddOns\WorldQuestTracker\media\background_blackgradientT]])
	timeLeftBackground:SetSize (32, 10)
	timeLeftBackground:SetAlpha (.60)
	timeLeftBackground:SetAlpha (0)
	
	local amountBackground = button:CreateTexture (nil, "overlay", 0)
	amountBackground:SetPoint ("center", amountText, "center")
	amountBackground:SetTexture ([[Interface\AddOns\WorldQuestTracker\media\background_blackgradientT]])
	amountBackground:SetSize (32, 12)
	amountBackground:SetAlpha (.9)
	
	local highlight = button:CreateTexture (nil, "highlight")
	highlight:SetAllPoints()
	highlight:SetTexCoord (10/64, 54/64, 10/64, 54/64)
	highlight:SetTexture ([[Interface\Store\store-item-highlight]])

	local new = button:CreateTexture (nil, "overlay")
	new:SetPoint ("bottom", button, "bottom", 0, -3)
	new:SetSize (64*.45, 32*.45)
	new:SetAlpha (.75)
	new:SetTexture ([[Interface\AddOns\WorldQuestTracker\media\new]])
	new:SetTexCoord (0, 1, 0, .5)
	button.newIndicator = new
	
	local newFlashTexture = button:CreateTexture (nil, "overlay")
	newFlashTexture:SetPoint ("bottom", new, "bottom")
	newFlashTexture:SetSize (64*.45, 32*.45)
	newFlashTexture:SetTexture ([[Interface\AddOns\WorldQuestTracker\media\new]])
	newFlashTexture:SetTexCoord (0, 1, 0, .5)
	newFlashTexture:Hide()
	
	local newFlash = newFlashTexture:CreateAnimationGroup()
	newFlash.In = newFlash:CreateAnimation ("Alpha")
	newFlash.In:SetOrder (1)
	newFlash.In:SetFromAlpha (0)
	newFlash.In:SetToAlpha (1)
	newFlash.In:SetDuration (.3)
	newFlash.On = newFlash:CreateAnimation ("Alpha")
	newFlash.On:SetOrder (2)
	newFlash.On:SetFromAlpha (1)
	newFlash.On:SetToAlpha (1)
	newFlash.On:SetDuration (2)
	newFlash.Out = newFlash:CreateAnimation ("Alpha")
	newFlash.Out:SetOrder (3)
	newFlash.Out:SetFromAlpha (1)
	newFlash.Out:SetToAlpha (0)
	newFlash.Out:SetDuration (2)
	newFlash:SetScript ("OnPlay", function()
		newFlashTexture:Show()
	end)
	newFlash:SetScript ("OnFinished", function()
		newFlashTexture:Hide()
	end)
	button.newFlash = newFlash
	
	shadow:SetDrawLayer ("BACKGROUND", -6)
	trackingGlowBorder:SetDrawLayer ("BACKGROUND", -5)
	background:SetDrawLayer ("background", -3)
	texture:SetDrawLayer ("background", 2)
	
	commonBorder:SetDrawLayer ("border", 1)
	rareBorder:SetDrawLayer ("border", 1)
	epicBorder:SetDrawLayer ("border", 1)
	trackingBorder:SetDrawLayer ("border", 2)
	amountBackground:SetDrawLayer ("overlay", 0)
	amountText:SetDrawLayer ("overlay", 1)
	criteriaIndicatorGlow:SetDrawLayer ("OVERLAY", 1)
	criteriaIndicator:SetDrawLayer ("OVERLAY", 2)
	newFlashTexture:SetDrawLayer ("OVERLAY", 7)
	new:SetDrawLayer ("OVERLAY", 6)
	trackingGlowInside:SetDrawLayer ("OVERLAY", 7)
	factionBorder:SetDrawLayer ("OVERLAY", 6)
	
	button.timeBlipRed:SetDrawLayer ("overlay", 2)
	button.timeBlipOrange:SetDrawLayer ("overlay", 2)
	button.timeBlipYellow:SetDrawLayer ("overlay", 2)
	button.timeBlipGreen:SetDrawLayer ("overlay", 2)
	
	highlight:SetDrawLayer ("highlight", 1)
	criteriaHighlight:SetDrawLayer ("highlight", 2)
	
	button.background = background
	button.texture = texture
	button.commonBorder = commonBorder
	button.rareBorder = rareBorder
	button.epicBorder = epicBorder
	button.invasionBorder = invasionBorder
	button.trackingBorder = trackingBorder
	button.trackingGlowBorder = trackingGlowBorder
	button.factionBorder = factionBorder
	
	button.trackingGlowInside = trackingGlowInside
	
	button.timeBlip = timeBlip
	button.timeLeftText = timeLeftText
	button.timeLeftBackground = timeLeftBackground
	button.amountText = amountText
	button.amountBackground = amountBackground
	button.criteriaIndicator = criteriaIndicator
	button.criteriaHighlight = criteriaHighlight
	button.criteriaIndicatorGlow = criteriaIndicatorGlow
	button.isWorldMapWidget = true
	
	return button
end

WorldQuestTracker.QUEST_POI_FRAME_WIDTH = 1
WorldQuestTracker.QUEST_POI_FRAME_HEIGHT = 1
WorldQuestTracker.NextWorldMapWidget = 1
WorldQuestTracker.WorldMapSquares = {}

--> anchor for world quests hub, this is only shown on world maps
function WorldQuestTracker.UpdateAllWorldMapAnchors (worldMapID)
	for mapId, configTable in pairs (WorldQuestTracker.mapTables) do
	
		if (configTable.show_on_map == worldMapID) then
			local x, y = configTable.Anchor_X, configTable.Anchor_Y
			WorldQuestTracker.UpdateWorldMapAnchors (x, y, configTable.MapAnchor)
			
			local mapInfo = C_Map.GetMapInfo (mapId)
			local mapName = mapInfo and mapInfo.name or "wrong map id"
			
			configTable.MapAnchor.Title:SetText (mapName)
			
			configTable.MapAnchor.Title:ClearAllPoints()
			configTable.MapAnchor.Title:Show()
			if (configTable.GrowRight) then
				configTable.MapAnchor.Title:SetPoint ("bottomleft", configTable.MapAnchor, "topleft", 0, 0)
				configTable.MapAnchor.Title:SetJustifyH ("left")
			else
				configTable.MapAnchor.Title:SetPoint ("bottomright", configTable.MapAnchor, "topright", 0, 0)
				configTable.MapAnchor.Title:SetJustifyH ("right")
			end
			
			configTable.MapAnchor:Show()
			configTable.factionFrame:Show()
		else
			configTable.MapAnchor:Hide()
			configTable.factionFrame:Hide()
		end
	end
end

function WorldQuestTracker.UpdateWorldMapAnchors (x, y, frame)
	WorldQuestTrackerAddon.DataProvider:GetMap():SetPinPosition (frame.AnchorFrame or frame, x, y)
end

function WorldQuestTracker.GetWorldMapWidget (configTable, showTimeLeftText)
	local widget = WorldQuestTracker.WorldMapSquares [WorldQuestTracker.NextWorldMapWidget]
	widget:Show()
	widget:ClearAllPoints()
	
	tinsert (configTable.widgets, widget)
	
	if (configTable.GrowRight) then
		if (configTable.LastWidget) then
			widget:SetPoint ("topleft", configTable.LastWidget, "topright", 1, 0)
		else
			widget:SetPoint ("topleft", configTable.MapAnchor, "topright", 0, 0)
		end
	else
		if (configTable.LastWidget) then
			if (configTable.WidgetNumber == 21) then --21 disabling this feature due to argus be in the map
				if (showTimeLeftText) then
					widget:SetPoint ("topright", configTable.MapAnchor, "topleft", 0, -50)
				else
					widget:SetPoint ("topright", configTable.MapAnchor, "topleft", 0, -40)
				end
			else
				widget:SetPoint ("topright", configTable.LastWidget, "topleft", -1, 0)
			end
		else
			widget:SetPoint ("topright", configTable.MapAnchor, "topleft", 0, 0)
		end
	end
	
	widget:SetAlpha (.75)
	
	configTable.LastWidget = widget
	configTable.WidgetNumber = configTable.WidgetNumber + 1
	
	WorldQuestTracker.NextWorldMapWidget = WorldQuestTracker.NextWorldMapWidget + 1
	
	widget:SetScale (WorldQuestTracker.db.profile.worldmap_widgets.scale)
	
	return widget
end

function WorldQuestTracker.ClearWorldMapWidgets()
	for i = 1, 120 do
		local widget = WorldQuestTracker.WorldMapSquares [i]
		widget:ClearAllPoints()
		widget:Hide()
	end
	
	for mapId, configTable in pairs (WorldQuestTracker.mapTables) do
		table.wipe (configTable.widgets)
		configTable.LastWidget = nil
		configTable.WidgetNumber = 1
	end
	
	WorldQuestTracker.NextWorldMapWidget = 1
end

function WorldQuestTracker.CreateWidgetAnchors()
	
	--aqui
	
end

function WorldQuestTracker.InitializeWorldWidgets()
	
	if (WorldQuestTracker.WorldMapFrameReference) then
		return
	end
	
	if (not WorldQuestTracker.DataProvider) then
		WorldQuestTrackerAddon.CatchMapProvider (true)
	end
	
	for mapId, configTable in pairs (WorldQuestTracker.mapTables) do
		local anchor = CreateFrame ("frame", nil, worldFramePOIs)
		anchor:SetSize (1, 1)
		
		local anchorFrame = CreateFrame ("frame", nil, worldFramePOIs, WorldQuestTracker.DataProvider:GetPinTemplate())
		anchorFrame.dataProvider = WorldQuestTracker.DataProvider
		anchorFrame.worldQuest = true
		anchorFrame.owningMap = WorldQuestTracker.DataProvider:GetMap()
		anchorFrame.questID = 1
		anchorFrame.numObjectives = 1
		
		anchor:SetPoint ("center", anchorFrame, "center", 0, 0)
		anchor.AnchorFrame = anchorFrame
		
		local x, y = configTable.Anchor_X, configTable.Anchor_Y
		configTable.MapAnchor = anchor
		
		WorldQuestTracker.UpdateWorldMapAnchors (x, y, anchor)
		
		local anchorText = anchor:CreateFontString (nil, "artwork", "GameFontNormal")
		anchorText:SetPoint ("bottomleft", anchor, "topleft", 0, 0)
		anchor.Title = anchorText
		
		local factionFrame = CreateFrame ("frame", "WorldQuestTrackerFactionFrame" .. mapId, worldFramePOIs)
		tinsert (faction_frames, factionFrame)
		factionFrame:SetSize (20, 20)
		configTable.factionFrame = factionFrame
		
		tinsert (all_widgets, factionFrame)
		tinsert (all_widgets, anchorText)
	end
	
	for i = 1, 120 do
		local button = create_worldmap_square ("WorldQuestTrackerWMButton", i)
		button:Hide()
		tinsert (WorldQuestTracker.WorldMapSquares, button)
	end
	
	WorldQuestTracker.WorldSummaryQuestsSquares = {}
	for i = 1, 120 do
		local button = create_worldmap_square ("WorldQuestTrackerWorldSummarySquare", i, WorldQuestTracker.WorldSummary)
		button:Hide()
		tinsert (WorldQuestTracker.WorldSummaryQuestsSquares, button)
	end
	
	WorldQuestTracker.WorldMapFrameReference = WorldQuestTracker.WorldMapSquares [1]
end

--agenda uma atualiza��o nos widgets do world map caso os dados das quests estejam indispon�veis
local do_worldmap_update = function (newTimer)
	if (WorldQuestTracker.IsWorldQuestHub (WorldQuestTracker.GetCurrentMapAreaID())) then
		WorldQuestTracker.UpdateWorldQuestsOnWorldMap (true, false, false, false, newTimer.QuestList) --no cache true
	else
		if (WorldQuestTracker.ScheduledWorldUpdate and not WorldQuestTracker.ScheduledWorldUpdate._cancelled) then
			WorldQuestTracker.ScheduledWorldUpdate:Cancel()
		end
	end
end

function WorldQuestTracker.ScheduleWorldMapUpdate (seconds, questList)
	if (WorldQuestTracker.ScheduledWorldUpdate and not WorldQuestTracker.ScheduledWorldUpdate._cancelled) then
		WorldQuestTracker.ScheduledWorldUpdate:Cancel()
	end
	
	WorldQuestTracker.ScheduledWorldUpdate = C_Timer.NewTimer (seconds or 1, do_worldmap_update)
	WorldQuestTracker.ScheduledWorldUpdate.QuestList = questList
end

local re_check_for_questcompleted = function()
	WorldQuestTracker.UpdateWorldQuestsOnWorldMap (true, true, true)
end

local loadFromServerAttempts = {}
local MAX_RETRY_ATTEMPTS_PER_QUEST = 10
C_Timer.NewTicker (MAX_RETRY_ATTEMPTS_PER_QUEST + 2, function()
	wipe (loadFromServerAttempts)
end)

--each 60 seconds the client dumps quest reward data received from the server
C_Timer.NewTicker (60, function()
	wipe (WorldQuestTracker.HasQuestData)
end)

--wipe retry cache each 10 minutes
C_Timer.NewTicker (600, function()
	wipe (forceRetryForHub)
end)

function WorldQuestTracker.GetWorldWidgetForQuest (questID)
	for i = 1, #all_widgets do
		local widget = all_widgets [i]
		if (widget:IsShown() and widget.questID == questID) then
			return widget
		end
	end
end

function WorldQuestTracker.UpdateWorldWidget (widget, questID, numObjectives, mapID, isCriteria, isNew, isUsingTracker, timeLeft, artifactPowerIcon)

	--if the second argument is a boolean, this is a quick refresh
	if (type (questID) == "boolean" and questID) then
		questID = widget.questID
		numObjectives = widget.numObjectives
		mapID = widget.mapID
		isCriteria = widget.IsCriteria
		isNew = false
		isUsingTracker = WorldQuestTracker.db.profile.use_tracker
		timeLeft = widget.TimeLeft
		artifactPowerIcon = widget.ArtifactPowerIcon
	end

	local can_cache = true
	if (not HaveQuestRewardData (questID) or not HaveQuestData (questID)) then
		C_TaskQuest.RequestPreloadRewardData (questID)
		can_cache = false
	end
	
	local title, factionID, tagID, tagName, worldQuestType, rarity, isElite, tradeskillLineIndex, tagID, tagName, worldQuestType, rarity, isElite, tradeskillLineIndex, allowDisplayPastCritical, gold, goldFormated, rewardName, rewardTexture, numRewardItems, itemName, itemTexture, itemLevel, quantity, quality, isUsable, itemID, isArtifact, artifactPower, isStackable, stackAmount = WorldQuestTracker.GetOrLoadQuestData (questID, can_cache)									
	
	widget.questID = questID
	widget.lastQuestID = questID
	widget.worldQuest = true
	widget.numObjectives = numObjectives
	widget.mapID = mapID
	widget.Amount = 0
	widget.FactionID = factionID
	widget.Rarity = rarity
	widget.WorldQuestType = worldQuestType
	widget.IsCriteria = isCriteria
	widget.TimeLeft = timeLeft
	widget.ArtifactPowerIcon = artifactPowerIcon
	
	widget.amountText:SetText ("")
	widget.amountBackground:Hide()
	widget.timeLeftBackground:Hide()
	
	widget.isArtifact = nil
	widget.IconTexture = nil
	widget.IconText = nil
	widget.QuestType = nil
	
	if (isCriteria) then
		widget.criteriaIndicator:Show()
		widget.criteriaHighlight:Show()
		widget.criteriaIndicatorGlow:Show()
	else
		widget.criteriaIndicator:Hide()
		widget.criteriaHighlight:Hide()
		widget.criteriaIndicatorGlow:Hide()
	end
	
	if (isNew) then
		widget.newIndicator:Show()
		widget.newFlash:Play()
	else
		widget.newIndicator:Hide()
	end
	
	if (not isUsingTracker) then
		if (WorldQuestTracker.IsQuestOnObjectiveTracker (questID)) then
			widget.trackingGlowBorder:Show()
		else
			widget.trackingGlowBorder:Hide()
		end
	else
		if (WorldQuestTracker.IsQuestBeingTracked (questID)) then
			widget.trackingGlowBorder:Show()
			widget.trackingGlowInside:Show()
			widget:SetAlpha (1)
		else
			widget.trackingGlowBorder:Hide()
			widget.trackingGlowInside:Hide()
		end
	end
	
	widget.timeBlipRed:Hide()
	widget.timeBlipOrange:Hide()
	widget.timeBlipYellow:Hide()
	widget.timeBlipGreen:Hide()
	
	if (not WorldQuestTracker.db.profile.show_timeleft) then
		WorldQuestTracker.SetTimeBlipColor (widget, timeLeft)
	end
	
	widget.amountBackground:SetWidth (32)
	
	if (worldQuestType == LE_QUEST_TAG_TYPE_PVP) then
		widget.questTypeBlip:Show()
		widget.questTypeBlip:SetTexture ([[Interface\PVPFrame\Icon-Combat]])
		widget.questTypeBlip:SetTexCoord (0, 1, 0, 1)
		widget.questTypeBlip:SetAlpha (.98)
		
	elseif (worldQuestType == LE_QUEST_TAG_TYPE_PET_BATTLE) then
		widget.questTypeBlip:Show()
		widget.questTypeBlip:SetTexture ([[Interface\MINIMAP\ObjectIconsAtlas]])
		widget.questTypeBlip:SetTexCoord (unpack (WorldQuestTracker.MapData.QuestTypeIcons [WQT_QUESTTYPE_PETBATTLE].coords)) -- left right    top botton  --7.3.5
		widget.questTypeBlip:SetAlpha (.98)
		
	elseif (worldQuestType == LE_QUEST_TAG_TYPE_DUNGEON) then
		widget.questTypeBlip:Show()
		widget.questTypeBlip:SetTexture ([[Interface\Scenarios\ScenarioIcon-Boss]])
		widget.questTypeBlip:SetTexCoord (0, 1, 0, 1)
		widget.questTypeBlip:SetAlpha (.98)
		
	elseif (rarity == LE_WORLD_QUEST_QUALITY_RARE) then
		widget.questTypeBlip:Show()
		widget.questTypeBlip:SetTexture ([[Interface\AddOns\WorldQuestTracker\media\icon_star]])
		widget.questTypeBlip:SetTexCoord (6/32, 26/32, 5/32, 27/32)
		widget.questTypeBlip:SetAlpha (.89)
		
	elseif (worldQuestType == LE_QUEST_TAG_TYPE_INVASION) then
		if (UnitFactionGroup("player") == "Alliance") then
			widget.questTypeBlip:SetTexture ([[Interface\COMMON\icon-alliance]])
			widget.questTypeBlip:SetTexCoord (20/64, 46/64, 14/64, 48/64)
		
		elseif (UnitFactionGroup("player") == "Horde") then
			widget.questTypeBlip:SetTexture ([[Interface\COMMON\icon-horde]])
			widget.questTypeBlip:SetTexCoord (17/64, 49/64, 15/64, 47/64)
		end

		widget.questTypeBlip:Show()
		widget.questTypeBlip:SetAlpha (1)
	else
		widget.questTypeBlip:Hide()
	end
	
	local okay, amountGold, amountAPower, amountResources = false, 0, 0, 0
	
	if (gold > 0) then
		local texture, coords = WorldQuestTracker.GetGoldIcon()
		widget.texture:SetTexture (texture)
		
		widget.amountText:SetText (goldFormated)
		widget.amountBackground:Show()
		
		widget.IconTexture = texture
		widget.IconText = goldFormated
		widget.QuestType = QUESTTYPE_GOLD
		widget.Amount = gold
		amountGold = gold
		tinsert (WorldQuestTracker.Cache_ShownQuestOnWorldMap [WQT_QUESTTYPE_GOLD], questID)
		okay = true
	end

	if (rewardName and not okay) then
	
		widget.texture:SetTexture (WorldQuestTracker.MapData.ReplaceIcon [rewardTexture] or rewardTexture)
		
		if (numRewardItems >= 1000) then
			widget.amountText:SetText (format ("%.1fK", numRewardItems/1000))
			widget.amountBackground:SetWidth (40)
		else
			widget.amountText:SetText (numRewardItems)
		end
		
		widget.amountBackground:Show()
		
		widget.IconTexture = rewardTexture
		widget.IconText = numRewardItems
		widget.Amount = numRewardItems
		
		if (WorldQuestTracker.MapData.ResourceIcons [rewardTexture]) then
			amountResources = numRewardItems
			widget.QuestType = QUESTTYPE_RESOURCE
			tinsert (WorldQuestTracker.Cache_ShownQuestOnWorldMap [WQT_QUESTTYPE_RESOURCE], questID)
		else
			amountResources = 0
		end

		okay = true
		
		--print (title, rewardTexture) --show the quest name and the texture ID
	end
	
	if (itemName) then
		if (isArtifact) then
			local artifactIcon = artifactPowerIcon
			widget.texture:SetTexture (artifactIcon)

			widget.isArtifact = true
			if (artifactPower >= 1000) then
				if (artifactPower > 999999) then
					widget.amountText:SetText (WorldQuestTracker.ToK (artifactPower))
					local text = widget.amountText:GetText()
					text = text:gsub ("%.0", "")
					widget.amountText:SetText (text)
					
				elseif (artifactPower > 9999) then
					widget.amountText:SetText (WorldQuestTracker.ToK (artifactPower))
					
				else
					widget.amountText:SetText (format ("%.1fK", artifactPower/1000))
				end
				
				widget.amountBackground:SetWidth (36)
			else
				widget.amountText:SetText (artifactPower)
			end
			
			widget.amountBackground:Show()
			
			local artifactIcon = artifactPowerIcon
			widget.IconTexture = artifactIcon
			widget.IconText = artifactPower
			widget.QuestType = QUESTTYPE_ARTIFACTPOWER
			widget.Amount = artifactPower
			tinsert (WorldQuestTracker.Cache_ShownQuestOnWorldMap [WQT_QUESTTYPE_APOWER], questID)
			amountAPower = artifactPower
		else
		
			widget.texture:SetTexture (itemTexture)
			
			local color = ""
			if (quality == 4 or quality == 3) then
				color =  WorldQuestTracker.RarityColors [quality]
			end
			widget.amountText:SetText ((isStackable and quantity and quantity >= 1 and quantity or false) or (itemLevel and itemLevel > 5 and (color) .. itemLevel) or "")

			if (widget.amountText:GetText() and widget.amountText:GetText() ~= "") then
				widget.amountBackground:Show()
			else
				widget.amountBackground:Hide()
			end
			
			widget.IconTexture = itemTexture
			widget.IconText = widget.amountText:GetText()
			widget.QuestType = QUESTTYPE_ITEM
		end
		
		WorldQuestTracker.AllCharactersQuests_Add (questID, timeLeft, widget.IconTexture, widget.IconText)
		
		okay = true
	end
	
	if (okay) then
		WorldQuestTracker.UpdateBorder (widget, rarity, worldQuestType)
	end
	
	return okay, amountGold, amountResources, amountAPower
end


function WorldQuestTracker.DelayedShowWorldQuestPins()
	if (WorldQuestTracker.DelayedWorldQuestUpdate) then
		return
	end
	
	WorldQuestTracker.DelayedWorldQuestUpdate = C_Timer.NewTimer (0.05, function()
		WorldQuestTracker.DelayedWorldQuestUpdate = nil
		if (WorldMapFrame and WorldMapFrame:IsShown() and WorldQuestTracker.IsWorldQuestHub (WorldMapFrame.mapID)) then
			WorldQuestTracker.UpdateWorldQuestsOnWorldMap (true)
		end
	end)
end

-- ~world
function WorldQuestTracker.UpdateWorldQuestsOnWorldMap (noCache, showFade, isQuestFlaggedRecheck, forceCriteriaAnimation, questList)
	if (UnitLevel ("player") < 110) then
		WorldQuestTracker.HideWorldQuestsOnWorldMap()
		
		--> show a message telling why world quests aren't shown
		if (WorldQuestTracker.db.profile and not WorldQuestTracker.db.profile.low_level_tutorial) then
			WorldQuestTracker.db.profile.low_level_tutorial = true
			WorldQuestTracker:Msg ("World quests aren't shown because you're below level 110.") --> localize-me
		end
		return

	end
	
	WorldQuestTracker.RefreshStatusBarVisibility()

	WorldQuestTracker.ClearZoneSummaryButtons()
	
	WorldQuestTracker.LastUpdate = GetTime()
	wipe (factionAmountForEachMap)
	
	--limpa todos os widgets no world map
	WorldQuestTracker.ClearWorldMapWidgets()
--	
	if (WorldQuestTracker.WorldWidgets_NeedFullRefresh) then
		WorldQuestTracker.WorldWidgets_NeedFullRefresh = nil
		noCache = true
	end
	
	local questsAvailable = {}
	local needAnotherUpdate = false
	local filters = WorldQuestTracker.db.profile.filters
	local timePriority = WorldQuestTracker.db.profile.sort_time_priority and WorldQuestTracker.db.profile.sort_time_priority * 60 --4 8 12 16 24
	local showTimeLeftText = WorldQuestTracker.db.profile.show_timeleft
	local forceShowBrokenShore = WorldQuestTracker.db.profile.filter_force_show_brokenshore

	local sortByTimeLeft = WorldQuestTracker.db.profile.force_sort_by_timeleft
	local worldMapID = WorldQuestTracker.GetCurrentMapAreaID()
	local bountyQuestID = WorldQuestTracker.GetCurrentBountyQuest()
	
	--store a list of quests that failed to update on this refresh
	local failedToUpdate = {}
	
	for mapId, configTable in pairs (WorldQuestTracker.mapTables) do
	
		questsAvailable [mapId] = {}

		local taskInfo = GetQuestsForPlayerByMapID (mapId, mapId)
		local shownQuests = 0

		if (taskInfo and #taskInfo > 0 and configTable.show_on_map [worldMapID]) then
			for i, info in ipairs (taskInfo) do
				local questID = info.questId
				local canUpdateQuest = false
				
				if (not questList) then
					canUpdateQuest = true
					
				elseif (questList [questID]) then
					canUpdateQuest = true
				end
				
				if (canUpdateQuest or not WorldQuestTracker.HasQuestData [questID] or not WorldQuestTracker.WorldSummary [questID]) then
					if (HaveQuestData (questID) and HaveQuestRewardData (questID)) then
					
						WorldQuestTracker.HasQuestData [questID] = true
					
						local isWorldQuest = QuestMapFrame_IsQuestWorldQuest (questID)
						
						if (isWorldQuest and info.mapID == mapId) then
						
							--time left
							local timeLeft = WorldQuestTracker.GetQuest_TimeLeft (questID)
							--gold
							local gold, goldFormated = WorldQuestTracker.GetQuestReward_Gold (questID)
							--class hall resource
							local rewardName, rewardTexture, numRewardItems = WorldQuestTracker.GetQuestReward_Resource (questID)
							--item
							local itemName, itemTexture, itemLevel, quantity, quality, isUsable, itemID, isArtifact, artifactPower, isStackable, stackAmount = WorldQuestTracker.GetQuestReward_Item (questID)
							--type
							local title, factionID, tagID, tagName, worldQuestType, rarity, isElite, tradeskillLineIndex = WorldQuestTracker.GetQuest_Info (questID)
							
							--[=
							if ((not gold or gold <= 0) and not rewardName and not itemName) then
								C_TaskQuest.RequestPreloadRewardData (questID)
								needAnotherUpdate = true; if (UpdateDebug) then print ("NeedUpdate 1") end
								failedToUpdate [questID] = true
							end
							--]=]
							
							local filter, order = WorldQuestTracker.GetQuestFilterTypeAndOrder (worldQuestType, gold, rewardName, itemName, isArtifact, stackAmount, numRewardItems, rewardTexture)
							order = order or 1
							
							if (sortByTimeLeft) then
								order = abs (timeLeft - 10000)
								
							elseif (timePriority) then --timePriority j� multiplicado por 60
								if (timeLeft < timePriority) then
									order = abs (timeLeft - 1000)
								end
							end

							if (filters [filter] or rarity == LE_WORLD_QUEST_QUALITY_EPIC or (forceShowBrokenShore and WorldQuestTracker.IsArgusZone (mapId))) then --force show broken shore questsmapId == 1021
								tinsert (questsAvailable [mapId], {questID, order, info.numObjectives, info.x, info.y, filter})
								shownQuests = shownQuests + 1
								
							elseif (WorldQuestTracker.db.profile.filter_always_show_faction_objectives) then
							
									local isCriteria = IsQuestCriteriaForBounty (questID, bountyQuestID)
									
									if (isCriteria) then
										tinsert (questsAvailable [mapId], {questID, order, info.numObjectives, info.x, info.y, filter})
										shownQuests = shownQuests + 1
									end
								--end
							else
								--if (mapId == 1033) then
								--	print ("DENIED:", i, title, filter)
								--end
							end
							
						end--is world quest and the map is valid
						
					else --dont have quest data
						--> check if isn't a quest removed from the game before request data from server
						local title, factionID, tagID, tagName, worldQuestType, rarity, isElite, tradeskillLineIndex = WorldQuestTracker.GetQuest_Info (questID)
						if (title) then
							C_TaskQuest.RequestPreloadRewardData (questID)
							loadFromServerAttempts [questID] = (loadFromServerAttempts [questID] or 0) + 1
							if (loadFromServerAttempts [questID] <= MAX_RETRY_ATTEMPTS_PER_QUEST) then
								failedToUpdate [questID] = true
								needAnotherUpdate = true; if (UpdateDebug) then print ("NeedUpdate 2") end
							end
						end

					end--end have quest data
					
				end--end can update quest
			end
			
			table.sort (questsAvailable [mapId], function (t1, t2) return t1[2] < t2[2] end)
			
			if (shownQuests == 0) then
				--hidar os widgets extras mque pertencem a zone sem quests
				--for o = 1, #WorldQuestTracker.WorldMapSupportWidgets [mapId] do
				--	WorldQuestTracker.WorldMapSupportWidgets [mapId] [o]:Hide()
				--end
			end
		else
			if (not taskInfo) then
				needAnotherUpdate = true; if (UpdateDebug) then print ("NeedUpdate 3") end
				
			elseif (#taskInfo == 0) then
				--hidar os widgets extras mque pertencem a zone sem quests
				--if (WorldQuestTracker.WorldMapSupportWidgets [mapId]) then
				--	for o = 1, #WorldQuestTracker.WorldMapSupportWidgets [mapId] do
				--		WorldQuestTracker.WorldMapSupportWidgets [mapId] [o]:Hide()
				--	end
				--end
			end
		end
	end

	local availableQuests = 0
	local isUsingTracker = WorldQuestTracker.db.profile.use_tracker
	
	--this shouldn't be here, need to move
	local timePriority = WorldQuestTracker.db.profile.sort_time_priority
	local UseTimePriorityAlpha = WorldQuestTracker.db.profile.alpha_time_priority
	if (timePriority) then
		if (timePriority == 4) then
			timePriority = 60*4
		elseif (timePriority == 8) then
			timePriority = 60*8
		elseif (timePriority == 12) then
			timePriority = 60*12
		elseif (timePriority == 16) then
			timePriority = 60*16
		elseif (timePriority == 24) then
			timePriority = 60*24
		end
	end
	
	--> ~artifactpower ~icon
	local artifactPowerIcon = WorldQuestTracker.MapData.ItemIcons ["BFA_ARTIFACT"]
	
	wipe (WorldQuestTracker.Cache_ShownQuestOnWorldMap)
	WorldQuestTracker.Cache_ShownQuestOnWorldMap [WQT_QUESTTYPE_GOLD] = {}
	WorldQuestTracker.Cache_ShownQuestOnWorldMap [WQT_QUESTTYPE_RESOURCE] = {}
	WorldQuestTracker.Cache_ShownQuestOnWorldMap [WQT_QUESTTYPE_APOWER] = {}
	
	local worldMapID = WorldQuestTracker.GetCurrentMapAreaID()
	local addToWorldMap, questCounter = {}, 1
	
	for mapId, configTable in pairs (WorldQuestTracker.mapTables) do
		local taskInfo = GetQuestsForPlayerByMapID (mapId, mapId)
		local taskIconIndex = 1
		local widgets = configTable.widgets
		
		if (taskInfo and #taskInfo > 0) then
			availableQuests = availableQuests + #taskInfo
		
			for i, quest in ipairs (questsAvailable [mapId]) do
				
				local questID = quest [1]
				local numObjectives = quest [3]

				if (HaveQuestData (questID)) then
					local isWorldQuest = QuestMapFrame_IsQuestWorldQuest (questID)

					if (isWorldQuest) then
						--is a new quest?
						local isNew = WorldQuestTracker.SavedQuestList_IsNew (questID)
						
						--info
						local can_cache = true
						local title, factionID, tagID, tagName, worldQuestType, rarity, isElite, tradeskillLineIndex, tagID, tagName, worldQuestType, rarity, isElite, tradeskillLineIndex, allowDisplayPastCritical, gold, goldFormated, rewardName, rewardTexture, numRewardItems, itemName, itemTexture, itemLevel, quantity, quality, isUsable, itemID, isArtifact, artifactPower, isStackable, stackAmount = WorldQuestTracker.GetOrLoadQuestData (questID, can_cache)
						
						--tempo restante
						local timeLeft = WorldQuestTracker.GetQuest_TimeLeft (questID)
						if (not timeLeft or timeLeft == 0) then
							timeLeft = 1
						end

						--need a clean up on this code
						
						if (timeLeft and timeLeft > 0) then

							local isCriteria = IsQuestCriteriaForBounty (questID, bountyQuestID)
							
							if (isCriteria) then
								factionAmountForEachMap [mapId] = (factionAmountForEachMap [mapId] or 0) + 1
							end
							
							local widget = WorldQuestTracker.GetWorldMapWidget (configTable, showTimeLeftText)
							
							if (not widget) then
								--se n�o tiver o widget, o jogador abriu o mapa muito rapidamente
								if (WorldMapFrame:IsShown()) then
									WorldQuestTracker.ScheduleWorldMapUpdate (1.5)
									WorldQuestTracker.PlayLoadingAnimation()
								end
								return
							end

							if (timePriority and UseTimePriorityAlpha) then
								if (timeLeft < timePriority) then
									widget:SetAlpha (WQT_WORLDWIDGET_ALPHA)
								else
									widget:SetAlpha (.4)
								end
							else
								widget:SetAlpha (WQT_WORLDWIDGET_ALPHA)
							end
							
							if (widget) then
							
								--need a clean up on this code

								if (showTimeLeftText) then
									widget.timeLeftText:Show()
									widget.timeLeftBackground:Show()
									widget.timeLeftText:SetText (timeLeft > 1440 and floor (timeLeft/1440) .. "d" or timeLeft > 60 and floor (timeLeft/60) .. "h" or timeLeft .. "m")
								else
									widget.timeLeftBackground:Hide()
									widget.timeLeftText:Hide()
								end

								tinsert (addToWorldMap, {questID, mapId, numObjectives, questCounter, title, quest [4], quest [5], quest [6], worldQuestType, isCriteria, isNew, timeLeft, quest [2]})
								questCounter = questCounter + 1
								
								--update the widget in the world map
								if (WorldQuestTracker.DoAnimationsOnWorldMapWidgets) then
									widget.OnShowAnimation:Play()
								end

								--todo: re write this part
									--atualiza o widget
									widget:Hide()
							end

							
							taskIconIndex = taskIconIndex + 1
						end
					end
				else
					--nao tem os dados da quest ainda
					needAnotherUpdate = true; if (UpdateDebug) then print ("NeedUpdate 5") end
					failedToUpdate [questID] = true
				end
			end
			
--			for i = taskIconIndex, 20 do
--				widgets[i]:Hide()
--			end
		else
			if (not taskInfo) then
				needAnotherUpdate = true; if (UpdateDebug) then print ("NeedUpdate 6") end
			else
--				for i = taskIconIndex, 20 do
--					widgets[i]:Hide()
--				end
			end
		end
		
		--quantidade de quest para a faccao
		configTable.factionFrame.amount = factionAmountForEachMap [mapId]
	end
	
	--force retry in case the game just opened and the server might not has sent all quests
	forceRetryForHub [WorldMapFrame.mapID] = forceRetryForHub [WorldMapFrame.mapID] or forceRetryForHubAmount
	if (forceRetryForHub [WorldMapFrame.mapID] > 0) then
		needAnotherUpdate = true
		forceRetryForHub [WorldMapFrame.mapID] = forceRetryForHub [WorldMapFrame.mapID] - 1
	end
	
	if (needAnotherUpdate) then
		if (WorldMapFrame:IsShown()) then
			WorldQuestTracker.ScheduleWorldMapUpdate (1.5, failedToUpdate)
			WorldQuestTracker.PlayLoadingAnimation()
		end
	else
		if (WorldQuestTracker.IsPlayingLoadAnimation()) then
			WorldQuestTracker.StopLoadingAnimation()
		end
	end
	if (showFade) then
		worldFramePOIs.fadeInAnimation:Play()
	end
	if (availableQuests == 0 and (WorldQuestTracker.InitAt or 0) + 10 > GetTime()) then
		WorldQuestTracker.ScheduleWorldMapUpdate()
	end
	
	--> need update the anchors for windowed and fullscreen modes, plus need to show and hide for different worlds
	WorldQuestTracker.UpdateAllWorldMapAnchors (worldMapID)

	WorldQuestTracker.HideZoneWidgets()
	WorldQuestTracker.SavedQuestList_CleanUp()

	if (not WorldQuestTracker.db.profile.disable_world_map_widgets) then
		WorldQuestTracker.UpdateWorldMapSmallIcons (addToWorldMap, questList)
	else
		local map = WorldQuestTrackerDataProvider:GetMap()
		for pin in map:EnumeratePinsByTemplate ("WorldQuestTrackerWorldMapPinTemplate") do
			map:RemovePin (pin)
			if (pin.Child) then
				pin.Child:Hide()
			end
		end
	end
	
	WorldQuestTrackerWorldSummaryFrame.Update (addToWorldMap, questList)

	WorldQuestTracker.DoAnimationsOnWorldMapWidgets = false
	
end

local mapRangeValues = {
	0.18, .38, 5.2, 3.3
}

hooksecurefunc (WorldMapFrame.ScrollContainer, "ZoomIn", function()
	local mapScale = WorldMapFrame.ScrollContainer:GetCanvasScale()
	local pinScale = DF:MapRangeClamped (mapRangeValues[1], mapRangeValues[2], mapRangeValues[3], mapRangeValues[4], mapScale)
	--print ("map",mapScale, "pin", pinScale)
	
	if (WorldQuestTracker.IsWorldQuestHub (WorldMapFrame.mapID)) then
		for _, widget in pairs (WorldQuestTracker.WorldMapSmallWidgets) do
			widget:SetScale (pinScale + WorldQuestTracker.db.profile.world_map_config.onmap_scale_offset)
		end
	end
end)

hooksecurefunc (WorldMapFrame.ScrollContainer, "ZoomOut", function()
	local mapScale = WorldMapFrame.ScrollContainer:GetCanvasScale()
	local pinScale = DF:MapRangeClamped (mapRangeValues[1], mapRangeValues[2], mapRangeValues[3], mapRangeValues[4], mapScale)
	--print ("map",mapScale, "pin", pinScale)
	
	if (WorldQuestTracker.IsWorldQuestHub (WorldMapFrame.mapID)) then
		for _, widget in pairs (WorldQuestTracker.WorldMapSmallWidgets) do
			widget:SetScale (pinScale + WorldQuestTracker.db.profile.world_map_config.onmap_scale_offset)
		end
	end
end)

function WorldQuestTracker.UpdateQuestOnWorldMap (questID)
	if (WorldMapFrame:IsShown() and WorldQuestTracker.IsWorldQuestHub (WorldMapFrame.mapID)) then
		--update in the world summary
		for _, widget in pairs (WorldQuestTracker.WorldSummaryQuestsSquares) do
			if (widget.questID == questID and widget:IsShown()) then
				--quick refresh
				WorldQuestTracker.UpdateWorldWidget (widget, true)
				break
			end
		end
		
		--update in the world map
		for _, widget in pairs (WorldQuestTracker.WorldMapSmallWidgets) do
			if (widget.questID == questID and widget:IsShown()) then
				--quick refresh
				WorldQuestTracker.SetupWorldQuestButton (widget, true)
				break
			end
		end
	end
end

local lazyUpdate = CreateFrame ("frame")
--list of quests queued to receive an update
lazyUpdate.WidgetsToUpdate = {}

--store quests that are shown in the world map with the value poiting to its widget
lazyUpdate.ShownQuests = {}

--list of all widgets created
WorldQuestTracker.WorldMapSmallWidgets = {}

local scheduledIconUpdate = function (questTable)
	
	local questID, mapID, numObjectives, questCounter, questName, x, y = unpack (questTable)
	
	--is already showing this quest?
	if (lazyUpdate.ShownQuests [questID]) then
		return
	end
	
	--update the quest counter
	questCounter = WorldQuestTracker.WorldMapQuestCounter
	WorldQuestTracker.WorldMapQuestCounter = WorldQuestTracker.WorldMapQuestCounter + 1
	
	--get a widget button for this quest
	local button = WorldQuestTracker.WorldMapSmallWidgets [questCounter]
	if (not button) then
		button = WorldQuestTracker.CreateZoneWidget (questCounter, "WorldQuestTrackerWorldMapSmallWidget", worldFramePOIs) --, "WorldQuestTrackerWorldMapPinTemplate"
		button.IsWorldZoneQuestButton = true
		WorldQuestTracker.WorldMapSmallWidgets [questCounter] = button
	end
	
	--get a pin in the world map from the data provider
	local pin = WorldQuestTrackerDataProvider:GetMap():AcquirePin ("WorldQuestTrackerWorldMapPinTemplate", "questPin")
	pin.Child = button
	button:ClearAllPoints()
	button:SetParent (pin)
	button:SetPoint ("center")
	
	lazyUpdate.ShownQuests [questID] = button
	
	button:Show()
	
	local mapScale = WorldMapFrame.ScrollContainer:GetCanvasScale()
	local pinScale = DF:MapRangeClamped (mapRangeValues[1], mapRangeValues[2], mapRangeValues[3], mapRangeValues[4], mapScale)
	button:SetScale (pinScale + WorldQuestTracker.db.profile.world_map_config.onmap_scale_offset)
	
--	if (button.questID ~= questID and HaveQuestData (questID)) then
		--> can cache here, at this point the quest data should already be in the cache
		local title, factionID, tagID, tagName, worldQuestType, rarity, isElite, tradeskillLineIndex, tagID, tagName, worldQuestType, rarity, isElite, tradeskillLineIndex, allowDisplayPastCritical, gold, goldFormated, rewardName, rewardTexture, numRewardItems, itemName, itemTexture, itemLevel, quantity, quality, isUsable, itemID, isArtifact, artifactPower, isStackable, stackAmount = WorldQuestTracker.GetOrLoadQuestData (questID)
		
		button.questID = questID
		button.mapID = mapID
		button.numObjectives = numObjectives
		button.questName = questName
		
		local bountyQuestId = WorldQuestTracker.GetCurrentBountyQuest()
		local isCriteria = IsQuestCriteriaForBounty (questID, bountyQuestId)
		
		WorldQuestTracker.SetupWorldQuestButton (button, worldQuestType, rarity, isElite, tradeskillLineIndex, nil, nil, isCriteria, nil, mapID)
--	end

	local newX, newY = HereBeDragons:TranslateZoneCoordinates (x, y, mapID, WorldMapFrame.mapID, false)
	pin:SetPosition (newX, newY)
	pin:SetSize (22, 22)
	pin.IsInUse = true
	
	button:SetAlpha (.74)
end

local lazyUpdateEnded = function()

	local total_Gold, total_Resources, total_APower = 0, 0, 0
	
	for _, widget in pairs (WorldQuestTracker.WorldMapSmallWidgets) do
		if (widget.Amount) then
			if (widget.QuestType == QUESTTYPE_GOLD) then
				total_Gold = total_Gold + (widget.Amount or 0)
				
			elseif (widget.QuestType == QUESTTYPE_RESOURCE) then
				total_Resources = total_Resources + (widget.Amount or 0)
				
			elseif (widget.QuestType == QUESTTYPE_ARTIFACTPOWER) then
				total_APower = total_APower + (widget.Amount or 0)
				
			end
		end
	end
	
	WorldQuestTracker.UpdateResourceIndicators (total_Gold, total_Resources, total_APower)
	
end

local lazyUpdateFunc = function (self, deltaTime)
	if (WorldMapFrame:IsShown() and #lazyUpdate.WidgetsToUpdate > 0 and WorldQuestTracker.IsWorldQuestHub (WorldMapFrame.mapID)) then
		
		--if framerate is low, update more quests at the same time
		local frameRate = GetFramerate()
		local amountToUpdate = 1
		
		if (frameRate < 20) then
			amountToUpdate = amountToUpdate + 3
		elseif (frameRate < 60) then
			amountToUpdate = amountToUpdate + 2
		else
			amountToUpdate = amountToUpdate + 1
		end
	
		for i = 1, amountToUpdate do
			local questTable = tremove (lazyUpdate.WidgetsToUpdate)
			if (questTable) then
				scheduledIconUpdate (questTable)
			else
				break
			end
		end
	else
		local map = WorldQuestTrackerDataProvider:GetMap()
		for pin in map:EnumeratePinsByTemplate ("WorldQuestTrackerWorldMapPinTemplate") do
			if (not pin.IsInUse) then
				map:RemovePin (pin)
			end
		end
		
		for questCounter, button in pairs (WorldQuestTracker.WorldMapSmallWidgets) do
			local pin = button:GetParent()
			if (pin and (pin.Child ~= button or not pin:IsShown())) then
				button:Hide()
			end
		end
		
		WorldQuestTracker.UpdatingForMap = nil
		lazyUpdateEnded()
		lazyUpdate:SetScript ("OnUpdate", nil)
	end
end

WorldQuestTracker.WorldMapQuestCounter = 0

--questsToUpdate is a hash table with questIDs to just update / if is nil it's a full refresh
function WorldQuestTracker.UpdateWorldMapSmallIcons (addToWorldMap, questsToUpdate)
	
	if (not WorldQuestTracker.db.profile.world_map_config.onmap_show) then
		return
	end
	
	wipe (lazyUpdate.WidgetsToUpdate)
	lazyUpdate.WidgetsToUpdate = DF.table.copy ({}, addToWorldMap)
	
	--which mapID quests being update belongs to
	WorldQuestTracker.UpdatingForMap = WorldMapFrame.mapID
	
	--if a full refresh?
	if (not questsToUpdate) then
		WorldQuestTracker.WorldMapQuestCounter = 0
		wipe (lazyUpdate.ShownQuests)
	end
	
	--tag pins 'not in use'
	local removedPins = 0
	local map = WorldQuestTrackerDataProvider:GetMap()
	for pin in map:EnumeratePinsByTemplate ("WorldQuestTrackerWorldMapPinTemplate") do
		--if there's a list of unique quests to update, only unitilize the pin if it's showing the quest it'll update
		if (questsToUpdate) then
			if (questsToUpdate [pin.questID]) then
				pin.IsInUse = false
				pin.Child:Hide()
				map:RemovePin (pin)
				removedPins = removedPins + 1
			end
		else
			pin.IsInUse = false
		end
	end
	
	lazyUpdateEnded()
	lazyUpdate:SetScript ("OnUpdate", lazyUpdateFunc)
end

--on maximize
if (WorldMapFrame.BorderFrame.MaximizeMinimizeFrame.MaximizeButton) then
	WorldMapFrame.BorderFrame.MaximizeMinimizeFrame.MaximizeButton:HookScript ("OnClick", function()
		WorldQuestTracker.UpdateZoneSummaryFrame()
		WorldQuestTracker.UpdateStatusBarAnchors()
	end)
end

--on minimize
if (WorldMapFrame.BorderFrame.MaximizeMinimizeFrame.MinimizeButton) then
	WorldMapFrame.BorderFrame.MaximizeMinimizeFrame.MinimizeButton:HookScript ("OnClick", function()
		WorldQuestTracker.UpdateZoneSummaryFrame()
		WorldQuestTracker.UpdateStatusBarAnchors()
	end)
end

--quando clicar no bot�o de por o world map em fullscreen ou window mode, reajustar a posi��o dos widgets
if (WorldMapFrameSizeDownButton) then
	WorldMapFrameSizeDownButton:HookScript ("OnClick", function() --window mode
		if (WorldQuestTracker.UpdateWorldQuestsOnWorldMap) then
			if (WorldQuestTracker.IsCurrentMapQuestHub()) then
				WorldQuestTracker.UpdateWorldQuestsOnWorldMap (false, true)
				WorldQuestTracker.RefreshStatusBarVisibility()
				C_Timer.After (1, WorldQuestTracker.RefreshStatusBarVisibility)
			end
		end
	end)
	
elseif (MinimizeButton) then
	MinimizeButton:HookScript ("OnClick", function() --window mode
		if (WorldQuestTracker.UpdateWorldQuestsOnWorldMap) then
			if (WorldQuestTracker.IsCurrentMapQuestHub()) then
				WorldQuestTracker.UpdateWorldQuestsOnWorldMap (false, true)
				WorldQuestTracker.RefreshStatusBarVisibility()
				C_Timer.After (1, WorldQuestTracker.RefreshStatusBarVisibility)
			end
		end
	end)
end

if (WorldMapFrameSizeUpButton) then
	WorldMapFrameSizeUpButton:HookScript ("OnClick", function() --full screen
		if (WorldQuestTracker.UpdateWorldQuestsOnWorldMap) then
			if (WorldQuestTracker.IsCurrentMapQuestHub()) then
				WorldQuestTracker.UpdateWorldQuestsOnWorldMap (false, true)
				C_Timer.After (1, WorldQuestTracker.RefreshStatusBarVisibility)
			end
		end
	end)

elseif (MaximizeButton) then
	MaximizeButton:HookScript ("OnClick", function() --full screen
		if (WorldQuestTracker.UpdateWorldQuestsOnWorldMap) then
			if (WorldQuestTracker.IsCurrentMapQuestHub()) then
				WorldQuestTracker.UpdateWorldQuestsOnWorldMap (false, true)
				C_Timer.After (1, WorldQuestTracker.RefreshStatusBarVisibility)
			end
		end
	end)
end

--atualiza a quantidade de alpha nos widgets que mostram quantas quests ha para a fac��o
function WorldQuestTracker.UpdateFactionAlpha()
	for _, factionFrame in ipairs (faction_frames) do
		if (factionFrame.enabled) then
			factionFrame:SetAlpha (1)
		else
			factionFrame:SetAlpha (.65)
		end
	end
end



