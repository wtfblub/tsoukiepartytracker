local AddOn, TPT, Private = select(2, ...):Init()

TPT.Options = {}

local floor = math.floor
local sformat = string.format
local match = string.match
local remove = table.remove
local insert = table.insert
local tonumber = tonumber
local tostring = tostring
local GetSpellInfo = GetSpellInfo
local GetSpellTexture = C_GetSpellTexture or GetSpellTexture
local LOCALIZED_CLASS_NAMES_MALE = LOCALIZED_CLASS_NAMES_MALE

local function UpdateAllAnchorIcons()
	if ( TPT.PARTY_NUM > 0 ) then
		for i=1, TPT.PARTY_NUM do
			TPT:IconUpdate(i)
		end
	end
end

local function UpdateAllAnchors()
	if ( TPT.PARTY_NUM > 0 ) then
		for i=1, TPT.PARTY_NUM do
			TPT:AnchorUpdate(i)
		end

		TPT:AnchorUpdatePosition()
	end
end

local function FindAbilityByName(Abilities, Name)
	if ( Abilities ) then
		for i, v in pairs(Abilities) do
			if ( v and TPT.Default.SpellName[v[1]] == Name ) then
				return v, i
			end
		end
	end
end

local function ListButtonOnClick(Self)
	Self:GetParent().currentButton = Self.index
	TPT.Options:UpdateScrollBar()
end

local function CreateListButton(parent, index)
	local name = parent:GetName()..index

	local button = CreateFrame("Button", name, parent)
		button:SetWidth(150)
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
	TPT.DB[setting] = value
	TPT:GROUP_ROSTER_UPDATE(1)
end

local function SettingsPrint(title, msg)
	print(title, ": |cffFF4500", msg)
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
	if ( TPT.DB.Attach ) then
		panel.offsetX:SetAlpha(1)
		panel.offsetY:SetAlpha(1)
		panel.horiz:SetAlpha(1)
		panel.offsetX:Enable()
		panel.offsetY:Enable()
		panel.horiz:Enable()

		panel.lock:SetChecked(1)
		panel.lock:SetAlpha(0.5)
		panel.lock:Disable()
		TPT.DB.Lock = 1
	else
		panel.offsetX:SetAlpha(0.5)
		panel.offsetY:SetAlpha(0.5)
		panel.horiz:SetAlpha(0.5)
		panel.offsetX:Disable()
		panel.offsetY:Disable()
		panel.horiz:Disable()

		if ( TPT.DB.Lock == 1 ) then
			panel.lock:SetChecked(0)
			panel.lock:SetAlpha(1)
			panel.lock:Enable()
			TPT.DB.Lock = nil
		end
	end

	TPT.Anchors:Lock()
end

local function RowToggle(panel)
	if ( TPT.DB.Rows ) then
		panel.spacingY:SetAlpha(1)
		panel.spacingY:Enable()
	else
		panel.spacingY:SetAlpha(0.5)
		panel.spacingY:Disable()
	end
end

local function UpdateOrder(c)
	local Panel = TPT.scrollframe
	local Num = #TPT.DB.Spells[TPT.DB.SelClass]
	_G[Panel.order:GetName() .. "High"]:SetText(tostring(Num))
	Panel.order:SetMinMaxValues(1, Num)
end

local function NULL() end

function TPT.Options.UpdateScrollBar()
	local self = TPT
	local scrollframe = self.scrollframe
	local btns = self.btns
	local line = 1

	for Index, Spell in pairs(TPT.DB.Spells[TPT.DB.SelClass]) do
		local btn = btns[line]
		local ability, id, cooldown, spellStatus = TPT.Default.SpellName[Spell[1]], Spell[1], Spell[2], Spell[3]	
		local abilitytexture = GetSpellTexture(id)

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
			scrollframe.order:SetValue(line)

			scrollframe.status.initialize()
			scrollframe.status:SetValue(tostring(spellStatus == false and "false" or "true"))
		end

		btn:Show()
		line = line + 1
	end 			

	-- Button Overflow
	for i=line, #self.btns do btns[i]:Hide() end
end

