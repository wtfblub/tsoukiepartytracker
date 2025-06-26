local AddOn, TPT, Private = select(2, ...):Init()

local _G = _G

local pairs = pairs
local GetTime = GetTime
local UIParent = UIParent
local UnitGUID = UnitGUID
local UnitRace = UnitRace
local IsInRaid = IsInRaid
local UnitBuff = UnitBuff
local UnitClass = UnitClass
local Timer = C_Timer.NewTicker
local GameTooltip = GameTooltip
local TimerAfter = C_Timer.After
local GetSpellInfo = GetSpellInfo
local IsInInstance = IsInInstance
local IsAddOnLoaded = IsAddOnLoaded
local GetSpellTexture = C_GetSpellTexture
local CooldownFrame_Set = CooldownFrame_Set
local GetNumGroupMembers = GetNumGroupMembers
local GetNumSubgroupMembers = GetNumSubgroupMembers
local ActionButton_ShowOverlayGlow = ActionButton_ShowOverlayGlow
local ActionButton_HideOverlayGlow = ActionButton_HideOverlayGlow

local ADDON_STATE

local ZONE_TYPE
local ZONE_TYPE_PREVIOUS

local GROUP_ID
local GROUP_TYPE
local GROUP_SUB_SIZE

local QUERY_SPEC

local GROUP_UPDATE_QUEUED

local UNIT_FRAME
local PLAYER_FACTION

local HEX
local GNAW
local FERAL_CHARGE
local MASTER_OF_GHOULS
local FERAL_CHARGE_CAT
local FERAL_CHARGE_BEAR

local RACIAL_UNDEAD
local TRINKET_HORDE
local TRINKET_ALLIANCE

TPT.Icons = CreateFrame("Frame", nil, UIParent)
TPT.Anchors = CreateFrame("Frame", nil, UIParent)

--[[

	GLOW

]]

local function GlowHide(Icon)
	if ( Icon.overlay ) then
		Icon.Swipe:SetAlpha(1)
		ActionButton_HideOverlayGlow(Icon)

		if ( TPT.DB.Fade ) then
			Icon.Texture:SetDesaturated(1)
		end
	end
end

local function Glow(SpellName, Event, Anchor)
	for i=1,#Anchor do
		local Icon = Anchor[i]

		if ( Icon.Name == SpellName ) then
			if ( Event == "SPELL_AURA_APPLIED" ) then
				local Name, _, _, _, _, Duration = UnitBuff(Anchor.Unit, SpellName)
				if ( not Name or Duration < 1.5 ) then
					return
				end

				ActionButton_ShowOverlayGlow(Icon)

				Icon.Swipe:SetAlpha(0)

				if ( TPT.DB.Fade ) then
					Icon.Texture:SetDesaturated(nil)
				end
			else
				GlowHide(Icon)
			end

			break
		end
	end
end

--[[

	COOLDOWN

]]

local function Stop(Icon)
	CooldownFrame_Set(Icon.Swipe, 0, 0, 0)
end

local function Start(Anchor, Icon, SetCD)
	if ( Icon.Name ) then
		CooldownFrame_Set(Icon.Swipe, GetTime(), SetCD or Icon.CD, 1)

		if ( TPT.DB.Glow and not SetCD ) then
			-- Flash
			ActionButton_ShowOverlayGlow(Icon)
			Icon.overlay.animIn:Stop()
			Icon.overlay.animOut:Play()
			Icon.overlay.ants.animOut:Stop()
			Icon.overlay.ants:Hide()
		end

		if ( TPT.DB.Hidden ) then
			TPT:IconUpdate(Anchor.i)
		else
			if ( TPT.DB.Fade ) then
				Icon.Texture:SetDesaturated(1)
			end
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

	for Index=1,#Anchor do
		local Icon = Anchor[Index]

		if ( Icon and Icon.Name and (not TPT.DB.Hidden or Icon.Swipe:IsShown()) ) then
			Icon:ClearAllPoints()

			if ( TPT.DB.Rows ) then
				if ( Count == 1 ) then
					Icon:SetPoint(TPT.DB.Left and "TOPRIGHT" or "TOPLEFT", Anchor, TPT.DB.Left and "BOTTOMLEFT" or "BOTTOMRIGHT", TPT.DB.Left and -1 * TPT.DB.SpaceX or TPT.DB.SpaceX, 0)
				elseif ( Count % 2 == 0 ) then
					Icon:SetPoint(TPT.DB.Left and "TOP" or "TOP", Anchor[LastIndex], TPT.DB.Left and "BOTTOM" or "BOTTOM", TPT.DB.Left and 0 or 0, -1 * TPT.DB.SpaceX )			
				else
					Icon:SetPoint(TPT.DB.Left and "BOTTOMRIGHT" or "BOTTOMLEFT", Anchor[LastIndex], TPT.DB.Left and "TOPLEFT" or "TOPRIGHT", TPT.DB.Left and -1 * TPT.DB.SpaceX or TPT.DB.SpaceX, TPT.DB.SpaceX)
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

