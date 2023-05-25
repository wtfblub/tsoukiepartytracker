local V = 7.54

local addon, ATTdefault = ...

local match = string.match
local remove = table.remove
local insert = table.insert
local sort = table.sort
local tonumber = tonumber
local tostring = tostring
local GetSpellInfo = GetSpellInfo
local UnitClass = UnitClass
local UnitGUID = UnitGUID
local IsInInstance = IsInInstance
local UnitRace = UnitRace
local CooldownFrame_Set = CooldownFrame_Set
local Timer = C_Timer.NewTicker
local TimerAfter = C_Timer.After
local LOCALIZED_CLASS_NAMES_MALE = LOCALIZED_CLASS_NAMES_MALE
local UIParent = UIParent

local ENABLED

local CURRENT_ZONE_TYPE
local PREVIOUS_ZONE_TYPE

local PLAYER_FACTION

local PARTY_NUM
local PARTY_NUM_PREVIOUS

local __CRF = false

local db
local dbRacial = ATTdefault.dbRacial
local dbTrinket = ATTdefault.dbTrinket

local ATT = CreateFrame("Frame", "ATT", UIParent)
local ATTIcons = CreateFrame("Frame", nil, UIParent)
local ATTAnchor = CreateFrame("Frame", nil, UIParent)

local INSPECT_FRAME
local INSPECT_CURRENT
local QUERY_SPEC_TICK
local QUERY_SPEC_TICK_TIMEOUT
local GROUP_ROSTER_UPDATE_DELAY_QUEUED

local GROUP_ROSTER_UPDATE = "GROUP_ROSTER_UPDATE"
local INSPECT_READY = "INSPECT_READY"
local HEX
local FERAL_CHARGE
local FERAL_CHARGE_CAT
local FERAL_CHARGE_BEAR
local RACIAL_UNDEAD
local TRINKET_ALLIANCE
local TRINKET_HORDE

-- Compat
if ( GetBuildInfo() == "3.3.5" ) then
	GROUP_ROSTER_UPDATE = "PARTY_MEMBERS_CHANGED"
	INSPECT_READY = "INSPECT_TALENT_READY"
end

local anchors = {}
local activeGUIDS = {}

local validUnits = {
	["player"] = 5,
	["party1"] = 1,
	["party2"] = 2,
	["party3"] = 3,
	["party4"] = 4,
	["pet"] = 5,
	["partypet1"] = 1,
	["partypet2"] = 2,
	["partypet3"] = 3,
	["partypet4"] = 4,
}

local groupedCooldowns = {
	["DRUID"] = {
		[16979] = 1, -- Feral Charge - Bear
		[49376] = 1, -- Feral Charge - Cat
	},
	["SHAMAN"] = {
		[49231] = 1, -- Earth Shock
		[49233] = 1, -- Flame Shock
		[49236] = 1, -- Frost Shock
	},
	["HUNTER"] = {
		[60192] = 1, -- Freezing Arrow
		[14311] = 1, -- Freezing Trap
		[13809] = 1, -- Frost Trap
		[49067] = 2, -- Explosive Trap
		[49056] = 2, -- Immolation Trap
	},
	["MAGE"] = {
		[43010] = 1,  -- Fire Ward
		[43012] = 1,  -- Frost Ward
	},
	["WARRIOR"] = {
		[72] = 1, -- Shield Bash
		[6552] = 1, -- Pummel
	},
}

local cooldownResetters = {
	[11958] = { -- Cold Snap
		[42931] = 1, -- Cone of Cold
		[42917] = 1, -- Frost Nova
		[43012] = 1, -- Frost Ward
		[43039] = 1, -- Ice Barrier
		[45438] = 1, -- Ice Block
		[31687] = 1, -- Summon Water Elemental
		[44572] = 1, -- Deep Freeze
		[44545] = 1, -- Fingers of Frost
		[12472] = 1, -- Icy Veins
	},
	[14185] = { -- Preparation
		[14177] = 1, -- Cold Blood
		[26669] = 1, -- Evasion
		[11305] = 1, -- Sprint
		[26889] = 1, -- Vanish
		[36554] = 1, -- Shadowstep
		[1766] = 1, -- Kick
		[51722] = 1,-- Dismantle
	},
	[23989] = { -- Readiness
		[19503] = 1, -- Scatter Shot
		[60192] = 1, -- Freezing Arrow
		[13809] = 1, -- Frost Trap
		[14311] = 1, -- Freezing Trap
		[19574] = 1, -- Bestial Wrath
		[34490] = 1, -- Silencing Shot
		[19263] = 1, -- Deterrence
		[53271] = 1, -- Master's Call
		[49012] = 1, -- Wyvern Sting
	},
}

local function GetSpellTexture(id)
	local _, _, icon = GetSpellInfo(id)
	return icon
end

