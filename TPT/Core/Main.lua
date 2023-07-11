local AddOn, TPT, Private = select(2, ...):Init()

local GetTime = GetTime
local UIParent = UIParent
local UnitGUID = UnitGUID
local UnitRace = UnitRace
local UnitClass = UnitClass
local Timer = C_Timer.NewTicker
local TimerAfter = C_Timer.After
local GetSpellInfo = GetSpellInfo
local IsInInstance = IsInInstance
local CooldownFrame_Set = CooldownFrame_Set
local GetSpellTexture = C_GetSpellTexture or GetSpellTexture

local CURRENT_ZONE_TYPE
local PREVIOUS_ZONE_TYPE

local CRF

local INSPECT_FRAME
local INSPECT_CURRENT
local QUERY_SPEC_TICK
local QUERY_SPEC_TICK_TIMEOUT
local GROUP_ROSTER_UPDATE_DELAY_QUEUED

local GROUP_ROSTER_UPDATE
local INSPECT_READY
local PLAYER_FACTION

local HEX
local FERAL_CHARGE
local FERAL_CHARGE_CAT
local FERAL_CHARGE_BEAR
local RACIAL_UNDEAD
local TRINKET_ALLIANCE
local TRINKET_HORDE

local GUID_ACTIVE

TPT.Icons = CreateFrame("Frame", nil, UIParent)
TPT.Anchors = CreateFrame("Frame", nil, UIParent)

--[[

	GLOW

]]

local function AnimateTexCoords_OnUpdate(Self, Elapsed)
	AnimateTexCoords(Self.A, 256, 256, 48, 48, 22, Elapsed, 0.03)
end

local function GlowHide(Icon)
	if ( Icon.Glow and Icon.Glow.SetScript ) then
		Icon.Swipe:SetAlpha(1)
		Icon.Glow:Hide()
		Icon.Glow:SetScript("OnUpdate", nil)
		Icon.Glow.SetScript = nil
	end
end

local function Glow(SpellName, Event, Anchor)
	for i=1,#Anchor do
		local Icon = Anchor[i]

		if ( Icon.Name == SpellName ) then
			if ( Event == "SPELL_AURA_APPLIED" ) then
				if ( not Icon.Glow ) then
					Icon.Glow = CreateFrame("Frame", nil, Icon, "TGlow")
				end

				Icon.Swipe:SetAlpha(0)
				Icon.Glow:SetScript("OnUpdate", AnimateTexCoords_OnUpdate)
				Icon.Glow:Show()
			else
				GlowHide(Icon)

				if ( Icon.Flash ) then
					Icon.Flash.D:Play()
				end
			end

			break
		end
	end
end

--[[

	COOLDOWN

]]

local function Active(Icon, Start)
	local GUID = Icon.GUID
	local AbilityName = Icon.Name
	local Unit = GUID_ACTIVE[GUID]

	-- Unit
	if ( Start and not Unit ) then
		Unit = {}
		GUID_ACTIVE[GUID] = Unit
	end

	-- Start
	if ( Start ) then
		Unit[AbilityName] = Start
	elseif ( Unit ) then
		Start = Unit[AbilityName]
	end

	return Start, Unit
end

local function Stop(Icon)
	local StartTime, StartUnit = Active(Icon)

	if ( Icon.Active or StartTime ) then
		CooldownFrame_Set(Icon.Swipe, 0, 0, 0)

		if ( StartTime ) then
			StartUnit[Icon.Name] = nil
		end
	end
end

local function Start(Anchor, Icon, SetCD)
	if ( Icon.Name ) then
		CooldownFrame_Set(Icon.Swipe, Active(Icon, GetTime()), SetCD or Icon.CD, 1)

		Icon.Active = true

		if ( TPT.DB.Glow ) then
			if ( not Icon.Flash ) then
				Icon.Flash = CreateFrame("Frame", nil, Icon, "TGlowFlash")
			end
			Icon.Flash.D:Play()
		end

		if ( TPT.DB.Hidden ) then
			TPT:IconUpdate(Anchor.i)
		else
			Icon:Show()
		end
	end
end

--[[

	ICON

]]