local function CooldownOnHide(Self)
	local Icon = Self:GetParent()
	GlowHide(Icon)

	if ( TPT.DB.Hidden ) then
		if ( Icon.Anchor.Active ) then
			TPT:IconUpdate(Icon.Anchor.i)
		end
	elseif ( TPT.DB.Fade ) then
		Icon.Texture:SetDesaturated(nil)
	end
end

local function IconCreate(Anchor)
	local Icon = CreateFrame("Frame", nil, TPT.Icons)
	local Swipe = CreateFrame("Cooldown", nil, Icon, "CooldownFrameTemplate")
	Icon:SetSize(40,40)
	Icon.Swipe = Swipe
	Icon.Anchor = Anchor

	local Border = Icon:CreateTexture(nil, "BACKGROUND")
	Border:SetAllPoints(true)
	Border:SetColorTexture(0, 0, 0, 1)
	Border = 1.6

	local Texture = Icon:CreateTexture(nil, "ARTWORK")
	Texture:SetPoint("TOPLEFT", Icon, Border, -Border)
	Texture:SetPoint("BOTTOMRIGHT", Icon, -Border, Border)
	Texture:SetTexCoord(.07, .9, .07, .93)
	Icon.Texture = Texture

	Icon:EnableMouse()
	Swipe:HookScript("OnHide", CooldownOnHide)
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
	Icon.Texture:SetDesaturated(nil)
	Icon.Name = Name
	Icon.ID = ID
	Icon.CD = CD

	return Icon, (Num + 1)
end