local function CreateAbilityEditor()
	local self = TPT
	local panel = self.panel
	self.btns = {}

	if ( not TPT.DB.SelClass ) then
		TPT.DB.SelClass = "WARRIOR"
	end

	local scrollframe = CreateFrame("ScrollFrame", "TPTScrollFrame", panel, "UIPanelScrollFrameTemplate")
	local child = CreateFrame("ScrollFrame" ,"TPTScrollFrameChild" , scrollframe)
	scrollframe:SetScrollChild(child)
	child:SetSize(1, 1)
	self.scrollframe = child

	scrollframe:SetSize(150, 126)
	scrollframe:SetPoint("TOPLEFT", 15, -285)

	local class = panel:MakeDropDown(
		"name", "",
		"description", "Pick a class to edit abilities.",
		"values", GetLocalClassList(),
		"default", 'WARRIOR',
		"getFunc", function() return TPT.DB.SelClass end,
		"setFunc", function(value)
			TPT.DB.SelClass = value
			UpdateOrder()
			child.currentButton = 1
			scrollframe:SetVerticalScroll(0)
			TPT.Options:UpdateScrollBar()
		end)
	class:SetPoint("TOP", scrollframe, "TOP", 0, 30)
	child.class = class

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
	status:SetPoint("TOPLEFT", scrollframe, "TOPRIGHT", 15, -15)
	child.status = status

	local ideditbox = CreateEditBox("Spell ID", scrollframe, 55, 25)
	ideditbox:SetPoint("TOPLEFT", status, "BOTTOMLEFT", 25, -12)
	child.ideditbox = ideditbox

	local cdeditbox = CreateEditBox("CD (s)", scrollframe, 35, 25)
	cdeditbox:SetPoint("LEFT", ideditbox, "RIGHT", 7, 0)
	child.cdeditbox = cdeditbox

	local groupedCDList = '|cFFFFFFFFAbilities with same ID share a cooldown.\n\n|cFFFF0000Example: Pummel will trigger Shield Bash.|r\n'
	for class, spells in pairs(TPT.Default.Shared) do
		groupedCDList = groupedCDList.."\n"..class.."\n"
		for Spell, Type in pairs(spells) do
			groupedCDList = groupedCDList..Type.." - "..Spell.."\n"
		end
	end

	local groupedCD = panel:MakeButton(
		'name', '|TInterface\\DialogFrame\\UI-Dialog-Icon-AlertNew:16|t Grouped Spells',
		'description', groupedCDList,
		'func', NULL)
	groupedCD:SetPoint("TOP", ideditbox, "BOTTOM", 20, 2)
	groupedCD:SetNormalTexture(nil)
	groupedCD:SetPushedTexture(nil)

	local order = panel:MakeSlider(	
		'name', 'Icon Order',
		'description', 'Adjust icon order.',
		'minText', '1',
		'maxText', '~',
		'minValue', 1,
		'maxValue', 1,
		'step', 1,
		'default', 1,
		'current',  1,
		'setFunc', NULL,
		'currentTextFunc', function(value) return value end)
	order:SetPoint("LEFT", cdeditbox, "RIGHT", 13, 1)
	order:SetWidth(80)
	child.order = order

	local updatebtn = panel:MakeButton(
		'name', 'Add/Update',
		'description', "Add / Update Ability",
		'func', function()
			local _, SpellName, SpellIcon, SpellCD, SpellStatus, SpellOrder
			local SpellID = ideditbox:GetText():match("^[0-9]+$")

			if ( SpellID ) then
				SpellCD = cdeditbox:GetText():match("^[0-9]+$")

				if ( SpellCD ) then
					SpellName, _, SpellIcon = GetSpellInfo(SpellID)
					SpellStatus = status.value
					SpellOrder = order.value

					if ( SpellIcon and SpellName ) then
						SettingsPrint("Added/Updated", SpellName)

						local Abilities = TPT.DB.Spells[TPT.DB.SelClass]
						local AbilityNameExist, AbilityIndexExist = FindAbilityByName(Abilities, SpellName)

						-- Updated/New Data
						local SpellID = tonumber(SpellID)
						local Data = {SpellID, tonumber(SpellCD)}

						if ( SpellStatus == "false" ) then
							Data[3] = false
						end

						-- Save it
						if ( AbilityIndexExist and AbilityIndexExist == SpellOrder ) then
							Abilities[AbilityIndexExist] = Data -- Soft Replace
						else
							if ( AbilityIndexExist and AbilityIndexExist ~= SpellOrder ) then
								remove(Abilities, AbilityIndexExist) -- New order, remove prev
							end
							insert(Abilities, SpellOrder, Data)
						end

						TPT.Default.SpellName[SpellID] = SpellName

						child.currentButton = SpellName
						UpdateOrder()
						TPT.Options:UpdateScrollBar()
						UpdateAllAnchors()

						return
					end
				end
			end

			SettingsPrint("Invalid/Blank", "ID or Cooldown")
	end)
	updatebtn:SetPoint("TOP", ideditbox, "BOTTOM", 20, -20)
	updatebtn:SetWidth(112)

	local removebtn = panel:MakeButton(
		'name', 'Remove',
		'description', 'Remove Ability',
		'func', function()
			local SpellName = GetSpellInfo(ideditbox:GetText())
			local AbilityNameExist, AbilityIndexExist = FindAbilityByName(TPT.DB.Spells[TPT.DB.SelClass], SpellName)

			if ( AbilityNameExist and AbilityIndexExist ) then
				remove(TPT.DB.Spells[TPT.DB.SelClass], AbilityIndexExist)
				TPT.Default.SpellName[AbilityNameExist[1]] = nil

				child.currentButton = 1
				UpdateOrder()
				TPT.Options:UpdateScrollBar()
				UpdateAllAnchors()

				SettingsPrint("Removed Ability", SpellName)
			else
				SettingsPrint("Invalid/Blank", "Ability ID")
			end
	end)
	removebtn:SetPoint("LEFT", updatebtn, "RIGHT", 5, 0)
	removebtn:SetWidth(85)