function TPT:IconUpdate(i)
	local Anchor = TPT.Anchors[i]
	local LastIndex = 0
	local Count = 1
	local Time = GetTime()

	for Index=1,#Anchor do
		local Icon = Anchor[Index]
		local StartTime

		if ( TPT.DB.Hidden and not Icon.Active ) then
			StartTime = Active(Icon)
		end

		if ( Icon and Icon.Name and (not TPT.DB.Hidden or Icon.Active or (StartTime and (Time - StartTime) < Icon.CD)) ) then
			Icon:ClearAllPoints()

			if TPT.DB.Rows then
				if ( Count == 1 ) then
					Icon:SetPoint(TPT.DB.Left and "TOPRIGHT" or "TOPLEFT", Anchor, TPT.DB.Left and "BOTTOMLEFT" or "BOTTOMRIGHT", TPT.DB.Left and -1 * TPT.DB.SpaceX or TPT.DB.SpaceX, 0)
				elseif ( Count % 2 == 0 ) then
					Icon:SetPoint(TPT.DB.Left and "TOP" or "TOP", Anchor[LastIndex], TPT.DB.Left and "BOTTOM" or "BOTTOM", TPT.DB.Left and 0 or 0, -1 * TPT.DB.SpaceY )			
				else
					Icon:SetPoint(TPT.DB.Left and "BOTTOMRIGHT" or "BOTTOMLEFT", Anchor[LastIndex], TPT.DB.Left and "TOPLEFT" or "TOPRIGHT", TPT.DB.Left and -1 * TPT.DB.SpaceX or TPT.DB.SpaceX, TPT.DB.SpaceY)
				end
			else
				if ( Count == 1 ) then	
					Icon:SetPoint(TPT.DB.Left and "TOPRIGHT" or "TOPLEFT", Anchor, TPT.DB.Left and "BOTTOMLEFT" or "BOTTOMRIGHT", TPT.DB.Left and -1 * TPT.DB.SpaceX or TPT.DB.SpaceX, 0)
				else
					Icon:SetPoint(TPT.DB.Left and "RIGHT" or "LEFT", Anchor[LastIndex], TPT.DB.Left and "LEFT" or "RIGHT", TPT.DB.Left and -1 * TPT.DB.SpaceX or TPT.DB.SpaceX, 0)
				end
			end

			LastIndex = Index
			Count = Count + 1
			Icon:Show()
		else
			Icon:Hide()
		end
	end
end

local function TooltipOnEnter(Self)
	if ( TPT.DB.Tooltip and Self.ID ) then
		GameTooltip:SetOwner(TPT, "ANCHOR_CURSOR")
		GameTooltip:SetHyperlink("spell:"..Self.ID)
	end
end

local function TooltipOnLeave(Self)
	if ( TPT.DB.Tooltip and Self.ID ) then
		GameTooltip:Hide()
	end
end

local function Cooldown_OnHide(Self)
	local Icon = Self:GetParent()
	local Anchor = Icon.Anchor

	GlowHide(Icon)

	Icon.Active = nil

	if ( TPT.DB.Hidden ) then
		TPT:IconUpdate(Anchor.i)
	end
end