local function StopAllIcons(Anchor, Hide)
	for i=(Anchor or 1), (Anchor or #TPT.Anchors) do
		local Icons = TPT.Anchors[i]

		for k=1,#Icons do
			local Icon = Icons[k]

			GlowHide(Icon)

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
	if ( TPT.DB.Lock or not ADDON_STATE ) then TPT.Anchors:Hide() else TPT.Anchors:Show() end
end

local function Attach(Anchor)
	local GUID = UnitGUID(Anchor.Unit)
	if ( GUID ) then
		local AddOn = UNIT_FRAME

		if ( UNIT_FRAME == "CompactRaidFrame" ) then
			if ( CompactRaidFrameManager_GetSetting("KeepGroupsTogether") ) then
				if ( GROUP_TYPE == "raid" ) then
					AddOn = "CompactRaidGroup1Member"
				else
					AddOn = "CompactPartyFrameMember"
				end
			end
		end

		for i=1, (UNIT_FRAME == "CompactRaidFrame" and 40 or GROUP_SUB_SIZE + 1) do
			local Frame = _G[AddOn..i]

			if ( Frame and not Frame:IsForbidden() ) then
				local Unit = Frame.unit or Frame.partyid
				if ( Unit and UnitGUID(Unit) == GUID ) then
					return Frame
				end
			end
		end
	end
end

function TPT:AnchorUpdatePosition(i)
	local Point, Relative, X, Y
	local Anchor = TPT.Anchors[i]
	local Parent = (TPT.DB.Attach) and Attach(Anchor)

	Anchor:ClearAllPoints()

	if ( Parent ) then
		if ( TPT.DB.Horiz ) then
			Relative = TPT.DB.Left and "BOTTOMRIGHT" or "BOTTOMLEFT"
		else	
			Relative = TPT.DB.Left and "TOPLEFT" or "TOPRIGHT"
		end

		Point = TPT.DB.Left and "BOTTOMLEFT" or "BOTTOMRIGHT"
		X = TPT.DB.OffX
		Y = TPT.DB.OffY
	else
		local Position = TPT.DB.Position[i]
		if ( Position ) then
			local Scale = Anchor:GetEffectiveScale()
			X = Position.X/Scale
			Y = Position.Y/Scale
			Point = "TOPLEFT"
		else
			Point = "CENTER"
		end

		Relative = Point
		Parent = UIParent
	end

	Anchor:SetPoint(Point, Parent, Relative, X, Y)
end

local function AnchorPositionSave(i)
	local UIParentScale = UIParent:GetEffectiveScale()
	local UIParentTop = UIParent:GetTop()

	local Anchor = TPT.Anchors[i]
	local Position = TPT.DB.Position[i]

	if ( not Position ) then
		Position = {}
		TPT.DB.Position[i] = Position
	end

	local Scale = Anchor:GetEffectiveScale()
	Position.X = Anchor:GetLeft() * Scale 
	Position.Y = (Anchor:GetTop() * Scale) - (UIParentTop * UIParentScale)
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

function AnchorCreate(i)
	local Anchor = CreateFrame("Frame", nil, TPT.Anchors)
		Anchor:SetSize(15, 15)
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
		Anchor.Text = Index

	return Anchor
end

function TPT:AnchorUpdate(i)
	local Anchor = TPT.Anchors[i]
	local Unit = Anchor.Unit
	local _, Class = UnitClass(Unit)

	if ( Class ) then
		local _, Race = UnitRace(Unit)

		local Num = 1
		local Time = GetTime()
		local Spec = Anchor.Spec

		Anchor.GUID = UnitGUID(Unit)
		Anchor.Class = Class
		Anchor.Race = Race

		-- PvP Trinket
		if ( TPT.DB.Trinket ) then
			local Trinket = (Race == "Human") and TPT.Default.Trinket[2] or TPT.Default.Trinket[1]
			local TrinketIcon = (PLAYER_FACTION == "Alliance") and TRINKET_ALLIANCE or TRINKET_HORDE
			local TrinketID, TrinketCD, TrinketName = Trinket[1], Trinket[2], Trinket[3]
			_, Num = IconSet(Anchor, Num, nil, Time, TrinketName, TrinketID, TrinketCD, TrinketIcon)
		end

		-- Racial
		if ( TPT.DB.Racial ) then
			local Racial = TPT.Default.Racial[Race]
			if ( Racial ) then
				local RacialID, RacialCD, RacialName = Racial[1], Racial[2], Racial[3]
				_, Num = IconSet(Anchor, Num, nil, Time, RacialName, RacialID, RacialCD, GetSpellTexture(RacialID))
			end
		end

		-- All Spells
		local All = TPT.DB.Spells[Class]
		for i=1,#All do
			local AbilityInfo = All[i]
			local AbilityName = TPT.Default.SpellName[AbilityInfo[1]]
			local AbilityStatus = AbilityInfo[3]

			if ( AbilityStatus ~= false and ((Spec and Spec[AbilityName]) or not TPT.Default.Spec[AbilityName]) ) then
				_, Num = IconSet(Anchor, Num, AbilityInfo, Time)
			end
		end

		-- Icon Overflow
		for i=Num,#Anchor do
			Anchor[i].Name = nil
		end

		TPT:IconUpdate(i)
	end
end

--[[

	GROUP

]]

local function GetUnitByGUID(GUID)
	for k,v in pairs(TPT.Default.Units) do
		if ( UnitGUID(k) == GUID ) then
			return k, v
		end
	end
end

local function AnchorShuffle(Anchor, GUID)
	local Index = Anchor.i
	local Anchors = TPT.Anchors

	for i=1,#Anchors do
		local Found = Anchors[i]

		if ( Found.GUID and Found.GUID == GUID and i ~= Index ) then
			local Unit = Found.Unit

			Anchors[Index] = Found
			Anchors[i] = Anchor

			Found.Unit = Anchor.Unit
			Anchor.Unit = Unit
			Found.i = Index
			Anchor.i = i
			Anchor.Active = Found.Active

			Found.Text:SetText(Index)
			Anchor.Text:SetText(i)

			return Found
		end
	end

	-- No shuffle, stop icons.
	if ( ZONE_TYPE ~= "arena" ) then
		StopAllIcons(Index)
	end
end

local function GroupUpdate(Delayed)
	if ( Delayed ~= false and UNIT_FRAME == "CompactRaidFrame" and TPT.DB.Attach and InCombatLockdown() ) then
		TPT:RegisterEvent("PLAYER_REGEN_ENABLED")
	else
		for i=1,4 do
			local Anchor = TPT.Anchors[i] or AnchorCreate(i)

			if ( i <= GROUP_SUB_SIZE ) then
				local UnitGUID = UnitGUID(Anchor.Unit)
				local UnitChange = Anchor.GUID ~= UnitGUID

				if ( UnitChange or not Anchor.Spec or not Anchor.Active or ZONE_TYPE_PREVIOUS ~= ZONE_TYPE ) then
					local Shuffle = (UnitChange) and AnchorShuffle(Anchor, UnitGUID)
					if ( Shuffle ) then
						Anchor = Shuffle
						UnitChange = nil
					end

					Anchor.Spec = nil

					if ( UnitChange ) then
						TPT:AnchorUpdate(i)
					elseif ( not Anchor.Active ) then
						TPT:IconUpdate(i)
					end

					TPT:QuerySpecStart()
					QUERY_SPEC.ID = nil
					QUERY_SPEC.TIMEOUT = nil
				end

				TPT:AnchorUpdatePosition(i)

				Anchor.Active = 1
				Anchor:Show()
			elseif ( Anchor.Active ) then
				Anchor.Active = nil
				StopAllIcons(i, true)
				Anchor:Hide()
			end
		end
	end

	GROUP_UPDATE_QUEUED = nil
	ZONE_TYPE_PREVIOUS = ZONE_TYPE
end

--[[

	TALENT

]]

local function QuerySpec()
	if ( InspectFrame and InspectFrame:IsShown() ) then
		QUERY_SPEC.TIMEOUT = nil
		return
	elseif ( QUERY_SPEC.TIMEOUT and QUERY_SPEC.TIMEOUT > 4 ) then
		return TPT:QuerySpecStop()
	else
		QUERY_SPEC.TIMEOUT = (QUERY_SPEC.TIMEOUT or 0) + 1
	end

	if ( not (QUERY_SPEC.ID or UnitIsDead("player")) ) then
		local Total = 0

		if ( GROUP_SUB_SIZE > 0 ) then
			for i=1, GROUP_SUB_SIZE do
				local Anchor = TPT.Anchors[i]
				if ( not Anchor ) then return end

				if ( Anchor.Spec ) then
					Total = Total + 1
				else
					local Unit = Anchor.Unit
					if ( Unit and UnitIsConnected(Unit) and CheckInteractDistance(Unit, 1) and CanInspect(Unit) ) then
						QUERY_SPEC.ID = i
						return NotifyInspect(Unit)
					end
				end
			end
		end

		if ( Total == GROUP_SUB_SIZE ) then
			TPT:QuerySpecStop()
		end
	end
end

function TPT:QuerySpecStart()
	if ( not QUERY_SPEC ) then
		QUERY_SPEC = Timer(1, QuerySpec)
		QuerySpec()
	end
end

function TPT:QuerySpecStop()
	if ( QUERY_SPEC ) then
		QUERY_SPEC:Cancel()
		ClearInspectPlayer()
		QUERY_SPEC = nil
	end
end

function TPT:INSPECT_READY(GUID)
	if ( ADDON_STATE ) then
		local UnitID, AnchorID = GetUnitByGUID(GUID)
		local Anchor = TPT.Anchors[AnchorID]

		if ( Anchor and Anchor.Active and not Anchor.Spec ) then
			local Talent, Found = {}

			for Tab = 1, 3 do
				for Index = 1, 31 do
					local Name, _, _, _, Spent = GetTalentInfo(Tab, Index, true)

					if ( Name ) then
						local Spent = Spent > 0

						if ( Spent ) then
							if ( Name == FERAL_CHARGE ) then
								Talent[FERAL_CHARGE_CAT] = 1
								Name = FERAL_CHARGE_BEAR
							elseif ( Name == MASTER_OF_GHOULS ) then
								Talent[GNAW] = 1
							end

							if ( TPT.Default.Spec[Name] ) then
								Found = true
								Talent[Name] = Spent
							end
						end
					end
				end
			end

			if ( Found ) then
				Anchor.Spec = Talent
				TPT:AnchorUpdate(AnchorID) -- Refresh

				if ( QUERY_SPEC and QUERY_SPEC.ID == AnchorID ) then
					QUERY_SPEC.ID = nil
					QUERY_SPEC.TIMEOUT = nil
					ClearInspectPlayer()
				end
			end
		end
	end
end

local function AddonEnabled()
	if ( GROUP_SUB_SIZE > 0 and ((TPT.DB.Arena and ZONE_TYPE == "arena") or (((TPT.DB.Dungeon and ZONE_TYPE == "party") or (TPT.DB.World and ZONE_TYPE == "none")) and GetNumGroupMembers() < 6)) ) then
		if ( not ADDON_STATE ) then
			ADDON_STATE = 1

			TPT.Icons:Show()
			TPT:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")

			if ( not TPT.DB.Lock ) then
				TPT.Anchors:Show()
			end
		end
	elseif ( ADDON_STATE ) then
		ADDON_STATE = nil

		TPT.Icons:Hide()
		TPT:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
		TPT:QuerySpecStop()

		GROUP_SUB_SIZE = 0
		GroupUpdate(false)
		TPT.Anchors:Hide()
	end

	return ADDON_STATE
end

function TPT:PLAYER_REGEN_ENABLED()
	GroupUpdate(false)
	TPT:UnregisterEvent("PLAYER_REGEN_ENABLED")
end

function TPT:GROUP_ROSTER_UPDATE(UpdateType)
	local GroupIDLast = GROUP_ID
	local GroupTypeLast = GROUP_TYPE
	local GroupSubSizeLast = GROUP_SUB_SIZE or 0

	GROUP_ID = UnitGUID("party1") -- Sub-Group Changes
	GROUP_TYPE = IsInRaid() and "raid" or "party" -- Group Type Converted
	GROUP_SUB_SIZE = GetNumSubgroupMembers() -- Sub-Group Size

	if ( GROUP_ID ~= GroupIDLast or GROUP_TYPE ~= GroupTypeLast or GROUP_SUB_SIZE ~= GroupSubSizeLast or UpdateType ) then
		if ( AddonEnabled() and not GROUP_UPDATE_QUEUED ) then
			if ( GROUP_SUB_SIZE < GroupSubSizeLast and ZONE_TYPE_PREVIOUS ~= "pvp" ) then
				GroupUpdate(false)
			else
				TimerAfter(.7, GroupUpdate)
				GROUP_UPDATE_QUEUED = 1
			end
		end
	end
end

local function UnitFrame()
	if ( IsAddOnLoaded("CompactRaidFrame") and CUF_CVar:GetCVarBool("useCompactPartyFrames") ) then
		UNIT_FRAME = "CompactRaidFrame"
		hooksecurefunc("CompactRaidFrameManagerDisplayFrameProfileSelector_OnClick", GroupUpdate)
	elseif ( IsAddOnLoaded("ElvUI") ) then
		UNIT_FRAME = "ElvUF_PartyGroup1UnitButton"
	elseif ( IsAddOnLoaded("ShadowedUnitFrames") ) then
		UNIT_FRAME = "SUFHeaderpartyUnitButton"
	elseif ( IsAddOnLoaded("XPerl") ) then
		UNIT_FRAME = "XPerl_party"
	elseif ( IsAddOnLoaded("PitBull4") ) then
		UNIT_FRAME = "PitBull4_Groups_PartyUnitButton"
	elseif ( IsAddOnLoaded("Grid2") ) then
		UNIT_FRAME = "Grid2LayoutHeader1UnitButton"
	else
		UNIT_FRAME = "PartyMemberFrame"
	end
end

local function OnLoad()
	TPT.Options()

	HEX = GetSpellInfo(51514)
	GNAW = GetSpellInfo(47481)
	FERAL_CHARGE = GetSpellInfo(49377)
	MASTER_OF_GHOULS = GetSpellInfo(52143)
	FERAL_CHARGE_CAT = GetSpellInfo(49376)
	FERAL_CHARGE_BEAR = GetSpellInfo(16979)

	TRINKET_HORDE = GetItemIcon(18849)
	RACIAL_UNDEAD = GetSpellInfo(7744)
	TRINKET_ALLIANCE = GetItemIcon(18854)

	UnitFrame()

	TPT.Anchors:Lock()
	TPT.Icons:SetScale(TPT.DB.Scale or 1)
	TPT.Icons:Hide()

	TPT:RegisterEvent("GROUP_ROSTER_UPDATE")
	TPT:RegisterEvent("INSPECT_READY")
end

function TPT:PLAYER_ENTERING_WORLD()
	if ( not PLAYER_FACTION ) then
		OnLoad()
	end

	PLAYER_FACTION = UnitFactionGroup("player")

	local _
	ZONE_TYPE_PREVIOUS = ZONE_TYPE
	_, ZONE_TYPE = IsInInstance()

	-- Zone changed, or init load.
	if ( ZONE_TYPE_PREVIOUS ~= ZONE_TYPE or GROUP_SUB_SIZE == nil ) then
		TPT:QuerySpecStop()

		if ( ZONE_TYPE == "arena" ) then
			StopAllIcons()
		end

		TPT:GROUP_ROSTER_UPDATE("Zone")
	end
end

local function TriggerCooldown(SpellName, Anchor)
	if ( not Anchor.Spec ) then
		TPT:QuerySpecStart()
	end

	for i=1,#Anchor do
		local Icon = Anchor[i]

		if ( Icon.Name == SpellName ) then
			Start(Anchor, Icon)
		elseif ( Icon.Name ) then
			-- Undead Racial <-> PvP Trinket (45s)
			if ( Anchor.Race == "Scourge" and FERAL_CHARGE ) then -- If WotLK
				local Trinket = TPT.Default.Trinket[1][3]
				if ( (Icon.Name == RACIAL_UNDEAD and SpellName == Trinket) or (Icon.Name == Trinket and SpellName == RACIAL_UNDEAD) ) then
					if ( not Icon.Swipe:IsShown() ) then
						Start(Anchor, Icon, 45)
					end
				end
			end

			-- Shared CD
			local SharedClassSpells = TPT.Default.Shared[Anchor.Class]
			if ( SharedClassSpells ) then
				local SharedSpellType = SharedClassSpells[SpellName]
				if ( SharedSpellType and SharedSpellType == SharedClassSpells[Icon.Name] and Icon.Swipe:GetCooldownDuration() < 1 ) then
					Start(Anchor, Icon, TPT.Default.Shared.CD[SpellName] or TPT.Default.Shared.CD_FALLBACK[Icon.Name] or TPT.Default.Shared.CD[Icon.Name])
				end
			end

			-- Reset CD
			local Reset = TPT.Default.Reset[SpellName]
			if ( Reset and Reset[Icon.Name] ) then
				Stop(Icon)
			end
		end
	end
end

function TPT:COMBAT_LOG_EVENT_UNFILTERED(...)
	local _, Event, _, SourceGUID, _, _, _, DestGUID, _, _, _, SpellID, SpellName, _, SpellType = CombatLogGetCurrentEventInfo(...)
	local CastEvent = (Event == "SPELL_CAST_SUCCESS") or ((Event == "SPELL_AURA_APPLIED" or Event == "SPELL_MISSED") and SpellName == HEX)

	if ( CastEvent or Event == "SPELL_AURA_REMOVED" or Event == "SPELL_AURA_APPLIED" ) then
		local Source, SourceID = GetUnitByGUID(SourceGUID)

		if ( Source ) then
			local Anchor = TPT.Anchors[SourceID]

			if ( Anchor and Anchor.Active ) then
				if ( CastEvent ) then
					TriggerCooldown(SpellName, Anchor)
				elseif ( SpellType == "BUFF" and DestGUID == Anchor.GUID and TPT.DB.Glow ) then
					if ( SpellID ~= 59620 ) then -- Blacklist: Berserk (Enchant)
						Glow(SpellName, Event, Anchor)
					end
				end
			end
		end
	end	
end

TPT:SetScript("OnEvent", function(Self, Event, ...)
	Event = Self[Event]
	if ( Event ) then
		Event(Self, ...)
	end
end)
TPT:RegisterEvent("PLAYER_ENTERING_WORLD")