end

function TPT.Options.Build(Self)
	local panel = Self
	local self = TPT
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
	local bg = CreateOptionBG(panel, 403, 20, "Interface\\BUTTONS\\UI-Listbox-Highlight")
	bg:SetPoint("TOPLEFT", panel, "TOPLEFT", 5, -259)

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
		'getFunc', function() return TPT.DB.Attach end,
		'setFunc', function(value)
			TPT.DB.Attach = value
			AttachToggle(panel)
			TPT:AnchorUpdatePosition()
		end)
	attach:SetPoint("TOPLEFT", panel, "TOPLEFT", 330, -10)

	-- Lock
	local lock = panel:MakeToggle(
		'name', 'Lock',
		'description', 'Lock anchors from being draggable.',
		'default', false,
		'getFunc', function() return TPT.DB.Lock end,
		'setFunc', function(value) TPT.DB.Lock = value TPT.Anchors:Lock() end)
	lock:SetPoint("RIGHT", attach, "LEFT", -40, 0)
	panel.lock = lock

--[[

DISPLAY

]]

	-- Scale
	local scale = panel:MakeSlider(
		'name', 'Scale',
		'description', 'Adjust the scale of icons.',
		'minText', '-',
		'maxText', '+',
		'minValue', 0.3,
		'maxValue', 5,
		'step', 0.01,
		'default', 1,
		'current', TPT.DB.Scale,
		'currentTextFunc', function(value) return sformat("%.1f", value) end,
		'setFunc', function(value) TPT.DB.Scale = value TPT.Icons:SetScale(TPT.DB.Scale) end)
	scale:SetPoint("TOPLEFT", panel, "TOPLEFT", 25, -55)
	scale:SetWidth(90)

	local hidden = panel:MakeToggle(
		'name', 'Hidden',
		'description', 'Only show icon on cooldown.',
		'default', false,
		'getFunc', function() return TPT.DB.Hidden end,
		'setFunc', function(value) TPT.DB.Hidden = value UpdateAllAnchors() end)
	hidden:SetPoint("TOPLEFT", scale, "TOPLEFT", 120, 5)

	local glow = panel:MakeToggle(
		'name', 'Glow',
		'description', 'Glow icon when active.',
		'default', true,
		'getFunc', function() return TPT.DB.Glow end,
		'setFunc', function(value) TPT.DB.Glow = value end)
	glow:SetPoint("LEFT", hidden, "RIGHT", CheckOffsetX, 0)

	local border = panel:MakeToggle(
		'name', 'Border',
		'description', 'Borders around icons.',
		'default', true,
		'getFunc', function() return TPT.DB.Border end,
		'setFunc', function(value) TPT.DB.Border = value UpdateAllAnchors() end)
	border:SetPoint("LEFT", glow, "RIGHT", CheckOffsetX, 0)

	local left = panel:MakeToggle(
		'name', 'Grow Left',
		'description', 'Grow icons to the left.',
		'default', false,
		'getFunc', function() return TPT.DB.Left end,
		'setFunc', function(value) TPT.DB.Left = value UpdateAllAnchors() end)
	left:SetPoint("TOPLEFT", scale, "TOPLEFT", 0, -25)
	
	local rows = panel:MakeToggle(
		'name', 'Two Rows',
		'description', 'Show icons on two rows.',
		'default', false,
		'getFunc', function() return TPT.DB.Rows end,
		'setFunc', function(value)
			TPT.DB.Rows = value
			RowToggle(panel)
			UpdateAllAnchorIcons()
		end)
	rows:SetPoint("LEFT", left, "RIGHT", CheckOffsetX + 20, 0)

	local horiz = panel:MakeToggle(
		'name', 'Horizontal',
		'description', 'Show icons under attached frame.',
		'default', false,
		'getFunc', function() return TPT.DB.Horiz end,
		'setFunc', function(value) TPT.DB.Horiz = value TPT:AnchorUpdatePosition() end)
	horiz:SetPoint("LEFT", rows, "RIGHT", CheckOffsetX + 20, 0)
	panel.horiz = horiz

	local tooltip = panel:MakeToggle(
		'name', 'Tooltip',
		'description', 'Show tooltips on mouseover.',
		'default', false,
		'getFunc', function() return TPT.DB.Tooltip end,
		'setFunc', function(value) TPT.DB.Tooltip = value end)
	tooltip:SetPoint("LEFT", horiz, "RIGHT", CheckOffsetX + 20, 0)