local function IconCreate(Anchor)
	local Icon = CreateFrame("Frame", nil, TPT.Icons, "ActionButtonTemplate")
	local Swipe = CreateFrame("Cooldown", nil, Icon, "CooldownFrameTemplate")
	Icon:SetSize(40,40)
	Icon.Swipe = Swipe
	Icon.Anchor = Anchor

	local Texture = Icon:CreateTexture(nil,"ARTWORK")
	Texture:SetAllPoints(true)
	Icon.Texture = Texture

	Icon:EnableMouse()
	Swipe:HookScript("OnHide", Cooldown_OnHide)
	Icon:SetScript("OnEnter", TooltipOnEnter)
	Icon:SetScript("OnLeave", TooltipOnLeave)

	Anchor[#Anchor+1] = Icon

	return Icon
end

local function IconSet(Anchor, Num, Ability, Time, Name, ID, CD, Texture)
	local Icon = Anchor[Num] or IconCreate(Anchor)

	if ( Ability ) then
		-- 1: ID, 2: CD, 3: Status
		ID = Ability[1]
		CD = Ability[2]
		Icon.Status = Ability[3]
		Name = TPT.Default.SpellName[ID]
		Texture = GetSpellTexture(ID)
	end

	Icon.Texture:SetTexture(Texture)
	Icon.Name = Name
	Icon.ID = ID
	Icon.CD = CD
	Icon.GUID = Anchor.GUID

	if ( TPT.DB.Border ) then
		Icon.Texture:SetTexCoord(0, 1, 0, 1)
	else
		Icon.Texture:SetTexCoord(0.07, 0.9, 0.07, 0.90)
	end

	local StartTime = Active(Icon)
	if ( (StartTime and (Time - StartTime) < CD) ) then
		CooldownFrame_Set(Icon.Swipe, StartTime, CD, 1)
		Icon.Active = 1
	elseif ( Icon.Active ) then
		Stop(Icon)
	end

	return Icon, (Num + 1)
end

local function StopAllIcons(Anchor, Hide)
	for i=(Anchor or 1), (Anchor or #TPT.Anchors) do
		local Icons = TPT.Anchors[i]

		for k=1, #Icons do
			local Icon = Icons[k]

			if ( Hide ) then
				Icon:Hide()
			else
				Stop(Icon)
			end
		end
	end
end

--[[

	ANCHOR

]]

function TPT.Anchors.Lock()
	if ( TPT.DB.Lock ) then TPT.Anchors:Hide() else TPT.Anchors:Show() end
end

local function Attach(Anchor)
	local GUID = UnitGUID(Anchor.Unit)
	if ( not GUID ) then return end

	local Frame

	for i=1, (CRF and 40 or TPT.PARTY_NUM) do
		local AddOn

		if ( not AddOn ) then -- Grid-L
			AddOn = _G["Raid_Grid-LUnitButton"..i]
		end

		if ( not AddOn )  then -- ElvUI
			AddOn = _G["ElvUF_PartyGroup1UnitButton"..i]
		end

		if ( not AddOn )  then -- Tukui
			AddOn = _G["TukuiPartyUnitButton"..i]
		end

		if ( not AddOn )  then -- SUF
			AddOn = _G["SUFHeaderpartyUnitButton"..i]
		end

		if ( not AddOn )  then -- Grid
			AddOn = _G["Grid2LayoutHeader1UnitButton"..i]
		end

		if ( not AddOn ) then -- CUF/Blizz Party
			if ( CRF )  then
				AddOn = _G["CompactRaidFrame"..i]
			else
				AddOn = _G["PartyMemberFrame"..i]
			end
		end

		if ( AddOn ) then
			Frame = AddOn
		end

		if ( Frame and not Frame:IsForbidden() ) then
			if ( Frame.unit and UnitGUID(Frame.unit) == GUID ) then
				return Frame
			end
		end
	end
end

function TPT:AnchorUpdatePosition()
	if ( TPT.PARTY_NUM > 0 and TPT.ENABLED ) then
		for i=1, TPT.PARTY_NUM do
			local Anchor = TPT.Anchors[i]
			local Frame = (TPT.DB.Attach) and Attach(Anchor) or nil

			Anchor:ClearAllPoints()

			if ( Frame ) then
				local Relative
				if ( TPT.DB.Horiz ) then
					Relative = TPT.DB.Left and "BOTTOMRIGHT" or "BOTTOMLEFT"
				else	
					Relative = TPT.DB.Left and "TOPLEFT" or "TOPRIGHT"
				end
				Anchor:SetPoint(TPT.DB.Left and "BOTTOMLEFT" or "BOTTOMRIGHT", Frame, Relative, TPT.DB.OffX, TPT.DB.OffY)
			else
				local Point, X, Y
				if ( TPT.DB.Position[i] ) then
					local Scale = Anchor:GetEffectiveScale()
					X = TPT.DB.Position[i].X/Scale
					Y = TPT.DB.Position[i].Y/Scale
					Point = "TOPLEFT"
				else
					Point = "CENTER"
				end
				Anchor:SetPoint(Point, UIParent, Point, X, Y)
			end
		end
	end
end

local function AnchorPositionSave(i)
	local UIParentScale = UIParent:GetEffectiveScale()
	local UIParentTop = UIParent:GetTop()

	local Anchor = TPT.Anchors[i]

	if ( not TPT.DB.Position[i] ) then
		TPT.DB.Position[i] = {}
	end

	local Scale = Anchor:GetEffectiveScale()
	TPT.DB.Position[i].X = Anchor:GetLeft() * Scale 
	TPT.DB.Position[i].Y = (Anchor:GetTop() * Scale) - (UIParentTop * UIParentScale)
end

local function AnchorOnMouseDown(Self, Button)
	if ( not TPT.DB.Attach ) then
		Self:StartMoving()
	end
end

local function AnchorOnMouseUp(Self, Button)
	if ( not TPT.DB.Attach ) then
		Self:StopMovingOrSizing()
		AnchorPositionSave(Self.i)
	end
end

local function AnchorCreate()
	for i=1,4 do
		local Anchor = CreateFrame("Frame", nil, TPT.Anchors)
			Anchor:SetHeight(15)
			Anchor:SetWidth(15)
			Anchor:EnableMouse(true)
			Anchor:SetMovable(true)
			Anchor:Hide()

			Anchor:SetScript("OnMouseDown", AnchorOnMouseDown)
			Anchor:SetScript("OnMouseUp", AnchorOnMouseUp)

			Anchor.i = i
			Anchor.Unit = "party"..i

			TPT.Anchors[i] = Anchor

		local Index = Anchor:CreateFontString(nil, "ARTWORK", "GameFontNormal")
			Index:SetPoint("CENTER")
			Index:SetText(i)
	end
end

function TPT:AnchorUpdate(i)
	local Anchor = TPT.Anchors[i]
	local Unit = Anchor.Unit

	local _, Class = UnitClass(Unit)
	if ( not Class ) then return end

	local _, Race = UnitRace(Unit)

	local Icon
	local Num = 1
	local Time = GetTime()

	Anchor.GUID = UnitGUID(Unit)
	Anchor.Class = Class
	Anchor.Race = Race

	-- PvP Trinket
	local PvPTrinket = (Race == "Human") and TPT.Default.Trinket[2] or TPT.Default.Trinket[1]
	if ( TPT.DB.Trinket ) then
		local PvPTrinketIcon = (PLAYER_FACTION == "Alliance") and TRINKET_ALLIANCE or TRINKET_HORDE
		local TrinketID, TrinketCD, TrinketName = PvPTrinket[1], PvPTrinket[2], PvPTrinket[3]
		_, Num = IconSet(Anchor, Num, nil, Time, TrinketName, TrinketID, TrinketCD, PvPTrinketIcon)
	else
		Icon = Anchor[Num]
		if ( Icon and Icon.Name == PvPTrinket[3] ) then
			Stop(Icon)
			Icon.Name = nil
		end
	end

	-- Racial
	local Racial = TPT.Default.Racial[Race]
	if ( Racial ) then
		if ( TPT.DB.Racial ) then
			local RacialID, RacialCD, RacialName = Racial[1], Racial[2], Racial[3]
			_, Num = IconSet(Anchor, Num, nil, Time, RacialName, RacialID, RacialCD, GetSpellTexture(RacialID))
		else
			Icon = Anchor[Num]
			if ( Icon and Icon.ID == Racial[1] ) then
				Stop(Icon)
				Icon.Name = nil
			end
		end
	end

	-- All Spells
	for Index, AbilityInfo in pairs(TPT.DB.Spells[Class]) do
		local AbilityName = TPT.Default.SpellName[AbilityInfo[1]]
		local AbilityStatus = AbilityInfo[3]
		local AnchorSpec = Anchor.Spec

		if ( AbilityStatus ~= false and (AnchorSpec and AnchorSpec[AbilityName] or not TPT.Default.Spec[AbilityName]) ) then
			_, Num = IconSet(Anchor, Num, AbilityInfo, Time)
		end
	end

	-- Icon Overflow
	for i=Num,#Anchor do
		Icon = Anchor[i]
		Icon.Active = nil
		Icon.Name = nil
	end

	TPT:IconUpdate(i)
end

--[[

	TALENT

]]

local function InvalidSpecQuery()
	if InCombatLockdown() or 
	INSPECT_CURRENT or
	UnitIsDead("player") or
	(InspectFrame and InspectFrame:IsShown())
	then return 1 end
end

function TPT:QuerySpecStop()
	if ( QUERY_SPEC_TICK and not QUERY_SPEC_TICK:IsCancelled() ) then
		QUERY_SPEC_TICK_TIMEOUT = nil
		INSPECT_CURRENT = nil
		QUERY_SPEC_TICK:Cancel()
	end
end

local function QuerySpecInfo()
	if ( QUERY_SPEC_TICK_TIMEOUT and (QUERY_SPEC_TICK_TIMEOUT >= 5)  ) then -- 3*5 = 8
		TPT:QuerySpecStop()
	else
		QUERY_SPEC_TICK_TIMEOUT = (QUERY_SPEC_TICK_TIMEOUT or 0) + 1
	end

	if ( InvalidSpecQuery() ) then return end

	if not INSPECT_FRAME then
		INSPECT_FRAME = CreateFrame("Frame")
		INSPECT_FRAME:SetScript("OnEvent", function (self, event, ...)
			if ( (InCombatLockdown()) or (InspectFrame and InspectFrame:IsShown()) or (not INSPECT_CURRENT) ) then return end

			local anchor = TPT.Anchors[INSPECT_CURRENT]

			if ( not anchor or not anchor.Class ) then
				-- anchor not created
				INSPECT_CURRENT = nil
				return
			end

			anchor.Spec = {}
			local Found
			local TalentGroup = GetActiveTalentGroup(true)

			for Tab = 1, 3 do
				for Talent = 1, 31 do
					local Name, _, _, _, Spent = GetTalentInfo(Tab, Talent, true, false, TalentGroup)

					if ( Name ) then
						local Spent = Spent > 0

						if ( Spent ) then
							-- Feral Charge
							if ( Name == FERAL_CHARGE ) then
								anchor.Spec[FERAL_CHARGE_CAT] = 1
								Name = FERAL_CHARGE_BEAR
							end

							if ( TPT.Default.Spec[Name] ) then
								Found = true
								anchor.Spec[Name] = Spent
							end
						end
					end
				end
			end

			if ( not Found ) then
				anchor.Spec = nil
			else
				-- Update with new spec.
				TPT:AnchorUpdate(INSPECT_CURRENT)
			end

			if ( INSPECT_CURRENT == TPT.PARTY_NUM ) then
				TPT:QuerySpecStop()
			end

			ClearInspectPlayer()
			INSPECT_CURRENT = nil
			QUERY_SPEC_TICK_TIMEOUT = nil
		end)
		INSPECT_FRAME:RegisterEvent(INSPECT_READY)
	end

	if ( TPT.PARTY_NUM > 0 ) then
		for i=1, TPT.PARTY_NUM do
			local anchor = TPT.Anchors[i]
			if not anchor then return end

			local unit = anchor.Unit

			if ( not anchor.Spec ) then
				if ( UnitIsConnected(unit) ) then
					if ( CheckInteractDistance(unit, 1) ) then
						if ( CanInspect(unit) ) then
							INSPECT_CURRENT = i
							NotifyInspect(unit)
							break
						end
					end
				end
			end
		end
	else
		TPT:QuerySpecStop()
	end
end

function TPT:QuerySpecStart()
	if ( (QUERY_SPEC_TICK and QUERY_SPEC_TICK:IsCancelled()) or not QUERY_SPEC_TICK ) then
		QUERY_SPEC_TICK = Timer(3, QuerySpecInfo)
	end
end

--[[

	ZONE

]]

local function ValidZoneType()
	if (TPT.DB.Arena and CURRENT_ZONE_TYPE == "arena") or
	   (TPT.DB.Dungeon and CURRENT_ZONE_TYPE == "party") or
	   (TPT.DB.Raid and (CURRENT_ZONE_TYPE == "raid" or CURRENT_ZONE_TYPE == "pvp") ) or
	   (TPT.DB.World and CURRENT_ZONE_TYPE == "none")
	then
		return 1
	end
end

--[[

	GROUP

]]

local function GetUnitByGUID(GUID)
	for k,v in pairs(TPT.Default.Units) do
		if UnitGUID(k) == GUID then
			return k, v
		end
	end
end

local function GROUP_ROSTER_UPDATE_DELAY()
	local QuerySpec

	for i=1, 4 do
		local Anchor = TPT.Anchors[i]

		if ( Anchor ) then
			if ( i <= TPT.PARTY_NUM ) then
				local UnitGUID = UnitGUID(Anchor.Unit)

				if ( (UnitGUID and not Anchor.Spec and not INSPECT_CURRENT) or (Anchor.GUID ~= UnitGUID) ) then
					TPT:AnchorUpdate(i)
					QuerySpec = 1
				elseif ( not Anchor.Active ) then
					TPT:IconUpdate(i)
				end

				Anchor:Show()
				Anchor.Active = 1
			elseif ( Anchor.Active ) then
				Anchor:Hide()
				Anchor.Active = nil
				StopAllIcons(i, true)
			end
		else
			break
		end
	end

	if ( QuerySpec ) then
		-- Cleanse Stale GUIDs
		for GUID in pairs(GUID_ACTIVE) do
			if ( not GetUnitByGUID(GUID) ) then
				GUID_ACTIVE[GUID] = nil
			end
		end

		TPT:AnchorUpdatePosition()

		INSPECT_CURRENT = nil
		QUERY_SPEC_TICK_TIMEOUT = nil
		TPT:QuerySpecStart()
	end

	GROUP_ROSTER_UPDATE_DELAY_QUEUED = nil
end

function TPT:EnableCheck()
	if ( ValidZoneType() and TPT.PARTY_NUM > 0 ) then
		if ( not TPT.ENABLED ) then
			TPT.ENABLED = 1

			TPT.Icons:Show()
			TPT:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")

			if ( not TPT.DB.Lock ) then
				TPT.Anchors:Show()
			end
		end
	elseif ( TPT.ENABLED ) then
		TPT.ENABLED = nil

		TPT.Icons:Hide()
		TPT:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
		TPT:QuerySpecStop()

		TPT.Anchors:Hide()
	end
end

function TPT:GROUP_ROSTER_UPDATE(ZoneChanged)
	local GroupSize = GetNumGroupMembers()
	if ( IsInRaid() ) then
		GroupSize = GroupSize - 1
	end

	local TPT_PARTY_NUM_PREVIOUS = TPT.PARTY_NUM or 0
	TPT.PARTY_NUM = GroupSize > 4 and 4 or GroupSize

	local PartyChanged = TPT.PARTY_NUM ~= TPT_PARTY_NUM_PREVIOUS

	if ( PartyChanged or ZoneChanged ) then
		TPT:EnableCheck()
	end

	if ( ValidZoneType() ) then
		if ( PartyChanged or CURRENT_ZONE_TYPE ~= PREVIOUS_ZONE_TYPE ) then
			if ( not GROUP_ROSTER_UPDATE_DELAY_QUEUED ) then
				TimerAfter(1, GROUP_ROSTER_UPDATE_DELAY)
				GROUP_ROSTER_UPDATE_DELAY_QUEUED = 1
			end

			PREVIOUS_ZONE_TYPE = CURRENT_ZONE_TYPE
		end
	end
end

function TPT:PARTY_MEMBERS_CHANGED()
	TPT:GROUP_ROSTER_UPDATE()
end

local function OnLoad()
	if ( GetBuildInfo() == "3.3.5" ) then
		GROUP_ROSTER_UPDATE = "PARTY_MEMBERS_CHANGED"
		INSPECT_READY = "INSPECT_TALENT_READY"
	else
		GROUP_ROSTER_UPDATE = "GROUP_ROSTER_UPDATE"
		INSPECT_READY = "INSPECT_READY"
	end

	if (TPTDB and ( (TPTDB.V and TPT.Version ~= TPTDB.V) or not TPTDB.V) ) or not TPTDB then
		print("|cffFF4500/tpt")
		TPTDB = { Spells = TPT.Default.Spells, Position = {}, Scale = 1, OffY = 2, OffX = 5, SpaceX = 0, SpaceY = 0, Glow = 1, V = TPT.Version, Border = true, World = true, Arena = true, Trinket = true, Racial = true }
	end
	TPT.DB = TPTDB

	TPT:Locale()

	FERAL_CHARGE = GetSpellInfo(49377)
	FERAL_CHARGE_BEAR = GetSpellInfo(16979)
	FERAL_CHARGE_CAT = GetSpellInfo(49376)
	HEX = GetSpellInfo(51514)
	RACIAL_UNDEAD = GetSpellInfo(7744)
	TRINKET_ALLIANCE = GetItemIcon(18854)
	TRINKET_HORDE = GetItemIcon(18849)

	AnchorCreate()

	-- Init Options
	local _, AddonTitle = GetAddOnInfo(AddOn)
	local SO = LibStub("LibSimpleOptions-1.0")
	SO.AddOptionsPanel(AddonTitle, TPT.Options.Build)
	SO.AddSlashCommand(AddonTitle, "/tpt")

	TPT.Anchors:Lock()
	TPT.Icons:SetScale(TPT.DB.Scale or 1)
	TPT.Icons:Hide()
	TPT.Anchors:Hide()

	CRF = CompactRaidFrameContainer or CompactRaidFrameDB

	GUID_ACTIVE = {}

	TPT:RegisterEvent(GROUP_ROSTER_UPDATE)
end

function TPT:PLAYER_ENTERING_WORLD()
	if ( not PLAYER_FACTION ) then
		OnLoad()
	end

	PLAYER_FACTION = UnitFactionGroup("player")

	local _
	PREVIOUS_ZONE_TYPE = CURRENT_ZONE_TYPE
	_, CURRENT_ZONE_TYPE = IsInInstance()

	-- Zone changed, or init load.
	if ( PREVIOUS_ZONE_TYPE ~= CURRENT_ZONE_TYPE or TPT.PARTY_NUM == nil ) then
		TPT:QuerySpecStop()

		if ( CURRENT_ZONE_TYPE == "arena" ) then
			StopAllIcons()
		end

		TPT:GROUP_ROSTER_UPDATE(1)
	end
end

local function TriggerCooldown(SpellName, Anchor)
	for i=1,#Anchor do
		local Icon = Anchor[i]

		if ( Icon.Name == SpellName ) then
			Start(Anchor, Icon)
		else
			-- Undead Racial <-> PvP Trinket (45s)
			if ( Anchor.Race == "Scourge" ) then
				local Trinket = TPT.Default.Trinket[1][3]
				if ( (Icon.Name == RACIAL_UNDEAD and SpellName == Trinket) or (Icon.Name == Trinket and SpellName == RACIAL_UNDEAD) ) then
					if ( not Icon.Active ) then
						Start(Anchor, Icon, 45)
					end
				end
			end

			-- Grouped CD
			local GroupedClassSpells = TPT.Default.Shared[Anchor.Class]
			if ( GroupedClassSpells ) then
				local GroupedSpellType = GroupedClassSpells[SpellName]

				if ( GroupedSpellType ) then
					if ( GroupedSpellType == GroupedClassSpells[Icon.Name] ) then
						Start(Anchor, Icon)
					end
				end
			end

			-- Reset CD
			local Reset = TPT.Default.Reset[SpellName]
			if ( Reset ) then
				if ( Reset[Icon.Name] ) then
					Stop(Icon)
				end
			end
		end
	end
end

function TPT:COMBAT_LOG_EVENT_UNFILTERED(...)
	local _, Event, _, SourceGUID, _, _, _, DestGUID, _, _, _, SpellID, SpellName, _, SpellType = CombatLogGetCurrentEventInfo(...)

	local AuraEvent = (Event == "SPELL_AURA_REMOVED") or (Event == "SPELL_AURA_APPLIED")
	local CastEvent = (Event == "SPELL_CAST_SUCCESS")

	if ( CastEvent or AuraEvent ) then
		local Source, SourceID = GetUnitByGUID(SourceGUID)

		if ( Source ) then
			local Anchor = TPT.Anchors[SourceID]

			-- Classic: Buff fired BEFORE cast
			-- Whitelist: Hex
			if ( CastEvent or (Event == "SPELL_AURA_APPLIED" and SpellName == HEX) ) then
				TriggerCooldown(SpellName, Anchor)
			elseif ( SpellType == "BUFF" ) then
				if ( DestGUID == SourceGUID and TPT.DB.Glow ) then
					-- Blacklist: Berserk (Enchant), PvP Trinket
					if ( SpellID ~= 59620 and SpellID ~= 42292 ) then
						Glow(SpellName, Event, Anchor)
					end
				end
			end
		end
	end	
end

TPT:SetScript("OnEvent", function(Self, Event, ...)
	local Event = Self[Event]
	if ( Event ) then
		Event(Self, ...)
		end
	end)

TPT:RegisterEvent("PLAYER_ENTERING_WORLD")