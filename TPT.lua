local addon, SPELLDB = ...
local addon, ATTdefault = ...
local match = string.match
local remove = table.remove
local GetSpellInfo = GetSpellInfo
local UnitClass = UnitClass
local UnitGUID = UnitGUID
local IsInInstance = IsInInstance
local UnitRace = UnitRace
local CooldownFrame_Set = CooldownFrame_Set
local Timer = C_Timer.NewTicker
local TimerAfter = C_Timer.After
local V = 7.53

local ENABLED

local CURRENT_ZONE_TYPE
local PREVIOUS_ZONE_TYPE

local PLAYER_FACTION

local PARTY_NUM
local PARTY_NUM_PREVIOUS

local __CompactRaidFrame = false

local db
local dbModif = dbModif
local dbTrinket = dbTrinket

local ATT = CreateFrame("Frame","ATT",UIParent)
local ATTIcons = CreateFrame("Frame",nil,UIParent)
local ATTAnchor = CreateFrame("Frame",nil,UIParent)
local ATTTooltip = CreateFrame("GameTooltip", "ATTGameTooltip", nil, "GameTooltipTemplate")

local INSPECT_FRAME
local INSPECT_CURRENT
local QUERY_SPEC_TICK
local QUERY_SPEC_TICK_TIMEOUT
local GROUP_ROSTER_UPDATE_DELAY_QUEUED

local TRINKET_HUMAN = "Will to Survive"
local GROUP_ROSTER_UPDATE = "GROUP_ROSTER_UPDATE"
local INSPECT_READY = "INSPECT_READY"

-- Compat
if ( GetBuildInfo() == "3.3.5" ) then
	TRINKET_HUMAN = "Every Man for Himself"
	GROUP_ROSTER_UPDATE = "PARTY_MEMBERS_CHANGED"
	INSPECT_READY = "INSPECT_TALENT_READY"
end