local function PrepareDefaultSpells()
	local Temp = {}

	for Class, Table in pairs(ATTdefault.defaultAbilities) do
		Temp[Class] = {}

		for Spec, Spells in pairs(Table) do
			Temp[Class][Spec] = {}

			for _, Spell in pairs(Spells) do
				local SpellID = Spell[1]
				local SpellName = GetSpellInfo(SpellID)

				if ( SpellName ) then
					Temp[Class][Spec][#Temp[Class][Spec]+1] = { ability = SpellName, cooldown = Spell[2], id = SpellID }
				end
			end
		end
	end

	return Temp
end

local function ConvertSpells(Table)
	local Temp = {}

	for Class, Spells in pairs(Table) do
		Temp[Class] = {}

		for Spell, Value in pairs(Spells) do
			local SpellName = GetSpellInfo(Spell)

			if ( SpellName ) then
				Temp[Class][SpellName] = Value
			end
		end
	end

	return Temp
end

local function ConvertReset(Table)
	local Temp = {}

	for Reset, Spells in pairs(cooldownResetters) do
		local ResetName = GetSpellInfo(Reset)

		if ( ResetName ) then
			Temp[ResetName] = {}

			for SpellID in pairs(Spells) do
				local SpellName = GetSpellInfo(SpellID)

				if ( SpellName ) then
					Temp[ResetName][SpellName] = 1
				end
			end
		end
	end

	return Temp
end

local function ConvertTrinket(Index)
	for i=1, #dbTrinket do
		local Trinket = dbTrinket[i]
		Trinket.ability = GetSpellInfo(Trinket.id)
	end
end

local function ValidZoneType()
	if (db.Arena and CURRENT_ZONE_TYPE == "arena") or
	   (db.Dungeon and CURRENT_ZONE_TYPE == "party") or
	   (db.Raid and (CURRENT_ZONE_TYPE == "raid" or CURRENT_ZONE_TYPE == "pvp") ) or
	   (db.World and CURRENT_ZONE_TYPE == "none")
	then
		return 1
	end
end

local function Lock()
	if ( db.Lock ) then ATTAnchor:Hide() else ATTAnchor:Show() end
end

-- Player Inspect
local function InvalidSpecQuery()
	if InCombatLockdown() or 
	INSPECT_CURRENT or
	UnitIsDead("player") or
	(InspectFrame and InspectFrame:IsShown())
	then return 1 end
end

local function QUERY_SPEC_STOP()
	if ( QUERY_SPEC_TICK and not QUERY_SPEC_TICK:IsCancelled() ) then
		QUERY_SPEC_TICK_TIMEOUT = nil
		INSPECT_CURRENT = nil
		QUERY_SPEC_TICK:Cancel()
	end
end

local function QUERY_SPEC_START()
	if ( (QUERY_SPEC_TICK and QUERY_SPEC_TICK:IsCancelled()) or not QUERY_SPEC_TICK ) then
		QUERY_SPEC_TICK = Timer(3, ATT.QuerySpecInfo)
	end
end

function ATT:QuerySpecInfo()
	if ( QUERY_SPEC_TICK_TIMEOUT and (QUERY_SPEC_TICK_TIMEOUT >= 5)  ) then -- 3*5 = 8
		QUERY_SPEC_STOP()
	else
		QUERY_SPEC_TICK_TIMEOUT = (QUERY_SPEC_TICK_TIMEOUT or 0) + 1
	end

	if ( InvalidSpecQuery() ) then return end

	if not INSPECT_FRAME then
		INSPECT_FRAME = CreateFrame("Frame")
		INSPECT_FRAME:SetScript("OnEvent", function (self, event, ...)
			if ( (InCombatLockdown()) or (InspectFrame and InspectFrame:IsShown()) or (not INSPECT_CURRENT) ) then return end

			local anchor = anchors[INSPECT_CURRENT]

			if ( not anchor or not anchor.class ) then
				-- anchor not yet created
				INSPECT_CURRENT = nil
				return
			end

			anchor.spec = {}
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
								anchor.spec[FERAL_CHARGE_CAT] = 1
								Name = FERAL_CHARGE_BEAR
							end

							for SpecID, SpellList in pairs(db.Spells[anchor.class]) do
								if ( SpecID ~= "*" ) then
									for Index, Spell in pairs(SpellList) do
										if ( Spell.ability == Name ) then
											Found = true
											anchor.spec[Name] = Spent
											break
										end
									end
								end
							end
						end
					end
				end
			end

			if ( not Found ) then
				anchor.spec = nil
			else
				-- Update with new spec.
				ATT:TrinketCheck("party"..INSPECT_CURRENT, INSPECT_CURRENT)
			end

			if ( INSPECT_CURRENT == PARTY_NUM ) then
				QUERY_SPEC_STOP()
			end

			ClearInspectPlayer()
			INSPECT_CURRENT = nil
			QUERY_SPEC_TICK_TIMEOUT = nil
		end)
		INSPECT_FRAME:RegisterEvent(INSPECT_READY)
	end

	if ( PARTY_NUM > 0 ) then
		for i=1, PARTY_NUM do
			local anchor = anchors[i]
			if not anchor then return end

			local unit = "party"..i

			if ( not anchor.spec ) then
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
		QUERY_SPEC_STOP()
	end
end

function ATT:SavePositions()
	local UIParentScale = UIParent:GetEffectiveScale()
	local UIParentTop = UIParent:GetTop()

	for i=1,PARTY_NUM do
		local anchor = anchors[i]

		if ( not db.Position[i] ) then
			db.Position[i] = {}
		end

		local Scale = anchor:GetEffectiveScale()
		db.Position[i].X = anchor:GetLeft() * Scale 
		db.Position[i].Y = (anchor:GetTop() * Scale) - (UIParentTop * UIParentScale)
	end
end

local function HideGlow(Icon)
	if ( Icon.glow and Icon.glow.SetScript ) then
		Icon.cd:SetAlpha(1)
		Icon.glow:Hide()
		Icon.glow:SetScript("OnUpdate", nil)
		Icon.glow.SetScript = nil
	end
end

-- Disable all this in a bigger raid.
function ATT:FindCompactRaidFrameByUnit(Unit)
	local UnitIDGUID = UnitGUID(Unit)

	if ( not Unit or not UnitIDGUID ) then return end

	local Frame

	for i=1, (__CRF and 40 or PARTY_NUM) do
		local Frame
		local AddOn

		-- Grid-L
		if ( not AddOn ) then
			AddOn = _G["Raid_Grid-LUnitButton"..i]
		end

		-- ElvUI
		if ( not AddOn )  then
			AddOn = _G["ElvUF_PartyGroup1UnitButton"..i]
		end

		-- Tukui
		if ( not AddOn )  then
			AddOn = _G["TukuiPartyUnitButton"..i]
		end

		-- SUF
		if ( not AddOn )  then
			AddOn = _G["SUFHeaderpartyUnitButton"..i]
		end

		-- Grid
		if ( not AddOn )  then
			AddOn = _G["Grid2LayoutHeader1UnitButton"..i]
		end

		-- CUF/Blizz Party
		if ( not AddOn ) then
			if ( __CRF )  then
				AddOn = _G["CompactRaidFrame"..i]
			else
				AddOn = _G["PartyMemberFrame"..i]
			end
		end

		if ( AddOn ) then
			Frame = AddOn
		end

		if ( Frame and not Frame:IsForbidden() ) then
			if ( Frame.unit and UnitGUID(Frame.unit) == UnitIDGUID ) then
				return Frame
			end
		end
	end
end

function ATT:LoadPositions()
	if ( PARTY_NUM > 0 and ENABLED ) then
		for i=1, PARTY_NUM do
			local anchor = anchors[i]

			anchor:ClearAllPoints() -- COMPAT

			local frame
			if ( db.Attach ) then
				frame = ATT:FindCompactRaidFrameByUnit("party"..i)
			end

			if ( frame ) then	
				if ( db.Horiz ) then 	
					anchor:SetPoint(db.Left and "BOTTOMLEFT" or "BOTTOMRIGHT", frame, db.Left and "BOTTOMRIGHT" or "BOTTOMLEFT", db.OffX, db.OffY)
				else	
					anchor:SetPoint(db.Left and "BOTTOMLEFT" or "BOTTOMRIGHT", frame, db.Left and "TOPLEFT" or "TOPRIGHT", db.OffX, db.OffY)
				end
			else
				if ( db.Position[i] ) then	
					local X = db.Position[i].X	
					local Y = db.Position[i].Y	
					local Scale = anchor:GetEffectiveScale()
					anchor:SetPoint("TOPLEFT", UIParent,"TOPLEFT", X/Scale, Y/Scale)
				else	
					anchor:SetPoint("CENTER", UIParent, "CENTER")
				end
			end
		end
	end
end

function ATT:CreateAnchors()
	for i=1,4 do
		local anchor = CreateFrame("Frame","ATTAnchor"..i , ATTAnchor)
			anchor:SetHeight(15)
			anchor:SetWidth(15)
			anchor:EnableMouse(true)
			anchor:SetMovable(true)
			anchor:Show()
			anchor.icons = {}
			anchor.spells = {}
			anchor.HideIcons = function() local icons = anchor.icons for i=1,#icons do local icon = icons[i] icon:Hide() icon.inUse = nil end end
			anchor:SetScript("OnMouseDown",function(self,button) if button == "LeftButton" and not db.Attach then self:StartMoving() end end)
			anchor:SetScript("OnMouseUp",function(self,button) if button == "LeftButton" and not db.Attach then self:StopMovingOrSizing() ATT:SavePositions() end end)
			anchor:Hide()
			anchors[i] = anchor
			anchor.i = i

		local index = anchor:CreateFontString(nil,"ARTWORK","GameFontNormal")
			index:SetPoint("CENTER")
			index:SetText(i)
	end
end

local function CreateIcon(anchor)
	local icon = CreateFrame("Frame",anchor:GetName().."Icon".. (#anchor.icons+1),ATTIcons,"ActionButtonTemplate")
	icon:SetSize(40,40) 	
	local cd = CreateFrame("Cooldown",icon:GetName().."Cooldown",icon,"CooldownFrameTemplate")
	icon.cd = cd
	icon.Start = function(sentCD)
		if ( icon.inUse ) then
			icon.starttime = GetTime()
			CooldownFrame_Set(cd, icon.starttime, sentCD or icon.cooldown, 1)

			if ( db.Glow ) then
				if ( not icon.flash ) then
					icon.flash = CreateFrame("Frame", nil, icon, "TGlowFlash")
				end
				icon.flash.D:Play()
			end

			if ( icon.inUse ) then
				icon:Show()
				icon.active = true
			end
			activeGUIDS[icon.GUID] = activeGUIDS[icon.GUID] or {}
			activeGUIDS[icon.GUID][icon.ability] = activeGUIDS[icon.GUID][icon.ability] or {}
			activeGUIDS[icon.GUID][icon.ability].starttime = icon.starttime
			activeGUIDS[icon.GUID][icon.ability].cooldown =  icon.cooldown

			if ( db.Hidden ) then
				ATT:ToggleIconDisplay(anchor.i)
			end
		end
	end
	icon.Stop = function()
		CooldownFrame_Set(cd, 0, 0, 0)
		icon.starttime = 0
		activeGUIDS[icon.GUID] = activeGUIDS[icon.GUID] or {}	
		if activeGUIDS[icon.GUID][icon.ability] then
			activeGUIDS[icon.GUID][icon.ability] = {}	
			activeGUIDS[icon.GUID][icon.ability].starttime = 0
			activeGUIDS[icon.GUID][icon.ability].cooldown =  0
		end
	end

	icon.SetTimer = function(starttime,cooldown)
		if starttime and cooldown then
			CooldownFrame_Set(cd,starttime,cooldown,1)
			icon.active = true	
			icon.starttime = starttime	
			icon.cooldown = cooldown	
		end
	end
	local texture = icon:CreateTexture(nil,"ARTWORK")
	texture:SetAllPoints(true)
	icon.texture = texture

	cd:HookScript("OnHide",function()
		icon.active = nil

		HideGlow(icon)

		if ( db.Hidden ) then
			ATT:ToggleIconDisplay(anchor.i)
		end
	end)

	ATT:ApplyIconTextureBorder(icon)

	-- Tooltips
	icon:EnableMouse()
	icon:SetScript('OnEnter', function()
		if ( db.Tooltip and icon.abilityID ) then
			GameTooltip:SetOwner(ATT, "ANCHOR_CURSOR")
			GameTooltip:SetHyperlink("spell:"..icon.abilityID)
		end
	end)
	icon:SetScript('OnLeave', function()
		if ( db.Tooltip and icon.abilityID ) then
			GameTooltip:Hide()
		end
	end)
	return icon
end

function ATT:AddIcon(icons,anchor)
	local newicon = CreateIcon(anchor)
	icons[#icons+1] = newicon

	return newicon
end

function ATT:ApplyIconTextureBorder(icon)
	if ( db.Border ) then
		icon.texture:SetTexCoord(0,1,0,1)
	else
		icon.texture:SetTexCoord(0.07,0.9,0.07,0.90)
	end
end
	
function ATT:ToggleAnchorDisplay()
	for i=1, 4 do
		local anchor = anchors[i]

		if ( anchor ) then
			local PartyMemberExist = UnitInParty("party"..i)

			if ( not PartyMemberExist ) then
				local Icons = anchor.icons
				local IconsNum = #Icons

				if ( IconsNum > 0 ) then
					for j=1, IconsNum do	
						Icons[j].ability = nil	
						Icons[j].seen = nil	
						Icons[j].active = nil	
						Icons[j].inUse = nil	
						Icons[j].showing = nil	
					end

					anchor.spells = {}
					anchor:HideIcons()
				end

				anchor:Hide()
			else
				anchor:Show()
			end
		end
	end
end

local function UpdateAnchorAdd(numIcons, anchor, abilityTable)
	insert(anchor.spells, abilityTable)

	local icon = ATT:UpdateAnchorIcon(anchor, numIcons, abilityTable)
	activeGUIDS[icon.GUID] = activeGUIDS[icon.GUID] or {}
	if activeGUIDS[icon.GUID][icon.ability] then
		icon.SetTimer(activeGUIDS[icon.GUID][icon.ability].starttime,activeGUIDS[icon.GUID][icon.ability].cooldown)
	else
		icon.Stop()
	end

	return numIcons + 1
end

function ATT:UpdateAnchor(unit, i, PvPTrinket, TraceID, tcooldown)
	if not self:IsShown() then return end

	local _, class = UnitClass(unit)
	local guid = UnitGUID(unit)

	if not class or not guid then return end

	local _, race = UnitRace(unit)

	local anchor = anchors[i]	
	anchor.GUID = guid	
	anchor.class = class
	anchor.race = race
	local icons = anchor.icons
	local numIcons = 1

	-- PvP Trinket
	if ( db.Trinket ) then 
		local ability, id, cooldown = PvPTrinket.ability, PvPTrinket.id, PvPTrinket.cooldown
		local icon = icons[numIcons] or self:AddIcon(icons,anchor)
		icon.texture:SetTexture(TraceID)
		icon.GUID = anchor.GUID
		icon.ability = ability
		icon.abilityID = id
		icon.cooldown = cooldown
		icon.inUse = true
		icon.spec = nil
		ATT:ApplyIconTextureBorder(icon)

		activeGUIDS[icon.GUID] = activeGUIDS[icon.GUID] or {}
		if activeGUIDS[icon.GUID][icon.ability] then
			icon.SetTimer(activeGUIDS[icon.GUID][ability].starttime,activeGUIDS[icon.GUID][ability].cooldown)
		else
			icon.Stop()
		end
		numIcons = numIcons + 1
	elseif icons[1] and (icons[1].ability == dbTrinket[1].ability or icons[1].ability == dbTrinket[2].ability) then
		icons[1]:Hide()
		icons[1].showing = nil
		icons[1].inUse = nil
		icons[1].spec = nil
		remove(icons, 1) 
	end 

	-- Racials
	if ( db.Racial ) then
		local Racial = dbRacial[race]

		if ( Racial ) then
			local RacialID = Racial[1]
			local RacialCD = Racial[2]
			local RacialName = GetSpellInfo(RacialID)

			local Icon = icons[numIcons] or self:AddIcon(icons, anchor)
			local texture = self:FindAbilityIcon(RacialName, RacialID)
			Icon.texture:SetTexture(texture)

			Icon.GUID = anchor.GUID
			Icon.ability = RacialName
			Icon.abilityID = RacialID
			Icon.cooldown = RacialCD
			Icon.inUse = true
			ATT:ApplyIconTextureBorder(Icon)

			activeGUIDS[Icon.GUID] = activeGUIDS[Icon.GUID] or {}
			if ( activeGUIDS[Icon.GUID][Icon.ability] ) then
				local ActiveGUID = activeGUIDS[Icon.GUID][RacialName]
				Icon.SetTimer(ActiveGUID.starttime, ActiveGUID.cooldown)
			else
				Icon.Stop()
			end

			numIcons = numIcons + 1
		end
	end

	-- All Spells
	for abilityIndex, abilityTable in pairs(db.Spells[class]["*"]) do
		if ( abilityTable.spellStatus ~= false ) then
			numIcons = UpdateAnchorAdd(numIcons, anchor, abilityTable)
		end
	end

	-- Spec Spells
	if ( anchor.spec ) then
		for specID, abilitiesTable in pairs(db.Spells[class]) do
			if ( specID ~= "*" ) then
				for abilityIndex, abilityTable in pairs(abilitiesTable) do
					if ( abilityTable.spellStatus ~= false and anchor.spec[abilityTable.ability] ) then
						numIcons = UpdateAnchorAdd(numIcons, anchor, abilityTable)
					end
				end
			end
		end
	end

	-- Icon Overflow
	for j=numIcons,#icons do
		icons[j].seen = nil
		icons[j].active = nil
		icons[j].inUse = nil
		icons[j].showing = nil
	end
	self:ToggleIconDisplay(i)
end

function ATT:UpdateAnchorIcon(anchor, numIcons, abilityTable)
	local icons = anchor.icons
	local ability, id, cooldown, spellStatus = abilityTable.ability, abilityTable.id, abilityTable.cooldown, abilityTable.spellStatus
	local icon = icons[numIcons] or self:AddIcon(icons,anchor)
	local texture = self:FindAbilityIcon(ability, id)
	if texture then
		icon.texture:SetTexture(texture)
	end
	icon.GUID = anchor.GUID
	icon.ability = ability
	icon.abilityID = id
	icon.cooldown = cooldown
	icon.shouldShow = true
	icon.inUse = true
	icon.spellStatus = spellStatus

	ATT:ApplyIconTextureBorder(icon)

	return icon
end

-- responsible for actual anchoring of icons
function ATT:ToggleIconDisplay(i)
	local anchor = anchors[i]
	local icons = anchor.icons
	local count = 1
	local lastActiveIndex = 0

	-- hiding all icons before anchoring and deciding whether to show them
	for k, icon in pairs(icons) do
		if icon and icon.ability and icon.inUse then	
			if icon.spec then	
				icon.showing = (not db.Hidden and icon.seen) or (db.Hidden and activeGUIDS[icon.GUID][icon.ability] and icon.active)
			else	
				icon.showing = (activeGUIDS[icon.GUID] and activeGUIDS[icon.GUID][icon.ability] and icon.active) or (not db.Hidden)
			end
		end
		icon:ClearAllPoints()

		if icon and icon.ability and icon.showing then	
			if db.Rows then
				if count == 1 then 	
					icon:SetPoint(db.Left and "TOPRIGHT" or "TOPLEFT", anchor, db.Left and "BOTTOMLEFT" or "BOTTOMRIGHT", db.Left and -1 * db.SpaceX or db.SpaceX, 0)
				elseif  (count % 2 == 0 )  then				
					icon:SetPoint(db.Left and "TOP" or "TOP", icons[lastActiveIndex], db.Left and "BOTTOM" or "BOTTOM", db.Left and 0 or 0, -1 * db.SpaceY )			
				else		
					icon:SetPoint(db.Left and "BOTTOMRIGHT" or "BOTTOMLEFT", icons[lastActiveIndex], db.Left and "TOPLEFT" or "TOPRIGHT", db.Left and -1 * db.SpaceX  or db.SpaceX, db.SpaceY)
				end	
			else
				if count == 1  then	
					icon:SetPoint(db.Left and "TOPRIGHT" or "TOPLEFT", anchor, db.Left and "BOTTOMLEFT" or "BOTTOMRIGHT", db.Left and -1 * db.SpaceX or db.SpaceX, 0)
				else	
					icon:SetPoint(db.Left and "RIGHT" or "LEFT", icons[lastActiveIndex], db.Left and "LEFT" or "RIGHT", db.Left and -1 * db.SpaceX or db.SpaceX, 0)
				end
			end

			lastActiveIndex = k	
			count = count + 1	
			icon:Show()
		else
			icon:Hide()
		end
	end

	self:ToggleAnchorDisplay() 	
end

function ATT:TrinketCheck(Unit, i)
	local Trinket = dbTrinket[1]
	local Icon

	if ( PLAYER_FACTION == "Alliance" ) then
		local _, Race = UnitRace(Unit)
		if ( Race == "Human" ) then
			Trinket = dbTrinket[2]
		end

		Icon = TRINKET_ALLIANCE
	else
		Icon = TRINKET_HORDE
	end

	self:UpdateAnchor(Unit, i, Trinket, Icon)  
end

function ATT:UpdateAllAnchors()
	if ( PARTY_NUM > 0 and ENABLED ) then
		for i=1, PARTY_NUM do
			local Unit = "party"..i
			local _, Class = UnitClass(Unit)

			if ( not Class ) then break end
			if ( not anchors[i] ) then break end

			self:TrinketCheck(Unit, i) 
		end
	end

	self:LoadPositions()
end

function ATT:UpdateAllAnchorIcons()
	if ( PARTY_NUM > 0 and ENABLED ) then
		for i=1, PARTY_NUM do
			ATT:ToggleIconDisplay(i)
		end
	end
end

local function GROUP_ROSTER_UPDATE_DELAY()
	ATT:UpdateAllAnchors()
	QUERY_SPEC_START()
	GROUP_ROSTER_UPDATE_DELAY_QUEUED = nil
end

function ATT:GROUP_ROSTER_UPDATE(Load)
	local GroupSize = GetNumGroupMembers()
	if ( IsInRaid() ) then
		GroupSize = GroupSize - 1
	end

	PARTY_NUM_PREVIOUS = PARTY_NUM or 0
	PARTY_NUM = GroupSize > 4 and 4 or GroupSize

	local PartyChanged = PARTY_NUM ~= PARTY_NUM_PREVIOUS

	if ( PartyChanged or Load ) then
		self:ApplySettings()
	end

	if ( ENABLED and ValidZoneType() ) then
		-- Our party has changed size, lets re-check spec.
		-- 3.3.5: This fires when we leave group, idk how to avoid.
		if ( PARTY_NUM > 0 and (PartyChanged or CURRENT_ZONE_TYPE ~= PREVIOUS_ZONE_TYPE) ) then -- Dynamic updating.
			for i=1, PARTY_NUM do
				local anchor = anchors[i]

				if ( anchor ) then
					anchor.spec = nil
				else
					break
				end
			end

			INSPECT_CURRENT = nil
			QUERY_SPEC_TICK_TIMEOUT = nil

			if ( not GROUP_ROSTER_UPDATE_DELAY_QUEUED ) then
				TimerAfter(1.1, GROUP_ROSTER_UPDATE_DELAY)
				GROUP_ROSTER_UPDATE_DELAY_QUEUED = 1
			end
		end
	end
end

function ATT:PARTY_MEMBERS_CHANGED()
	ATT:GROUP_ROSTER_UPDATE()
end

function ATT:PLAYER_ENTERING_WORLD()
	-- Player faction, cause merc on Warmane.
	PLAYER_FACTION = UnitFactionGroup("player")

	local _
	PREVIOUS_ZONE_TYPE = CURRENT_ZONE_TYPE
	_, CURRENT_ZONE_TYPE = IsInInstance()

	-- Check if we have the CRF addon.
	if ( __CRF == false ) then
		__CRF = CompactRaidFrameContainer or CompactRaidFrameDB
	end

	-- Zone changed, or init load.
	if ( PREVIOUS_ZONE_TYPE ~= CURRENT_ZONE_TYPE or PARTY_NUM == nil ) then
		QUERY_SPEC_STOP()

		if ( CURRENT_ZONE_TYPE == "arena" ) then
			self:StopAllIcons()
		end

		ATT:GROUP_ROSTER_UPDATE(1)
	end
end

function ATT:FindAbilityByName(abilities, name)
	if abilities then
		for i, v in pairs(abilities) do
			if v and v.ability and v.ability == name then return v, i end
		end
	end
end

function ATT:FindAbilityByID(abilities, id)
	if abilities then
		for i, v in pairs(abilities) do
			if v and v.id and v.id == id then return v, i end
		end
	end
end

function ATT:GetUnitByGUID(guid)
	for k,v in pairs(validUnits) do
		if UnitGUID(k) == guid then
			return k, v
		end
	end
end

function ATT:ValidUnit(unit)
	if ( validUnits[unit] ) then
		return unit
	end
end

local function AnimateTexCoords_OnUpdate(Self, Elapsed)
	AnimateTexCoords(Self.A, 256, 256, 48, 48, 22, Elapsed, 0.03)
end

function ATT:HandleGlow(SpellName, Event, Anchor)
	for i=1,#Anchor.icons do
		local Icon = Anchor.icons[i]

		if ( Icon.ability == SpellName ) then
			if ( Event == "SPELL_AURA_APPLIED" ) then
				if ( not Icon.glow ) then
					Icon.glow = CreateFrame("Frame", nil, Icon, "TGlow")
				end

				Icon.cd:SetAlpha(0)
				Icon.glow:SetScript("OnUpdate", AnimateTexCoords_OnUpdate)
				Icon.glow:Show()
			else
				HideGlow(Icon)

				if ( Icon.flash ) then
					Icon.flash.D:Play()
				end
			end

			break
		end
	end
end

function ATT:StartCooldown(SpellName, Anchor)
	for i=1,#Anchor.icons do
		local Icon = Anchor.icons[i]

		if ( Icon.ability == SpellName ) then
			Icon.seen = true
			Icon.Start()
		else
			-- Undead Racial <-> PvP Trinket (45s)
			if ( Anchor.race == "Scourge" ) then
				local Trinket = dbTrinket[1].ability
				if ( (Icon.ability == RACIAL_UNDEAD and SpellName == Trinket) or (Icon.ability == Trinket and SpellName == RACIAL_UNDEAD) ) then
					if ( not Icon.active ) then
						Icon.Start(45)
					end
				end
			end

			-- Grouped CD
			local GroupedClassSpells = groupedCooldowns[Anchor.class]
			if ( GroupedClassSpells ) then
				local GroupedSpellType = GroupedClassSpells[SpellName]

				if ( GroupedSpellType ) then
					if ( GroupedSpellType == GroupedClassSpells[Icon.ability] ) then
						Icon.Start()
					end
				end
			end

			-- Reset CD
			local Reset = cooldownResetters[SpellName]
			if ( Reset ) then
				if ( Reset[Icon.ability] ) then
					Icon.Stop()
				end
			end
		end
	end
end

function ATT:COMBAT_LOG_EVENT_UNFILTERED(...)
	local _, Event, _, SourceGUID, _, _, _, DestGUID, _, _, _, SpellID, SpellName, _, SpellType = CombatLogGetCurrentEventInfo(...)

	local AuraEvent = (Event == "SPELL_AURA_REMOVED") or (Event == "SPELL_AURA_APPLIED")
	local CastEvent = (Event == "SPELL_CAST_SUCCESS")

	if ( CastEvent or AuraEvent ) then
		local Source, SourceID = self:GetUnitByGUID(SourceGUID)

		if ( Source ) then
			if ( SourceID < 5 ) then
				local Anchor = anchors[SourceID]

				-- Classic: Buff is fired BEFORE cast event. Makes no sense, I know.
				-- Whitelist: Hex
				if ( CastEvent or (Event == "SPELL_AURA_APPLIED" and SpellName == HEX) ) then
					self:StartCooldown(SpellName, Anchor)
				elseif ( SpellType == "BUFF" ) then
					if ( DestGUID == SourceGUID and db.Glow ) then
						-- Blacklist: Berserk (Enchant), PvP Trinket
						if ( SpellID ~= 59620 and SpellID ~= 59752 ) then
							self:HandleGlow(SpellName, Event, Anchor)
						end
					end
				end
			end
		end
	end	
end

function ATT:ApplySettings()
	if ( ValidZoneType() and PARTY_NUM > 0 ) then
		if ( not ENABLED ) then
			ATTIcons:Show()
			self:Show()
			self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
			ENABLED = 1

			if ( not db.Lock ) then
				ATTAnchor:Show()
			end
		end
	elseif ( ENABLED ) then
		if ( PARTY_NUM == 0 ) then
			self:StopAllIcons()
		end

		ATTIcons:Hide()
		self:Hide()
		self:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
		QUERY_SPEC_STOP()
		ENABLED = nil

		ATTAnchor:Hide()
	end
end

function ATT:StopAllIcons()
	local Anchors = #anchors
	for i=1, Anchors do
		local Icons = anchors[i].icons

		for k=1, #Icons do
			local Icon = Icons[k]
			Icon.Stop()
			Icon.seen = nil
		end
	end

	wipe(activeGUIDS)
end

local function ATT_OnLoad(self)
	self:RegisterEvent("PLAYER_ENTERING_WORLD")
	self:RegisterEvent(GROUP_ROSTER_UPDATE)
	self:SetScript("OnEvent", function(self,event, ...) if self[event] then self[event](self, ...) end end)

	groupedCooldowns = ConvertSpells(groupedCooldowns)
	cooldownResetters = ConvertReset(cooldownResetters)
	ConvertTrinket()

	if (TPTDB and ( (TPTDB.V and V > TPTDB.V) or not TPTDB.V) ) or not TPTDB then
		print("|cffFF4500/tpt")
		TPTDB = { Spells = PrepareDefaultSpells(), Position = {}, Scale = 1, OffY = 2, OffX = 5, SpaceX = 0, SpaceY = 0, Glow = 1, V = V, Border = true, World = true, Arena = true, Trinket = true, Racial = true }
	end
	db = TPTDB

	ATTdefault.defaultAbilities = nil

	FERAL_CHARGE = GetSpellInfo(49377)
	FERAL_CHARGE_BEAR = GetSpellInfo(16979)
	FERAL_CHARGE_CAT = GetSpellInfo(49376)
	HEX = GetSpellInfo(51514)
	RACIAL_UNDEAD = GetSpellInfo(7744)
	TRINKET_ALLIANCE = GetItemIcon(18854)
	TRINKET_HORDE = GetItemIcon(18849)

	self:CreateAnchors()

	-- Init Options
	local _, AddonTitle = GetAddOnInfo(addon)
	local SO = LibStub("LibSimpleOptions-1.0")
	SO.AddOptionsPanel(AddonTitle, self.BuildOptions)
	SO.AddSlashCommand(AddonTitle, "/tpt")

	Lock()
	ATTIcons:SetScale(db.Scale or 1)
	ATTIcons:Hide()
	ATTAnchor:Hide()
	ATT:Hide()
end

function ATT:FindAbilityIcon(ability, id)
	local icon
	if id then
		icon = GetSpellTexture(id)
	else
		icon = GetSpellTexture(self:FindAbilityID(ability))
	end
	return icon
end

function ATT:FindAbilityID(ability)
	for _,S in pairs(ATTdefault) do
		for _,v in pairs(S) do
			for _,sp in pairs(v) do
				for _,SPELLID in pairs(sp) do
					local spellName, spellRank, spellIcon = GetSpellInfo(SPELLID)
					if(spellName and spellName == ability) then
						return SPELLID
					end
				end
			end
		end
	end
end

-------------------------------------------------------------
-- Panel
-------------------------------------------------------------

local function ListButtonOnClick(self)
	self:GetParent().currentButton = self.index
	ATT:UpdateScrollBar()
end

local function CreateListButton(parent, index)
	local name = parent:GetName()..index

	local button = CreateFrame("Button", name, parent)
		button:SetWidth(130)
		button:SetHeight(25)

		button:SetNormalFontObject("GameFontNormalSmallLeft")

		button:SetNormalTexture("Interface\\QuestFrame\\UI-QuestLogTitleHighlight")
		local NormalTex = button:GetNormalTexture()
		NormalTex:SetVertexColor(1, 0.8, 0, 0.7)
		NormalTex:SetTexCoord(0.11, 0.88, 0.02, 0.97)
		NormalTex:SetDrawLayer("BACKGROUND", 1)

		button:SetHighlightTexture("Interface\\ContainerFrame\\UI-Icon-QuestBorder")
		button:GetHighlightTexture():SetTexCoord(0.11, 0.88, 0.02, 0.97)

		button:SetScript("OnClick", ListButtonOnClick)

		button.index = index

	return button
end

local function CreateEditBox(name,parent,width,height)
	local editbox = CreateFrame("EditBox",parent:GetName()..name,parent,"InputBoxTemplate")
		editbox:SetHeight(height)
		editbox:SetWidth(width)
		editbox:SetAutoFocus(false)

	local label = editbox:CreateFontString(nil, "BACKGROUND", "GameFontNormal")
		label:SetText(name)
		label:SetPoint("BOTTOMLEFT", editbox, "TOPLEFT", -3, 0)

	return editbox
end

local function CreateOptionBG(parent, width, height, file, alpha)
	local texture = parent:CreateTexture()
	texture:SetTexture(file or "Interface\\Tooltips\\UI-Tooltip-Background")
	texture:SetSize(width, height)
	texture:SetAlpha(alpha or 0.2)

	return texture
end

local function ZoneSet(setting, value)
	db[setting] = value

	QUERY_SPEC_STOP()
	ATT:ApplySettings()
	if ( ENABLED ) then
		ATT:UpdateAllAnchors()
		QUERY_SPEC_START()
	end
end

local function SettingsPrint(title, msg)
	print(title, ": |cffFF4500", msg)
end

local function SortAbilities(a, b)
	if ((a.order or 1) == (b.order or 1)) then
		return (a.id) < (b.id)
	end

	return (a.order or 1) < (b.order or 1)
end

local function GetSelectedSpecs()
	local ClassSpecs = ATTdefault.dbSpecs[db.SelClass]
	local Specs = {"*", "All"}

	for SpecName, _ in pairs(ClassSpecs) do
		insert(Specs, SpecName)
		insert(Specs, SpecName)
	end

	return Specs
end

local function GetLocalClassList()
	local ClassList = {}

	for ClassID, ClassName in pairs(LOCALIZED_CLASS_NAMES_MALE) do
		insert(ClassList, ClassID)
		insert(ClassList, ClassName)
	end

	return ClassList
end

local function AttachToggle(panel)
	if ( db.Attach ) then
		panel.offsetX:SetAlpha(1)
		panel.offsetY:SetAlpha(1)
		panel.horiz:SetAlpha(1)
		panel.offsetX:Enable()
		panel.offsetY:Enable()
		panel.horiz:Enable()

		panel.lock:SetChecked(1)
		panel.lock:SetAlpha(0.5)
		panel.lock:Disable()
		db.Lock = 1
	else
		panel.offsetX:SetAlpha(0.5)
		panel.offsetY:SetAlpha(0.5)
		panel.horiz:SetAlpha(0.5)
		panel.offsetX:Disable()
		panel.offsetY:Disable()
		panel.horiz:Disable()

		if ( db.Lock == 1 ) then
			panel.lock:SetChecked(0)
			panel.lock:SetAlpha(1)
			panel.lock:Enable()
			db.Lock = nil
		end
	end

	Lock()
end

local function RowToggle(panel)
	if ( db.Rows ) then
		panel.spacingY:SetAlpha(1)
		panel.spacingY:Enable()
	else
		panel.spacingY:SetAlpha(0.5)
		panel.spacingY:Disable()
	end
end

local function NULL() end

function ATT:BuildOptions()
	local panel = self
	local self = ATT
	self.panel = panel

	local CheckOffsetX = 50
	local SliderWidth = 75

	-- Title
	panel:MakeTitleTextAndSubText(panel.name)

--[[

BORDER/BG

]]

	-- Display
	local bg = CreateOptionBG(panel, 403, 65)
	bg:SetPoint("TOPLEFT", panel, "TOPLEFT", 5, -40)

	-- Offset
	local bg = CreateOptionBG(panel, 403, 45)
	bg:SetPoint("TOPLEFT", panel, "TOPLEFT", 5, -120)

	-- Zone
	local bg = CreateOptionBG(panel, 403, 25)
	bg:SetPoint("TOPLEFT", panel, "TOPLEFT", 5, -180)

	-- Ability
	local bg = CreateOptionBG(panel, 230, 20, "Interface\\BUTTONS\\UI-Listbox-Highlight")
	bg:SetPoint("TOPLEFT", panel, "TOPLEFT", 150, -258)

	local bg = CreateOptionBG(panel, 403, 170, "Interface\\BUTTONS\\UI-Listbox-Highlight")
	bg:SetPoint("TOPLEFT", panel, "TOPLEFT", 5, -252)

	local abilitylabel = panel:CreateFontString(nil, "BACKGROUND", "GameFontNormalLarge")
		abilitylabel:SetText("Abilities")
		abilitylabel:SetPoint("TOPLEFT", bg, "TOPLEFT", 40, 25)

		local abilityicon = CreateOptionBG(panel, 25, 25, "Interface\\ICONS\\inv_misc_book_09", 1)
		abilityicon:SetPoint("TOPLEFT", panel, "TOPLEFT", 15, -221)

--[[

ALIGN

]]

	-- Attach
	local attach = panel:MakeToggle(
		'name', 'Attach',
		'description', 'Attach to party/raid frames.',
		'default', false,
		'getFunc', function() return db.Attach end,
		'setFunc', function(value)
			db.Attach = value
			AttachToggle(panel)
			ATT:LoadPositions()
		end)
	attach:SetPoint("TOPLEFT", panel, "TOPLEFT", 330, -10)

	-- Lock
	local lock = panel:MakeToggle(
		'name', 'Lock',
		'description', 'Lock anchors from being draggable.',
		'default', false,
		'getFunc', function() return db.Lock end,
		'setFunc', function(value) db.Lock = value Lock() end)
	lock:SetPoint("RIGHT", attach, "LEFT", -40, 0)
	panel.lock = lock

--[[

DISPLAY

]]

	-- Scale
	local scale = panel:MakeSlider(
		'name', 'Scale',
		'description', 'Adjust the scale of icons',
		'minText', '-',
		'maxText', '+',
		'minValue', 0.1,
		'maxValue', 5,
		'step', 0.05,
		'default', 1,
		'current', db.Scale,
		'setFunc', function(value) db.Scale = value ATTIcons:SetScale(db.Scale) end)
	scale:SetPoint("TOPLEFT", panel, "TOPLEFT", 25, -55)
	scale:SetWidth(90)

	local hidden = panel:MakeToggle(
		'name', 'Hidden',
		'description', 'Only show icon on cooldown.',
		'default', false,
		'getFunc', function() return db.Hidden end,
		'setFunc', function(value) db.Hidden = value ATT:UpdateAllAnchors() end)
	hidden:SetPoint("TOPLEFT", scale, "TOPLEFT", 120, 5)

	local glow = panel:MakeToggle(
		'name', 'Glow',
		'description', 'Glow icon when active.',
		'default', true,
		'getFunc', function() return db.Glow end,
		'setFunc', function(value) db.Glow = value end)
	glow:SetPoint("LEFT", hidden, "RIGHT", CheckOffsetX, 0)

	local border = panel:MakeToggle(
		'name', 'Border',
		'description', 'Borders around icons.',
		'default', true,
		'getFunc', function() return db.Border end,
		'setFunc', function(value) db.Border = value ATT:UpdateAllAnchors() end)
	border:SetPoint("LEFT", glow, "RIGHT", CheckOffsetX, 0)

	local left = panel:MakeToggle(
		'name', 'Grow Left',
		'description', 'Grow icons to the left.',
		'default', false,
		'getFunc', function() return db.Left end,
		'setFunc', function(value) db.Left = value ATT:UpdateAllAnchors() end)
	left:SetPoint("TOPLEFT", scale, "TOPLEFT", 0, -25)
	
	local rows = panel:MakeToggle(
		'name', 'Two Rows',
		'description', 'Show icons on two rows.',
		'default', false,
		'getFunc', function() return db.Rows end,
		'setFunc', function(value)
			db.Rows = value
			RowToggle(panel)
			ATT:UpdateAllAnchorIcons()
		end)
	rows:SetPoint("LEFT", left, "RIGHT", CheckOffsetX + 20, 0)

	local horiz = panel:MakeToggle(
		'name', 'Horizontal',
		'description', 'Show icons under attached frame.',
		'default', false,
		'getFunc', function() return db.Horiz end,
		'setFunc', function(value) db.Horiz = value ATT:LoadPositions() end)
	horiz:SetPoint("LEFT", rows, "RIGHT", CheckOffsetX + 20, 0)
	panel.horiz = horiz

	local tooltip = panel:MakeToggle(
		'name', 'Tooltip',
		'description', 'Show tooltips on mouseover.',
		'default', false,
		'getFunc', function() return db.Tooltip end,
		'setFunc', function(value) db.Tooltip = value end)
	tooltip:SetPoint("LEFT", horiz, "RIGHT", CheckOffsetX + 20, 0)

--[[

OFFSETS

]]

	local offsetX = panel:MakeSlider(
		'name', 'X Offset',
		'description', 'X Offset.',
		'minText', '',
		'maxText', '',
		'minValue', -100,
		'maxValue', 100,
		'step', 1,
		'default', 0,
		'current', db.OffX or 0,
		'setFunc', function(value) db.OffX = value ATT:LoadPositions() end,
		'currentTextFunc', function(value) return value end)
	offsetX:SetPoint("TOP", left, "BOTTOM", 25, -30)
	offsetX:SetWidth(SliderWidth)
	panel.offsetX = offsetX

	local offsetY = panel:MakeSlider(
		'name', 'Y Offset',
		'description', 'Y Offset.',
		'minText', '',
		'maxText', '',
		'minValue', -100,
		'maxValue', 100,
		'step', 1,
		'default', 0,
		'current', db.OffY or 0,
		'setFunc', function(value) db.OffY = value ATT:LoadPositions() end,
		'currentTextFunc', function(value) return value end)
	offsetY:SetPoint("LEFT", offsetX, "RIGHT", 20, 0)
	offsetY:SetWidth(SliderWidth)
	panel.offsetY = offsetY

	-- Spacing
	local spacingX = panel:MakeSlider(
		'name', 'Icon Spacing',
		'description', 'Icon Spacing.',
		'minText', '',
		'maxText', '',
		'minValue', 0,
		'maxValue', 20,
		'step', 1,
		'default', 0,
		'current', db.SpaceX,
		'setFunc', function(value) db.SpaceX = value ATT:UpdateAllAnchorIcons() end,
		'currentTextFunc', function(value) return value end)
	spacingX:SetPoint("LEFT", offsetY, "RIGHT", 20, 0)
	spacingX:SetWidth(SliderWidth)

	local spacingY = panel:MakeSlider(
		'name', 'Row Spacing',
		'description', 'Row spacing.',
		'minText', '',
		'maxText', '',
		'minValue', 0,
		'maxValue', 20,
		'step', 1,
		'default', 0,
		'current', db.SpaceY,
		'setFunc', function(value) db.SpaceY = value ATT:UpdateAllAnchorIcons() end,
		'currentTextFunc', function(value) return value end)
	spacingY:SetPoint("LEFT", spacingX, "RIGHT", 20, 0)
	spacingY:SetWidth(SliderWidth)
	panel.spacingY = spacingY

--[[

ZONE

]]

	local arena = panel:MakeToggle(
		'name', 'Arena',
		'description', 'Enable in Arena.',
		'default', false,
		'getFunc', function() return db.Arena end,
		'setFunc', function(value) ZoneSet("Arena", value) end)
	arena:SetPoint("TOP", offsetX, "BOTTOM", -25, -27)

	local dungeon = panel:MakeToggle(
		'name', 'Dungeon',
		'description', 'Enable in Dungeon.',
		'default', false,
		'getFunc', function() return db.Dungeon end,
		'setFunc', function(value) ZoneSet("Dungeon", value) end)
	dungeon:SetPoint("LEFT", arena, "RIGHT", 40, 0)

	local raid = panel:MakeToggle(
		'name', 'Raid/BG',
		'description', 'Enable in Raid/Battleground.\n\n|cFFFFFFFFOnly works for your group!',
		'default', false,
		'getFunc', function() return db.Raid end,
		'setFunc', function(value) ZoneSet("Raid", value) end)
	raid:SetPoint("LEFT", dungeon, "RIGHT", 65, 0)

	local world = panel:MakeToggle(
		'name', 'World',
		'description', 'Enable in World.',
		'default', false,
		'getFunc', function() return db.World end,
		'setFunc', function(value) ZoneSet("World", value) end)
	world:SetPoint("LEFT", raid, "RIGHT", 60, 0)

--[[

TRINKET/RACIAL

]]

	local showTrinket = panel:MakeToggle(
		'name', 'Trinket',
		'description', 'Show PvP Trinket icon.',
		'default', false,
		'getFunc', function() return db.Trinket end,
		'setFunc', function(value) db.Trinket = value ATT:UpdateAllAnchors() end)
	showTrinket:SetPoint("TOP", world, "BOTTOM", -10, -15)

	local showRacial = panel:MakeToggle(
		'name', 'Racial',
		'description', 'Show Racial icon.',
		'default', false,
		'getFunc', function() return db.Racial end,
		'setFunc', function(value) db.Racial = value ATT:UpdateAllAnchors() end)
	showRacial:SetPoint("LEFT", showTrinket, "RIGHT", 50, 0)

	AttachToggle(panel)
	RowToggle(panel)

	self:CreateAbilityEditor()
end

function ATT:UpdateScrollBar()
	local scrollframe = self.scrollframe
	local btns = self.btns
	local SelClassSpecs = db.Spells[db.SelClass] 
	local line = 1

	for specID, abilities in pairs(SelClassSpecs) do
		for abilityIndex, abilityTable in pairs(abilities) do
			local btn = btns[line]
			local ability, id, cooldown, spellStatus = abilityTable.ability, abilityTable.id, abilityTable.cooldown, abilityTable.spellStatus	
			abilitytexture = self:FindAbilityIcon(ability, id)

			if ( not btn ) then
				btn = CreateListButton(scrollframe, line)

				if ( line == 1 ) then
					btn:SetPoint("TOPLEFT", scrollframe, "TOPLEFT", 2, 0)
				else
					btn:SetPoint("TOP", btns[line - 1], "BOTTOM")
				end

				btns[line] = btn
			end

			if ( spellStatus == false ) then
				btn:SetText("|cff808080|T"..(abilitytexture or "")..":18|t " ..ability.."|r")
			else
				btn:SetText("|T"..(abilitytexture or "")..":18|t " ..ability)
			end

			if ( ability ~= scrollframe.currentButton and line ~= scrollframe.currentButton ) then
				btn:UnlockHighlight()
			else
				btn:LockHighlight()
				scrollframe.ideditbox:SetText(id or "")
				scrollframe.cdeditbox:SetText(cooldown or "")
				scrollframe.order:SetValue(abilityTable.order or 1)

				scrollframe.spec.initialize()
				scrollframe.spec:SetValue(specID or "*")

				scrollframe.status.initialize()
				scrollframe.status:SetValue(tostring(spellStatus == false and "false" or "true"))
			end

			btn:Show()
			line = line + 1
		end 
	end 			

	-- Button Overflow
	for i=line, #self.btns do btns[i]:Hide() end
end

function ATT:CreateAbilityEditor()
	local panel = self.panel
	self.btns = {}

	if ( not db.SelClass ) then
		db.SelClass = "WARRIOR"
	end

	local scrollframe = CreateFrame("ScrollFrame", "ATTScrollFrame", panel, "UIPanelScrollFrameTemplate")
	local child = CreateFrame("ScrollFrame" ,"ATTScrollFrameChild" , scrollframe)
	scrollframe:SetScrollChild(child)
	child:SetSize(1, 1)
	self.scrollframe = child

	scrollframe:SetSize(130,126)
	scrollframe:SetPoint("TOPLEFT", 15, -285)

	local class = panel:MakeDropDown(
		"name", "",
		"description", "Pick a class to edit abilities.",
		"values", GetLocalClassList(),
		"default", 'WARRIOR',
		"getFunc", function() return db.SelClass end,
		"setFunc", function(value)
			db.SelClass = value
			ATT:UpdateScrollBar()
			child.spec.initialize()
			child.spec:SetValue("*")
			child.spec.values = GetSelectedSpecs()
		end)
	class:SetPoint("TOP", scrollframe, "TOP", 0, 30)
	child.class = class  	

	local spec = panel:MakeDropDown(
		"name", " Specialization",
		"description", "Chosen specialization.",
		"values", GetSelectedSpecs(),
		"default", "*",
		"current", "*",
		"setFunc", NULL)
	spec:SetPoint("TOPLEFT", scrollframe, "TOPRIGHT", 15, -15)
	child.spec = spec

	local status = panel:MakeDropDown(
	   'name', ' Status',
		'description', 'Enable or disable ability.',
		'values', {
					"true", "Enabled",
					"false", "Disabled",
		 },
		'default', 'true',
		'current', 'true',
		'setFunc', NULL)
	status:SetPoint("LEFT", spec, "RIGHT", -26, 0)
	child.status = status

	local ideditbox = CreateEditBox("Spell ID", scrollframe, 55, 25)
	ideditbox:SetPoint("TOPLEFT", spec, "BOTTOMLEFT", 25, -15)
	child.ideditbox = ideditbox

	local cdeditbox = CreateEditBox("CD (s)", scrollframe, 35, 25)
	cdeditbox:SetPoint("LEFT", ideditbox, "RIGHT", 7, 0)
	child.cdeditbox = cdeditbox

	-- GroupedCD list
	local groupedCDList = '|cFFFFFFFFAbilities with same ID share a cooldown.\n\n|cFFFF0000Example: Pummel will trigger Shield Bash.|r\n'
	for class, spells in pairs(groupedCooldowns) do
		groupedCDList = groupedCDList.."\n"..class.."\n"
		for Spell, Type in pairs(spells) do
			groupedCDList = groupedCDList..Type.." - "..Spell.."\n"
		end
	end

	local groupedCD = panel:MakeButton(
		'name', '|TInterface\\DialogFrame\\UI-Dialog-Icon-AlertNew:16|t Grouped Spells',
		'description', groupedCDList,
		'func', NULL)
	groupedCD:SetPoint("TOP", ideditbox, "BOTTOM", 20, 0)
	groupedCD:SetNormalTexture(nil)
	groupedCD:SetPushedTexture(nil)

	local order = panel:MakeSlider(	
		'name', 'Icon Order',
		'description', 'Adjust icon order priority.\n\n|cFFFFFFFFSpec icons are ALWAYS displayed last!\n\n|cFFFF0000*Work in progress!|r',
		'minText', '',
		'maxText', '',
		'minValue', 1,
		'maxValue', 69,
		'step', 1,
		'default', 1,
		'current',  1,
		'setFunc', NULL,
		'currentTextFunc', function(value) return value end)
	order:SetPoint("TOP", status, "BOTTOM", 0, -17)
	order:SetWidth(100)
	child.order = order

	local addbutton = panel:MakeButton(	
		'name', 'Add/Update',
		'description', "Add / Update Ability",
		'func', function()
			local _, SpellName, SpellIcon, SpellSpec, SpellCD, SpellStatus, SpellOrder
			local SpellID = ideditbox:GetText():match("^[0-9]+$")

			if ( SpellID ) then
				SpellCD = cdeditbox:GetText():match("^[0-9]+$")

				if ( SpellCD ) then
					SpellName, _, SpellIcon = GetSpellInfo(SpellID)
					SpellSpec = spec.value
					SpellStatus = status.value
					SpellOrder = order.value

					if ( SpellIcon and SpellName and (not SpellSpec or db.Spells[db.SelClass] and db.Spells[db.SelClass][SpellSpec]) ) then
						SettingsPrint("Added/Updated", SpellName)

						local Abilities = db.Spells[db.SelClass][SpellSpec or "*"]
						local AbilityNameExist, AbilityIndexExist = self:FindAbilityByName(Abilities, SpellName)

						-- Updated/New Data
						local Data = {}
						Data.ability = SpellName
						Data.cooldown = tonumber(SpellCD)
						Data.id = tonumber(SpellID)

						if ( SpellStatus == "false" ) then
							Data.spellStatus = false
						end

						if ( SpellOrder > 1 ) then
							Data.order = SpellOrder
						end

						-- Save it
						if ( AbilityNameExist and AbilityIndexExist ) then
							Abilities[AbilityIndexExist] = Data
						else
							insert(Abilities, Data)
						end

						sort(Abilities, SortAbilities)

						child.currentButton = SpellName
						ATT:UpdateScrollBar()
						ATT:UpdateAllAnchors()

						return
					end
				end
			end

			SettingsPrint("Invalid/Blank", "ID or Cooldown")
	end)
	addbutton:SetPoint("TOP", ideditbox, "BOTTOM", 25, -25)

	local removebutton = panel:MakeButton(
		'name', 'Remove',
		'description', 'Remove Ability',
		'func', function()
				local SpellName = GetSpellInfo(ideditbox:GetText())
	     		local SpellSpec = spec.value
	     		local AbilityNameExist, AbilityIndexExist = self:FindAbilityByName(db.Spells[db.SelClass][SpellSpec or "*"], SpellName)

	     		if ( AbilityNameExist and AbilityIndexExist ) then
					remove(db.Spells[db.SelClass][SpellSpec], AbilityIndexExist)

					ideditbox:SetText("")
					cdeditbox:SetText("")
					order:SetValue(1)
					child.currentButton = nil
					ATT:UpdateScrollBar()
					ATT:UpdateAllAnchors()

					SettingsPrint("Removed Ability", SpellName)
				else
					SettingsPrint("Invalid/Blank", "Ability ID")
				end
	end)
	removebutton:SetPoint("LEFT", addbutton, "RIGHT", 10, 0)
	removebutton:SetWidth(90)
end

ATT:RegisterEvent("VARIABLES_LOADED")
ATT:SetScript("OnEvent", ATT_OnLoad)