--[[

OFFSETS

]]

	local offsetX = panel:MakeSlider(
		'name', 'X Offset',
		'description', 'X Offset.',
		'minText', '',
		'maxText', '',
		'minValue', -50,
		'maxValue', 50,
		'step', 0.01,
		'default', 1,
		'current', TPT.DB.OffX,
		'setFunc', function(value) TPT.DB.OffX = value TPT:AnchorUpdatePosition() end,
		'currentTextFunc', function(value) return floor(value) end)
	offsetX:SetPoint("TOP", left, "BOTTOM", 25, -30)
	offsetX:SetWidth(SliderWidth)
	panel.offsetX = offsetX

	local offsetY = panel:MakeSlider(
		'name', 'Y Offset',
		'description', 'Y Offset.',
		'minText', '',
		'maxText', '',
		'minValue', -50,
		'maxValue', 50,
		'step', 0.01,
		'default', 1,
		'current', TPT.DB.OffY,
		'setFunc', function(value) TPT.DB.OffY = value TPT:AnchorUpdatePosition() end,
		'currentTextFunc', function(value) return floor(value) end)
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
		'current', TPT.DB.SpaceX,
		'setFunc', function(value) TPT.DB.SpaceX = value UpdateAllAnchorIcons() end,
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
		'current', TPT.DB.SpaceY,
		'setFunc', function(value) TPT.DB.SpaceY = value UpdateAllAnchorIcons() end,
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
		'getFunc', function() return TPT.DB.Arena end,
		'setFunc', function(value) ZoneSet("Arena", value) end)
	arena:SetPoint("TOP", offsetX, "BOTTOM", -25, -27)

	local dungeon = panel:MakeToggle(
		'name', 'Dungeon',
		'description', 'Enable in Dungeon.',
		'default', false,
		'getFunc', function() return TPT.DB.Dungeon end,
		'setFunc', function(value) ZoneSet("Dungeon", value) end)
	dungeon:SetPoint("LEFT", arena, "RIGHT", 40, 0)

	local raid = panel:MakeToggle(
		'name', 'Raid/BG',
		'description', 'Enable in Raid/Battleground.\n\n|cFFFFFFFFOnly works for your group!',
		'default', false,
		'getFunc', function() return TPT.DB.Raid end,
		'setFunc', function(value) ZoneSet("Raid", value) end)
	raid:SetPoint("LEFT", dungeon, "RIGHT", 65, 0)

	local world = panel:MakeToggle(
		'name', 'World',
		'description', 'Enable in World.',
		'default', false,
		'getFunc', function() return TPT.DB.World end,
		'setFunc', function(value) ZoneSet("World", value) end)
	world:SetPoint("LEFT", raid, "RIGHT", 60, 0)

--[[

TRINKET/RACIAL

]]

	local showTrinket = panel:MakeToggle(
		'name', 'Trinket',
		'description', 'Show PvP Trinket icon.',
		'default', false,
		'getFunc', function() return TPT.DB.Trinket end,
		'setFunc', function(value) TPT.DB.Trinket = value UpdateAllAnchors() end)
	showTrinket:SetPoint("TOP", world, "BOTTOM", -10, -15)

	local showRacial = panel:MakeToggle(
		'name', 'Racial',
		'description', 'Show Racial icon.',
		'default', false,
		'getFunc', function() return TPT.DB.Racial end,
		'setFunc', function(value) TPT.DB.Racial = value UpdateAllAnchors() end)
	showRacial:SetPoint("LEFT", showTrinket, "RIGHT", 50, 0)

	AttachToggle(panel)
	RowToggle(panel)

	CreateAbilityEditor()
end