local iconlist = {}
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
		[34600] = 3, -- Snake Trap
	},
	["MAGE"] = {
		[43010] = 1,  -- Fire Ward
		[43012] = 1,  -- Frost Ward
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
		[1766] = 10, -- Kick
		[51722] = 60,-- Dismantle
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
	local icon = select(3, GetSpellInfo(id))
	return icon
end

local function convertspellids(t)
	local temp = {}
	for class, table in pairs(t) do
		temp[class] = {}
		for spec, spells in pairs(table) do
			spec = tostring(spec)
			temp[class][spec] = {}
			for k, spell in pairs(spells) do
				local spellInfo = GetSpellInfo(spell[1])
				if spellInfo then temp[class][spec][#temp[class][spec]+1] = { ability = spellInfo, cooldown = spell[2], id = spell[1], talent = spell.talent } end
			end
		end
	end
	return temp
end

local ATTdefaultAbilities = convertspellids(ATTdefault.defaultAbilities)

local function Gconvertspellids(t)
	local temp = {}
	for class,spells in pairs(t) do
		temp[class] = {}
		for spell, k in pairs(spells) do
			local spellName = GetSpellInfo(spell)
			if spellName then
				temp[class][spellName] = k
			end
		end
	end
	return temp
end
groupedCooldowns = Gconvertspellids(groupedCooldowns)
dbSpecAbilities = Gconvertspellids(dbSpecAbilities)
overallCooldowns = Gconvertspellids(overallCooldowns)

local temp = {}
for k, v in pairs(cooldownResetters) do
	local spellInfo = GetSpellInfo(k)
	if spellInfo then
		temp[spellInfo] = {}
		if type(v) == "table" then
			for id in pairs(v) do
				local spellInfo2 = GetSpellInfo(id)
				if spellInfo2 then temp[spellInfo][spellInfo2] = 1 end
			end
		else
			local spellInfo3 = GetSpellInfo(k)
			if spellInfo3 then
				temp[spellInfo3] = v
			end
		end
	end
end

cooldownResetters = temp
temp = nil
convertspellids = nil

local function ValidZoneType()
	if (db.arena and CURRENT_ZONE_TYPE == "arena") or
	   (db.dungeons and CURRENT_ZONE_TYPE == "party") or
	   (db.inraid and (CURRENT_ZONE_TYPE == "raid" or CURRENT_ZONE_TYPE == "pvp") ) or
	   (db.outside and CURRENT_ZONE_TYPE == "none")
	then
		return 1
	end
end

local function Lock()
	if db.lock then ATTAnchor:Hide() else ATTAnchor:Show() end
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
			-- are we fighting
			if InCombatLockdown() then return end
			-- is the player inspecting
			if InspectFrame and InspectFrame:IsShown() then return end

			if not INSPECT_CURRENT then return end
			
			local anchor = anchors[INSPECT_CURRENT]
			
			if not anchor or not anchor.class then
				-- anchor not yet created
				INSPECT_CURRENT = nil
				return
			end

			local SpecSpells = dbSpecAbilities[anchor.class]

			if ( SpecSpells ) then
				anchor.spec = {}
				local Found
				local TalentGroup = GetActiveTalentGroup(true)

				for Tab = 1, 3 do
					for Talent = 1, 31 do
						local Name, _, _, _, Spent = GetTalentInfo(Tab, Talent, true, false, TalentGroup)

						if ( Name ) then
							local Spent = Spent > 0

							if ( Spent ) then
								if ( SpecSpells[Name] ) then
									Found = true
									anchor.spec[Name] = Spent
								end
							end
						end
					end
				end

				if ( not Found ) then
					anchor.spec = nil
				else
					ATT:TrinketCheck("party"..INSPECT_CURRENT, INSPECT_CURRENT) -- Update icons for unit.
				end
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
	for i=1,#anchors do
		local anchor = anchors[i]

		local scale = anchor:GetEffectiveScale()
		local worldscale = UIParent:GetEffectiveScale()
		local x = anchor:GetLeft() * scale
		local y = (anchor:GetTop() * scale) - (UIParent:GetTop() * worldscale)
		print(scale, worldscale, x,y)

		if not db.positions[k] then
			db.positions[k] = {}
		end
		db.positions[k].x = x
		db.positions[k].y = y
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

	for i=1, (__CompactRaidFrame and 40 or PARTY_NUM) do
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
			if ( __CompactRaidFrame )  then
				AddOn = _G["CompactRaidFrame"..i]
			else
				AddOn = _G["PartyMemberFrame"..i]
			end
		end

		if ( AddOn ) then
			Frame = AddOn
		end

		--if ( Frame and not Frame:IsForbidden() ) then -- ERROR: 3.3.5
			if ( Frame and Frame.unit and UnitGUID(Frame.unit) == UnitIDGUID ) then
				return Frame
			end
		--end
	end
end

function ATT:LoadPositions()
	local PartyNum = PARTY_NUM

	db.positions = db.positions or {}
	
	if ( PartyNum > 0 ) then
		for i=1,PartyNum do
			local anchor = anchors[i]

			anchor:ClearAllPoints() -- COMPAT

			local raidFrame
			if ( db.attach ) then
				raidFrame = ATT:FindCompactRaidFrameByUnit("party"..i)
			end

			anchor:ClearAllPoints()
			if ( raidFrame ) then	
				if ( db.horizontal ) then 	
					anchor:SetPoint(db.growLeft and "BOTTOMLEFT" or "BOTTOMRIGHT", raidFrame, db.growLeft and "BOTTOMRIGHT" or "BOTTOMLEFT", db.offsetX, db.offsetY)
				else	
					anchor:SetPoint(db.growLeft and "BOTTOMLEFT" or "BOTTOMRIGHT", raidFrame, db.growLeft and "TOPLEFT" or "TOPRIGHT", db.offsetX, db.offsetY)
				end
			else
				if ( db.positions[i] ) then	
					local x = db.positions[i].x	
					local y = db.positions[i].y	
					local scale = anchor:GetEffectiveScale()
					anchor:SetPoint("TOPLEFT", UIParent,"TOPLEFT", x/scale, y/scale)
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
			anchor:SetScript("OnMouseDown",function(self,button) if button == "LeftButton" and not db.attach then self:StartMoving() end end)
			anchor:SetScript("OnMouseUp",function(self,button) if button == "LeftButton" and not db.attach then self:StopMovingOrSizing() ATT:SavePositions() end end)
			anchor:Hide()
			anchors[i] = anchor
			anchor.i = i

		local index = anchor:CreateFontString(nil,"ARTWORK","GameFontNormal")
			index:SetPoint("CENTER")
			index:SetText(i)
	end
end

-- creates a new raw frame icon that can be used/reused to show cooldowns
local function CreateIcon(anchor)
	local icon = CreateFrame("Frame",anchor:GetName().."Icon".. (#anchor.icons+1),ATTIcons,"ActionButtonTemplate")
	icon:SetSize(40,40) 	
	local cd = CreateFrame("Cooldown",icon:GetName().."Cooldown",icon,"CooldownFrameTemplate")
	icon.cd = cd
	icon.Start = function(sentCD)
		icon.cooldown = tonumber(sentCD)

		if icon.cooldown then
			icon.starttime = GetTime()
			CooldownFrame_Set(cd, icon.starttime, icon.cooldown, 1)
			
			if ( db.Glow ) then
				if ( not icon.flash ) then
					icon.flash = CreateFrame("Frame", nil, icon, "TGlowFlash")
				end
				icon.flash.D:Play()
			end
		end
		
		icon:Show()
		icon.active = true 	
		activeGUIDS[icon.GUID] = activeGUIDS[icon.GUID] or {}	
		activeGUIDS[icon.GUID][icon.ability] = activeGUIDS[icon.GUID][icon.ability] or {}	
		activeGUIDS[icon.GUID][icon.ability].starttime = icon.starttime	
		activeGUIDS[icon.GUID][icon.ability].cooldown =  icon.cooldown

		if ( icon.cooldown and db.hidden ) then
			ATT:ToggleIconDisplay(anchor.i)
		end
	end
	icon.Stop = function()
		CooldownFrame_Set(cd,0,0,0)
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

		if ( db.hidden ) then
			ATT:ToggleIconDisplay(anchor.i)
		end
	end)
		
	ATT:ApplyIconTextureBorder(icon)

	-- tooltip:
	icon:EnableMouse()
	icon:SetScript('OnEnter', function()
		if db.showTooltip and icon.abilityID then	
			ATTTooltip:ClearLines()
			ATTTooltip:SetOwner(WorldFrame, "ANCHOR_CURSOR")
			ATTTooltip:SetSpellByID(icon.abilityID)
		end
	end)
	icon:SetScript('OnLeave', function()
		if db.showTooltip and icon.abilityID then	
			ATTTooltip:ClearLines()
			ATTTooltip:Hide()
		end
	end)
	return icon	
end

-- adds a new icon to icon list of anchor
function ATT:AddIcon(icons,anchor)
	local newicon = CreateIcon(anchor)
	iconlist[#iconlist+1] = newicon
	icons[#icons+1] = newicon
	
	newicon.isNeedStart = function(sentCD)
		cooldown = tonumber(sentCD)
		activeCooldown = newicon.cooldown
		endTimeCooldown = newicon.starttime + activeCooldown
		diff = endTimeCooldown - GetTime()
		
		if diff < cooldown then
			return true
		end
		
		if diff > cooldown then
			return false
		end
	end
	
	return newicon
end

-- applies texture border to an icon
function ATT:ApplyIconTextureBorder(icon)
	if db.showIconBorders then
		icon.texture:SetTexCoord(0,1,0,1)
	else
		icon.texture:SetTexCoord(0.07,0.9,0.07,0.90)
	end
end

-- hides anchors currently not in use due to too few party members	
function ATT:ToggleAnchorDisplay()
	for i=1, 4 do
		local anchor = anchors[i]

		if ( anchor ) then
			local PartyMemberExist = UnitInParty("party"..i)

			if ( not PartyMemberExist ) then
				local icons = anchor.icons

				for j=1, #icons do	
					icons[j].ability = nil	
					icons[j].seen = nil	
					icons[j].active = nil	
					icons[j].inUse = nil	
					icons[j].showing = nil	
				end

				anchor.spells = {}
				anchor:Hide()
				anchor:HideIcons()
			else
				anchor:Show()
			end
		end
	end
end

function ATT:UpdateAnchor(unit, i, PvPTrinket, TraceID, tcooldown)
	if not self:IsShown() then return end

	local _,class = UnitClass(unit)
	local guid = UnitGUID(unit)

	if not class or not guid then return end -- REMOVE?

	local _,race = UnitRace(unit)

	local anchor = anchors[i]	
	anchor.GUID = guid	
	anchor.class = class
	anchor.race = race
	local icons = anchor.icons
	local numIcons = 1

	-- PvP Trinket:
	if db.showTrinket  then 
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
	elseif icons[1] and icons[1].ability == PvPTrinketName then
		icons[1]:Hide()
		icons[1].showing = nil
		icons[1].inUse = nil
		icons[1].spec = nil
		table.remove(icons, 1) 
	end 

	-- Racials
	if db.showRacial then
		for abilityIndex, abilityTable in pairs(dbRacial) do
			local abilityCheck, id, cooldown, talent, race = abilityTable.ability, abilityTable.id, abilityTable.cooldown, abilityTable.talent, abilityTable.race
			
			ability = nil  
			_, raceID = UnitRace(unit)
			if raceID == race then
				ability = GetSpellInfo(abilityCheck)
				id = abilityCheck 
			end
			
			if id and ability then	
				local icon = icons[numIcons] or self:AddIcon(icons,anchor)   
				local texture = self:FindAbilityIcon(ability, id)
				if texture then
					icon.texture:SetTexture(texture)
				end
				icon.GUID = anchor.GUID
				icon.ability = ability
				icon.abilityID = id
				icon.cooldown = cooldown
				icon.inUse = true
				icon.spec = talent
				icon.spellStatus = spellStatus
				ATT:ApplyIconTextureBorder(icon)
			 
				activeGUIDS[icon.GUID] = activeGUIDS[icon.GUID] or {}
				if activeGUIDS[icon.GUID][icon.ability]  then
					icon.SetTimer(activeGUIDS[icon.GUID][ability].starttime,activeGUIDS[icon.GUID][ability].cooldown)
				else
					icon.Stop()
				end
				numIcons = numIcons + 1
			end
		end 
	end
	
	local specSpells = dbSpecAbilities[anchor.class]
	for specID, abilitiesTable in pairs(db.abilities[class]) do
		for abilityIndex, abilityTable in pairs(abilitiesTable) do
			if abilityTable.spellStatus ~= "DISABLED" and not specSpells[abilityTable.ability] or (anchor.spec and anchor.spec[abilityTable.ability]) then
				table.insert(anchor.spells, abilityTable)
				local icon = self:UpdateAnchorIcon(anchor, numIcons, abilityTable)
				activeGUIDS[icon.GUID] = activeGUIDS[icon.GUID] or {}
				if activeGUIDS[icon.GUID][icon.ability] then
					icon.SetTimer(activeGUIDS[icon.GUID][icon.ability].starttime,activeGUIDS[icon.GUID][icon.ability].cooldown)
				else
					icon.Stop()
				end
				numIcons = numIcons + 1
			end
		end
	end

	-- clean leftover icons
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
	local ability, id, cooldown, talent, spellStatus = abilityTable.ability, abilityTable.id, abilityTable.cooldown, abilityTable.talent, abilityTable.spellStatus
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
	icon.spec = talent
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
				icon.showing = (not db.hidden and icon.seen) or (db.hidden and activeGUIDS[icon.GUID][icon.ability] and icon.active)
			else	
				icon.showing = (activeGUIDS[icon.GUID] and activeGUIDS[icon.GUID][icon.ability] and icon.active) or (not db.hidden)
			end
		end
		icon:ClearAllPoints()

		if icon and icon.ability and icon.showing then	
			if db.tworows then	
				if count == 1 then 	
					icon:SetPoint(db.growLeft and "TOPRIGHT" or "TOPLEFT", anchor, db.growLeft and "BOTTOMLEFT" or "BOTTOMRIGHT", db.growLeft and -1 * db.OffsetX or db.OffsetX, 0)
				elseif  (count % 2 == 0 )  then				
					icon:SetPoint(db.growLeft and "TOP" or "TOP", icons[lastActiveIndex], db.growLeft and "BOTTOM" or "BOTTOM", db.growLeft and 0 or 0, -1 * db.OffsetY )			
				else		
					icon:SetPoint(db.growLeft and "BOTTOMRIGHT" or "BOTTOMLEFT", icons[lastActiveIndex], db.growLeft and "TOPLEFT" or "TOPRIGHT", db.growLeft and -1 * db.OffsetX  or db.OffsetX, db.OffsetY)
				end	
			else
				if count == 1  then	
					icon:SetPoint(db.growLeft and "TOPRIGHT" or "TOPLEFT", anchor, db.growLeft and "BOTTOMLEFT" or "BOTTOMRIGHT", db.growLeft and -1 * db.OffsetX or db.OffsetX, 0)
				else	
					icon:SetPoint(db.growLeft and "RIGHT" or "LEFT", icons[lastActiveIndex], db.growLeft and "LEFT" or "RIGHT", db.growLeft and -1 * db.OffsetX or db.OffsetX, 0)
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

-- Checking PVP trinket

function ATT:TrinketCheck(Unit, i)
	local Trinket = dbTrinket[1] -- Fetch trinket data, or could do FindAbilityByID, saving calls.
	local Name
	local Icon

	if ( PLAYER_FACTION == "Alliance" ) then
		if ( UnitRace(Unit) == "Human" ) then
			Name = TRINKET_HUMAN
		end

		Icon = GetItemIcon(18854)
	else
		Icon = GetItemIcon(18849)
	end

	Trinket.ability = Name or "PvP Trinket"

	self:UpdateAnchor(Unit, i, Trinket, Icon)  
end

function ATT:UpdateAllAnchors()
	if ( PARTY_NUM > 0 ) then
		for i=1, PARTY_NUM do
			local Unit = "party"..i
			local _, Class = UnitClass(Unit)

			if ( not Class ) then break end
			if ( not anchors[i] ) then break end

			self:TrinketCheck(Unit, i) 
		end
	end

	self:LoadPositions()
	self:ToggleAnchorDisplay()
	--self:ApplySettings()
end

function ATT:UpdateAllAnchorIcons()
	if ( PARTY_NUM > 0 ) then
		for i=1, PARTY_NUM do -- GetNumPartyMembers or 4
			ATT:ToggleIconDisplay(i)
		end
	end
end

local function GROUP_ROSTER_UPDATE_DELAY()
	ATT:UpdateAllAnchors() -- This is better on classic, but on 3.3.5 inside ROSTER_UPDATE
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

	if ( ValidZoneType() ) then
		-- Our party has changed size, lets re-check spec.
		-- 3.3.5: This fires when we leave group, idk how to avoid.
		if ( PARTY_NUM > 0 and (PartyChanged or CURRENT_ZONE_TYPE == "arena") ) then -- Dynamic updating.
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
	-- Update the player faction, cause merc on Warmane.
	PLAYER_FACTION = UnitFactionGroup("player")

	local _
	PREVIOUS_ZONE_TYPE = CURRENT_ZONE_TYPE
	_, CURRENT_ZONE_TYPE = IsInInstance()

	-- Check if we have the CRF addon.
	if ( __CompactRaidFrame == false ) then
		__CompactRaidFrame = CompactRaidFrameContainer or CompactRaidFrameDB
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

function ATT:HandleGlow(SpellID, Event, Anchor)
	for i=1,#Anchor.icons do
		local icon = Anchor.icons[i]

		if ( icon.abilityID == SpellID ) then
			-- Need to check if the animation is already active, then do nothing.
			if ( Event == "SPELL_AURA_APPLIED" ) then
				if ( not icon.glow ) then
					icon.glow = CreateFrame("Frame", nil, icon, "TGlow")
				end
				icon.cd:SetAlpha(0)
				icon.glow:SetScript("OnUpdate", AnimateTexCoords_OnUpdate)
				icon.glow:Show()
			else
				HideGlow(icon)

				if ( icon.flash ) then
					icon.flash.D:Play()
				end
			end

			break
		end
	end
end

function ATT:StartCooldown(SpellID, Anchor)
	-- Check and find spell in DBS
	local cAbility = self:FindAbilityByID(Anchor.spells, SpellID) or self:FindAbilityByID(dbRacial, SpellID) or self:FindAbilityByID(dbTrinket, SpellID)
	local spellName = select(1,GetSpellInfo(SpellID))
	
	-- Add it to our "tracked cds"
	self:TrackCooldown(Anchor, spellName, cAbility and cAbility.cooldown or nil) 
end

function ATT:TrackCooldown(anchor, ability, cooldown)
	for k,icon in ipairs(anchor.icons) do
		if cooldown then 
			-- Direct cooldown
			if icon.ability == ability then 
				icon.seen = true
				icon.Start(cooldown)
				
				-- Overall Cooldown
				if overallCooldowns[anchor.race] and overallCooldowns[anchor.race][ability] then
					for k,overallCooldown in pairs(overallCooldowns[anchor.race]) do
						if k ~= icon.ability then
							for index,overallIcon in ipairs(anchor.icons) do
								if overallIcon.ability == k and overallIcon.isNeedStart(overallCooldown) then
									overallIcon.Start(overallCooldown)
									break
								end
							end
							break
						end
					end
				end
				
			end	
		end

		-- Grouped Cooldowns
		if groupedCooldowns[anchor.class] and groupedCooldowns[anchor.class][ability] then
			for k in pairs(groupedCooldowns[anchor.class]) do
				if k == icon.ability and icon.shouldShow then icon.Start(cooldown) break end
			end
		end

		-- Cooldown resetters
		if cooldownResetters[ability] then
			if type(cooldownResetters[ability]) == "table" then
				if cooldownResetters[ability][icon.ability] then icon.Stop() end
			else
				icon.Stop()
			end
		end
	end
end

function ATT:COMBAT_LOG_EVENT_UNFILTERED(...)
	local _, Event, _, SourceGUID, _, _, _, DestGUID, _, _, _, SpellID, SpellName, _, SpellType = CombatLogGetCurrentEventInfo(...)

	--[[if ( not Event ) then
		_, Event, SourceGUID, _, _, DestGUID, _, _, SpellID, SpellName, _, SpellType = ...
	end]]

	local AuraEvent = (Event == "SPELL_AURA_REMOVED") or (Event == "SPELL_AURA_APPLIED")
	local CastEvent = (Event == "SPELL_CAST_SUCCESS")

	if ( CastEvent or AuraEvent ) then
		local Source, SourceID = self:GetUnitByGUID(SourceGUID)

		if ( Source ) then
			if ( SourceID < 5 ) then
				local Anchor = anchors[SourceID]

				-- Classic: Buff is fired BEFORE cast event. Makes no sense, I know.
				if ( CastEvent or (Event == "SPELL_AURA_APPLIED" and SpellName == "Hex") ) then
					self:StartCooldown(SpellID, Anchor)
				elseif ( SpellType == "BUFF" ) then
					if ( DestGUID == SourceGUID and db.Glow ) then
						self:HandleGlow(SpellID, Event, Anchor)
					end
				end
			end
		end
	end	
end

function ATT:ApplySettings()
	if ValidZoneType() and PARTY_NUM > 0 then
		if ( not ENABLED ) then
			ATTIcons:Show()
			self:Show()
			self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
			ENABLED = 1
		end
	elseif ( ENABLED ) then
		ATTIcons:Hide()
		self:Hide()
		self:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
		QUERY_SPEC_STOP()
		ENABLED = nil
	end
end

-- resets all icons on zone change
function ATT:StopAllIcons()
	for k=1,#iconlist do
		local v = iconlist[k]
		v.Stop()
		v.seen = nil
	end
	wipe(activeGUIDS)
end

local function ATT_OnLoad(self)
	self:RegisterEvent("PLAYER_ENTERING_WORLD")
	self:RegisterEvent(GROUP_ROSTER_UPDATE)
	self:SetScript("OnEvent",function(self,event, ...) if self[event] then self[event](self, ...) end end)

	ATTDB = ATTDB
	if (ATTDB and ( (ATTDB.V and V > ATTDB.V) or not ATTDB.V) ) or not ATTDB then
		print("ATT Loaded!")

		-- Cache the default abilities, they won't be the same if user edits them.
		ATTDB = { abilities = ATTdefaultAbilities, Scale = 1, OffsetY = 2 , OffsetX = 5 , Glow = 1, V = V, showIconBorders = true }
	end
	db = ATTDB
	db.classSelected = "WARRIOR"

	self:CreateAnchors()
	self:CreateOptions()
	self:UpdateScrollBar()
	Lock()
	ATTIcons:SetScale(db.Scale or 1)
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
	for _,S in pairs(SPELLDB) do
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

local function ZoneSet()
	QUERY_SPEC_STOP()
	ATT:UpdateAllAnchors()
	ATT:ApplySettings()
	QUERY_SPEC_START()
end

-------------------------------------------------------------
-- Panel
-------------------------------------------------------------

local SO = LibStub("LibSimpleOptions-1.01")

local function CreateListButton(parent,index)
	local button = CreateFrame("Button",parent:GetName()..index,parent)
		button:SetWidth(190)
		button:SetHeight(25)

	local font = CreateFont("ATTListFont")
		font:SetFont(GameFontNormal:GetFont(),12)
		font:SetJustifyH("LEFT")

	button:SetNormalFontObject(font)
	button:SetHighlightTexture("Interface\\ContainerFrame\\UI-Icon-QuestBorder")
	button:GetHighlightTexture():SetTexCoord(0.11,0.88,0.02,0.97)
	button:SetScript("OnClick",function(self) parent.currentButton = self:GetText() ATT:UpdateScrollBar() end)

	return button
end

local function CreateEditBox(name,parent,width,height)
	local editbox = CreateFrame("EditBox",parent:GetName()..name,parent,"InputBoxTemplate")
		editbox:SetHeight(height)
		editbox:SetWidth(width)
		editbox:SetAutoFocus(false)

	local label = editbox:CreateFontString(nil, "BACKGROUND", "GameFontNormal")
		label:SetText(name)
		label:SetPoint("BOTTOMLEFT", editbox, "TOPLEFT",-3,0)

	return editbox
end

function ATT:CreateOptions()
	local panel = SO.AddOptionsPanel("Arena Team Tracker", function() end)
	self.panel = panel	

	SO.AddSlashCommand("Arena Team Tracker", "/att")

	local scale = panel:MakeSlider(	
		'name', 'Scale',	
		'description', 'Adjust the scale of icons',	
		'minText', '0.1',	
		'maxText', '5',	
		'minValue', 0.1,	
		'maxValue', 5,	
		'step', 0.05,	
		'default', 1,	
		'current', db.Scale,	
		'setFunc', function(value) db.Scale = value ATTIcons:SetScale(db.Scale) end,	
		'currentTextFunc', function(value) return string.format("%.2f",value) end)
	scale:SetPoint("TOPLEFT",panel,"TOPLEFT",15,-30)
	
	local offsetX = CreateEditBox("Offset X", panel, 50, 25)
		offsetX:SetText(db.offsetX or "0")
		offsetX:SetCursorPosition(0)
		offsetX:SetPoint("LEFT", scale, "RIGHT", 18, 0)
		offsetX:SetScript("OnEnterPressed", function(self)
			self:ClearFocus()
			local num = self:GetText():match("%-?%d+$")
			if num then	
				print("Offset X changed and saved: " .. tostring(num))
				db.offsetX = num	
				ATT:LoadPositions()
			else	
				print("Wrong value for Offset X/Y")
				self:SetText(db.offsetX)
			end
		end)
		panel.offsetX = offsetX
	
	local offsetY = CreateEditBox("Offset Y", panel, 50, 25)
		offsetY:SetText(db.offsetY or "0")
		offsetY:SetCursorPosition(0)
		offsetY:SetPoint("LEFT", offsetX, "RIGHT", 8, 0)
		offsetY:SetScript("OnEnterPressed", function(self)
			self:ClearFocus()
			local num = self:GetText():match("%-?%d+$")
			if num then	
				print("Offset Y changed and saved: " .. tostring(num))
				db.offsetY = num	
				ATT:LoadPositions()
			else	
				print("Wrong value for Offset X/Y")
				self:SetText(db.offsetY)
			end
		end)
		panel.offsetY = offsetY	
	
	local OffsetX = CreateEditBox("Icon X", panel, 50, 25)
		OffsetX:SetText(db.OffsetX or 5)
		OffsetX:SetCursorPosition(0)
		OffsetX:SetPoint("LEFT", offsetY, "RIGHT", 8, 0)
		OffsetX:SetScript("OnEnterPressed", function(self)
			self:ClearFocus()
			local num = self:GetText():match("%-?%d+$")
			if num then	
				print("Icon Offset X changed and saved: " .. tostring(num))
				db.OffsetX = num	
				ATT:LoadPositions()
			else	
				print("Wrong value for Icon Offset X")
				self:SetText(db.OffsetX)
			end
		end)
		panel.OffsetX = OffsetX	

	local OffsetY = CreateEditBox("Icon Y", panel, 50, 25)
		OffsetY:SetText(db.OffsetY or 2)
		OffsetY:SetCursorPosition(0)
		OffsetY:SetPoint("LEFT", OffsetX, "RIGHT", 8, 0)
		if not db.OffsetY then local OffsetY = 2 end
		OffsetY:SetScript("OnEnterPressed", function(self)
			self:ClearFocus()
			local num = self:GetText():match("%-?%d+$")
			if db.OffsetY == nil then db.OffsetY = "2" end
			if num then	
				print("Icon Offset Y changed and saved: " .. tostring(num))
				db.OffsetY = num	
				ATT:LoadPositions()
			else	
				print("Wrong value for Icon Offset Y")
				self:SetText(db.OffsetY)
			end
		end)
		panel.OffsetY = OffsetY

	local attach = panel:MakeToggle(
		'name', 'Attach to frames',	
		'description', 'Attach to Blizzard raid frames',	
		'default', false,	
		'getFunc', function() return db.attach end,	
		'setFunc', function(value) db.attach = value ATT:LoadPositions() end)
	attach:SetPoint("TOPLEFT",scale,"TOPLEFT",-5,-35)
	
	local lock = panel:MakeToggle(	
		'name', 'Lock',	
		'description', 'Hide/Show anchors',	
		'default', false,	
		'getFunc', function() return db.lock end,	
		'setFunc', function(value) db.lock = value Lock() end)
	lock:SetPoint("LEFT",attach,"RIGHT",105,0)
	
	local hidden = panel:MakeToggle(	
		'name', 'Hidden',	
		'description', 'Show icons only when\nthey are on cooldown',	
		'default', false,	
		'getFunc', function() return db.hidden end,	
		'setFunc', function(value) db.hidden = value ATT:UpdateAllAnchors() end)
	hidden:SetPoint("LEFT",lock,"RIGHT",32,0)
	
	local glow = panel:MakeToggle(	
		'name', 'Glow Icons',	
		'description', 'Glow icons blizzard style\nwhen ability is active',	
		'default', true,	
		'getFunc', function() return db.Glow end,	
		'setFunc', function(value) db.Glow = value ATT:UpdateAllAnchors()end)
	glow:SetPoint("LEFT",hidden,"RIGHT",60,0)

	local growLeft = panel:MakeToggle(	
		'name', 'Grow Left',	
		'description', 'Grow icons to the left',	
		'default', false,	
		'getFunc', function() return db.growLeft end,	
		'setFunc', function(value) db.growLeft = value ATT:LoadPositions() end)
	growLeft:SetPoint("TOPLEFT",attach,"TOPLEFT",0,-25)
	
	local tworows = panel:MakeToggle(	
		'name', 'Two rows',	
		'description', 'Show icons on two rows',	
		'default', false,	
		'getFunc', function() return db.tworows end,	
		'setFunc', function(value) db.tworows = value ATT:LoadPositions() ATT:UpdateAllAnchorIcons() end)
	tworows:SetPoint("LEFT",growLeft,"RIGHT",60,0)
	
	
	local horizontal = panel:MakeToggle(	
		'name', 'Horizontal',	
		'description', 'Show icons under raid frames\n(works when using horizontal group and attached raid frames)',
		'default', false,	
		'getFunc', function() return db.horizontal end,	
		'setFunc', function(value) db.horizontal = value ATT:LoadPositions() end)
	horizontal:SetPoint("LEFT",tworows,"RIGHT",60,0)
	
	local showIconBorders = panel:MakeToggle(	
		'name', 'Draw borders',	
		'description', 'Draw borders around icons',	
		'default', true,	
		'getFunc', function() return db.showIconBorders end,	
		'setFunc', function(value) db.showIconBorders = value ATT:UpdateAllAnchors() end)
	showIconBorders:SetPoint("LEFT",horizontal,"RIGHT",65,0)
	
	local arena = panel:MakeToggle(	
		'name', 'Arena',	
		'description', 'Enable icons in Arena',	
		'default', false,	
		'getFunc', function() return db.arena end,	
		'setFunc', function(value) db.arena = value ZoneSet() end)
	arena:SetPoint("TOPLEFT",growLeft,"TOPLEFT",0,-45)
	
	local dungeons = panel:MakeToggle(	
		'name', 'Dungeons',	
		'description', 'Enable icons in Dungeons',	
		'default', false,	
		'getFunc', function() return db.dungeons end,	
		'setFunc', function(value) db.dungeons = value ZoneSet() end)
	dungeons:SetPoint("LEFT",arena,"RIGHT",40,0)
	
	local inraid = panel:MakeToggle(	
		'name', 'Raid/Bg',	
		'description', 'Enable icons in Raid / BGs\n(only works for your group)',
		'default', false,	
		'getFunc', function() return db.inraid end,	
		'setFunc', function(value) db.inraid = value ZoneSet() end)
	inraid:SetPoint("LEFT",dungeons,"RIGHT",65,0)
		
	local outside = panel:MakeToggle(	
		'name', 'Outside World',	
		'description', 'Enable icons in Outside World',	
		'default', false,	
		'getFunc', function() return db.outside end,	
		'setFunc', function(value) db.outside = value ZoneSet() end)
	outside:SetPoint("LEFT",inraid,"RIGHT",60,0)
	
	local showTrinket = panel:MakeToggle(	
		'name', 'Trinket',	
		'description', 'Show PvP Trinket',	
		'default', false,	
		'getFunc', function() return db.showTrinket end,	
		'setFunc', function(value) db.showTrinket = value ATT:UpdateAllAnchors() end)
	showTrinket:SetPoint("TOPLEFT",arena,"TOPLEFT",0,-45)
	
	local showRacial = panel:MakeToggle(	
		'name', 'Racial',	
		'description', 'Show Racial icons',	
		'default', false,	
		'getFunc', function() return db.showRacial end,	
		'setFunc', function(value) db.showRacial = value ATT:UpdateAllAnchors() end)
	showRacial:SetPoint("LEFT",showTrinket,"RIGHT",50,0)
	
	local showTooltip = panel:MakeToggle(	
		'name', 'Show Tooltip',	
		'description', 'Show tooltips over icons',
		'default', false,	
		'getFunc', function() return db.showTooltip end,	
		'setFunc', function(value) db.showTooltip = value end)
	showTooltip:SetPoint("LEFT",showRacial,"RIGHT",70,0)
		
	local title2, subText2 = panel:MakeTitleTextAndSubText("","Enable in:")
	title2:ClearAllPoints()
	title2:SetPoint("TOPLEFT",panel,"TOPLEFT",20,-110)
	
	local title2, subText2 = panel:MakeTitleTextAndSubText("","Show:")
	subText2:ClearAllPoints()
	subText2:SetPoint("TOPLEFT",panel,"TOPLEFT",20,-160)
	
	self:CreateAbilityEditor()
end

local function count(t) local i = 0 for k,v in pairs(t) do i = i + 1  end return i end

function ATT:UpdateScrollBar()
	local btns = self.btns
	local scrollframe = self.scrollframe
	local classSelectedSpecs = db.abilities[db.classSelected] 
	local line = 1
	
	if not btns then return end
	
	for specID, abilities in pairs(classSelectedSpecs) do
		for abilityIndex, abilityTable in pairs(abilities) do
			local ability, id, cooldown, talent, spellStatus = abilityTable.ability, abilityTable.id, abilityTable.cooldown, abilityTable.talent, abilityTable.spellStatus
			local order = abilityTable.order or 1	
			spectexture  =  "Interface\\Buttons\\UI-MicroButton-"..db.classSelected
			abilitytexture = self:FindAbilityIcon(ability, id)
			
			if spellStatus ~= "DISABLED" then
				btns[line]:SetText("   |T"..(abilitytexture or "")..":18|t " ..ability)
			else
				btns[line]:SetText("   |cff808080|T"..(abilitytexture or "")..":18|t " ..ability.."|r")
			end
			
			if btns[line]:GetText() ~= scrollframe.currentButton then
				btns[line]:SetNormalTexture("")
			else 
				btns[line]:SetNormalTexture("Interface\\ContainerFrame\\UI-Icon-QuestBorder")
				btns[line]:GetNormalTexture():SetTexCoord(0.11,0.88,0.02,0.97)
				btns[line]:GetNormalTexture():SetBlendMode("ADD") 
				scrollframe.addeditbox:SetText(ability)
				scrollframe.ideditbox:SetText(id or "")
				scrollframe.cdeditbox:SetText(cooldown or "")
				scrollframe.order:SetValue(tostring(order or 1))
				
				scrollframe.dropdown2.initialize()
				scrollframe.dropdown2:SetValue(tostring(specID or "ALL"))
				
				scrollframe.spellStatusbox.initialize()
				scrollframe.spellStatusbox:SetValue(tostring(spellStatus or "ENABLED"))
			end
			
			btns[line]:Show()
			line = line + 1
		end 
	end 			
	 for i=line,25 do btns[i]:Hide() end
end

function ATT:getSpecs()
	local classSpecs = dbSpecs[db.classSelected]
	local specs = {"ALL", "All specs"}
	for specName,_ in pairs(classSpecs) do
		table.insert(specs, specName)
		table.insert(specs, specName)
	end
	
	return specs
end

function ATT:CreateAbilityEditor()
	local panel = self.panel
	local btns = {}
	self.btns = btns
	local scrollframe = CreateFrame("ScrollFrame", "ATTScrollFrame",panel,"UIPanelScrollFrameTemplate")
	local child = CreateFrame("ScrollFrame" ,"ATTScrollFrameChild" , scrollframe )
	child:SetSize(1, 1)
	scrollframe:SetScrollChild(child)
	local button1 = CreateListButton(child,"25")
	button1:SetPoint("TOPLEFT",child,"TOPLEFT",2,0)
	btns[#btns+1] = button1
	for i=2,25 do
		local button = CreateListButton(child,tostring(i))
		button:SetPoint("TOPLEFT",btns[#btns],"BOTTOMLEFT")
		btns[#btns+1] = button
	end
	scrollframe:SetScript("OnShow",function(self) if not db.classSelected then db.classSelected = "WARRIOR" end ATT:UpdateScrollBar()  end)
	self.scrollframe = child
	
	scrollframe:SetSize(130,176)
	scrollframe:SetPoint('LEFT',10,-100)
	child.dropdown2 = nil
   
	local dropdown = panel:MakeDropDown(
	   'name', ' Class',
		'description', 'Pick a class to edit abilities',
		'values', {
			"WARRIOR", "Warrior",
			"PALADIN", "Paladin",
			"PRIEST", "Priest",
			"SHAMAN", "Shaman",
			"DRUID", "Druid",
			"ROGUE", "Rogue",
			"MAGE", "Mage",
			"WARLOCK", "Warlock",
			"HUNTER", "Hunter",
			"DEATHKNIGHT", "DeathKnight",
		 },
		'default', 'WARRIOR',
		'getFunc', function() return db.classSelected end ,
		'setFunc', function(value)
			db.classSelected = value
			ATT:UpdateScrollBar()
			child.dropdown2.initialize()
			child.dropdown2:SetValue("ALL")
			child.dropdown2.values = ATT:getSpecs()
		end)
	dropdown:SetPoint("TOPLEFT",scrollframe,"TOPRIGHT",15,-8)
	child.dropdown = dropdown  	
	
	local dropdown2 = panel:MakeDropDown(
	   'name', ' Specialization',
		'description', 'Pick a spec',
		'values', ATT:getSpecs(),
		'default', 'ALL',
		'current', 'ALL',
		'setFunc', function(value) end
	)
	
	dropdown2:SetPoint("TOPLEFT",dropdown,"BOTTOMLEFT",0,-15)
	child.dropdown2 = dropdown2
	
	local spellStatusbox = panel:MakeDropDown(
	   'name', ' Status',
		'description', 'Enable or disable ability',
		'values', {
					"ENABLED", "Enabled",
					"DISABLED", "Disabled",
		 },
		'default', 'ENABLED',
		'current', 'ENABLED',
		'setFunc', function(value) end)
	spellStatusbox:SetPoint("TOPLEFT",dropdown,"BOTTOMLEFT",115,30)
	child.spellStatusbox = spellStatusbox

	local addeditbox = CreateEditBox("Ability Name",scrollframe,90,25)
	child.addeditbox = addeditbox	
	addeditbox:SetPoint("TOPLEFT",dropdown2,"BOTTOMLEFT",20,-15)

	local ideditbox = CreateEditBox("Ability ID",scrollframe,70,25)
	ideditbox:SetPoint("LEFT",addeditbox,"RIGHT",7,0)
	child.ideditbox = ideditbox

	local cdeditbox = CreateEditBox("CD (s)",scrollframe,40,25)
	cdeditbox:SetPoint("LEFT",ideditbox,"RIGHT",7,0)
	child.cdeditbox = cdeditbox
	
	local order = panel:MakeSlider(	
		'name', 'Icon Order',	
		'description', 'Adjust icon order priority\nAll Specs icons are always first',
		'minText', '1',
		'maxText', '6',
		'minValue', 1,
		'maxValue', 6,
		'step', 1,
		'vertical', 1,
		'default', 1,
		'current',  1,
		'setFunc', function() end,	
		'currentTextFunc', function(value) return string.format("%.0f",value) end)
	order:SetPoint("LEFT",dropdown2,"RIGHT",0,5)
	order:SetWidth(100)
	child.order = order

	local addbutton = panel:MakeButton(	
		'name', 'Add/Update',	
		'description', "Add / Update ability",	
		'func', function() 	
			local id = ideditbox:GetText():match("^[0-9]+$")
			local spec = dropdown2.value	
			local ability = addeditbox:GetText()
			local iconfound = ATT:FindAbilityIcon(ability, id)
			local cdtext = cdeditbox:GetText():match("^[0-9]+$")
			local spellStatus = spellStatusbox.value	
			local order = string.format("%.0f",order.value)
			if iconfound and cdtext and id and (not spec or db.abilities[db.classSelected] and db.abilities[db.classSelected][spec]) then	
				print("Added/Updated: |cffFF4500"..ability.."|r")
				local abilities = db.abilities[db.classSelected][spec or "ALL"]	
				local _ability, _index = self:FindAbilityByName(abilities, ability)
				if _ability and _index then	
					-- editing:	
					abilities[_index] = {ability = ability, cooldown = tonumber(cdtext), id = tonumber(id), spellStatus = spellStatus and tostring(spellStatus), order = tonumber(string.format("%.0f",order)) }	
				else	
					-- adding new:	
					table.insert(abilities, {ability = ability, cooldown = tonumber(cdtext), id = tonumber(id), spellStatus = spellStatus and tostring(spellStatus), order = tonumber(string.format("%.0f",order))  })
				end
			table.sort(abilities, function(a, b) 	
			if (a.order or 1) == (b.order or 1) then	
			return (a.id) < (b.id) end
			return (a.order or 1) < (b.order or 1) end)	
				child.currentButton = ability	
				ATT:UpdateScrollBar()
				ATT:UpdateAllAnchors()
			else	
				print("Invalid/blank:|cffFF4500 Ability Name, ID or Cooldown|r")
			end
	end)
	addbutton:SetPoint("TOPLEFT",addeditbox,"BOTTOMLEFT",-5,-20)
	
	local removebutton = panel:MakeButton(	
		'name', 'Remove',
		'description', 'Remove ability',
		'func', function()
	     		local spec = dropdown2.value
	     		local _ability, _index = self:FindAbilityByName(db.abilities[db.classSelected][spec or "ALL"], addeditbox:GetText())
	     		if _ability and _index then
					table.remove(db.abilities[db.classSelected][spec], _index)
					print("Removed ability |cffFF4500" .. addeditbox:GetText().."|r")
					addeditbox:SetText("");
					ideditbox:SetText("");
					cdeditbox:SetText("");
					order:SetValue(1)
					child.currentButton = nil;
					ATT:UpdateScrollBar();
					ATT:UpdateAllAnchors()
				else
					print("Invalid/blank:|cffFF4500 Ability ID|r")
				end
	end)
	removebutton:SetPoint("TOPLEFT",addeditbox,"BOTTOMLEFT",120,-20)
	removebutton:SetWidth(100)
end

ATT:RegisterEvent("VARIABLES_LOADED")
ATT:SetScript("OnEvent",ATT_OnLoad)