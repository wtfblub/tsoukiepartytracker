if ( WOW_PROJECT_ID_RCE ~= WOW_PROJECT_BURNING_CRUSADE_CLASSIC ) then
	return
end

local AddOn, TPT, Private = select(2, ...):Init()

TPT.Version = 2.1
TPT.Default = {}

TPT.Default.Spells = {
	["DRUID"] = {
		{29166, 360}, -- Innervate
		{22812, 60}, -- Barkskin
		{5211, 60}, -- Bash
		{22842, 180}, -- Frenzied Regeneration
		{740, 600}, -- Tranquility
		{1850, 300}, -- Dash

		{16689, 60}, -- Nature's Grasp
		{33831, 180}, -- Force of Nature

		{16979, 15}, -- Feral Charge

		{17116, 180}, -- Nature's Swiftness
		{18562, 15}, -- Swiftmend
	},
	["HUNTER"] = {
		{1499, 30}, -- Freezing Trap
		{3045, 300}, -- Rapid Fire
		{34600, 30}, -- Snake Trap
		{1513, 30}, -- Scare Beast
		{1543, 20}, -- Flare

		{19574, 120}, -- Bestial Wrath
		{19577, 60}, -- Intimidation

		{34490, 20}, -- Silencing Shot
		{19503, 30}, -- Scatter Shot

		{19386, 120}, -- Wyvern Sting
		{19263, 300}, -- Deterrence
		{23989, 300}, -- Readiness
	},
	["MAGE"] = {
		{2139, 24}, -- Counterspell
		{122, 25}, -- Frost Nova
		{1953, 15}, -- Blink
		{12051, 480}, -- Evocation
		{45438, 300}, -- Ice Block

		{12043, 180}, -- Presence of Mind
		{12042, 180}, -- Arcane Power

		{11113, 30}, -- Blast Wave
		{11129, 180}, -- Combustion
		{31661, 20}, -- Dragon's Breath

		{11958, 480}, -- Cold Snap
		{12472, 180}, -- Icy Veins
	},
	["PALADIN"] = {
		{853, 60}, -- Hammer of Justice
		{1044, 25}, -- Blessing of Freedom
		{6940, 30}, -- Blessing of Sacrifice
		{1022, 300}, -- Blessing of Protection
		{498, 300}, -- Divine Protection
		{642, 300}, -- Divine Shield
		{31884, 180}, -- Avenging Wrath

		{20216, 120}, -- Divine Favor
		{31842, 180}, -- Divine Illumination

		{20925, 10}, -- Holy Shield
		{31935, 30}, -- Avenger's Shield

		{20066, 60}, -- Repentance
	},
	["PRIEST"] = {
		{6346, 180}, -- Fear Ward
		{8122, 30}, -- Psychic Scream
		{34433, 300}, -- Shadowfiend
		{32379, 12}, -- Shadow Word: Death
		{13908, 600}, -- Desperate Prayer
		{2651, 180}, -- Elune's Grace
		{13896, 180}, -- Feedback

		{10060, 180}, -- Power Infusion
		{33206, 120}, -- Pain Suppression

		{724, 360}, -- Lightwell

		{15487, 45}, -- Silence
		{15286, 10}, -- Vampiric Embrace
	},
	["ROGUE"] = {
		{1766, 10}, -- Kick
		{2094, 180}, -- Blind
		{408, 20}, -- Kidney Shot
		{5277, 300}, -- Evasion
		{1857, 300}, -- Vanish
		{31224, 60}, -- Cloak of Shadows

		{14177, 180}, -- Cold Blood

		{13877, 120}, -- Blade Flurry
		{13750, 300}, -- Adrenaline Rush
		{14251, 6}, -- Riposte

		{14185, 600}, -- Preparation
		{36554, 30}, -- Shadowstep
	},
	["SHAMAN"] = {
		{8042, 6}, -- Earth Shock
		{8177, 15}, -- Grounding Totem
		{2484, 15}, -- Earthbind Totem

		{16166, 180}, -- Elemental Mastery

		{30823, 120}, -- Shamanistic Rage

		{16188, 180}, -- Nature's Swiftness
		{16190, 300}, -- Mana Tide Totem
	},
	["WARLOCK"] = {
		{6789, 120}, -- Death Coil
		{19244, 24}, -- Spell Lock
		{19505, 8}, -- Devour Magic
		{5484, 40}, -- Howl of Terror
		{6229, 30}, -- Shadow Ward

		{18708, 900}, -- Fel Domination

		{30283, 20}, -- Shadowfury
	},
	["WARRIOR"] = {
		{72, 12}, -- Shield Bash
		{676, 60}, -- Disarm
		{871, 1800}, -- Shield Wall
		{1719, 1800}, -- Recklessness
		{2565, 5}, -- Shield Block
		{3411, 30}, -- Intervene
		{5246, 180}, -- Intimidating Shout
		{100, 15}, -- Charge
		{18499, 30}, -- Berserker Rage
		{20230, 1800}, -- Retaliation
		{23920, 10}, -- Spell Reflection
		{20252, 30}, -- Intercept

		{12292, 180}, -- Death Wish

		{12328, 30}, -- Sweeping Strikes

		{12809, 45}, -- Concussion Blow
		{12975, 480}, -- Last Stand
	},
}

TPT.Default.Racial = {
-- ALLIANCE
	["Human"] = {20600, 180},
	["Dwarf"] = {20594, 180},
	["NightElf"] = {20580, 10},
	["Gnome"] = {20589, 105},
	["Draenei"] = {28880, 180},

-- HORDE
	["Tauren"] = {20549, 120},
	["Scourge"] = {7744, 120},
	["Orc"] = {20572, 120},
	["Troll"] = {20554, 180},
	["BloodElf"] = {28730, 120},
}

TPT.Default.Trinket = {
	{42292, 120},
	{42292, 120},
}

TPT.Default.Spec = {
-- MULTI
	[16188] = 1, -- Nature's Swiftness

-- WARRIOR
	[12294] = 1, -- Mortal Strike
	[12292] = 1, -- Death Wish
	[12328] = 1, -- Sweeping Strikes
	[23881] = 1, -- Bloodthirst
	[12809] = 1, -- Concussion Blow
	[12975] = 1, -- Last Stand
	[23922] = 1, -- Shield Slam

-- PALADIN
	[20216] = 1, -- Divine Favor
	[20473] = 1, -- Holy Shock
	[31842] = 1, -- Divine Illumination
	[31935] = 1, -- Avenger's Shield
	[20925] = 1, -- Holy Shield
	[20066] = 1, -- Repentance
	[35395] = 1, -- Crusader Strike

-- MAGE
	[12043] = 1, -- Presence of Mind
	[12042] = 1, -- Arcane Power
	[11129] = 1, -- Combustion
	[31661] = 1, -- Dragon's Breath
	[11113] = 1, -- Blast Wave
	[11426] = 1, -- Ice Barrier
	[11958] = 1, -- Cold Snap
	[12472] = 1, -- Icy Veins
	[31687] = 1, -- Summon Water Elemental

-- PRIEST
	[14751] = 1, -- Inner Focus
	[10060] = 1, -- Power Infusion
	[33206] = 1, -- Pain Suppression
	[724] = 1, -- Lightwell
	[15473] = 1, -- Shadowform
	[15286] = 1, -- Vampiric Embrace
	[15487] = 1, -- Silence

-- WARLOCK
	[18288] = 1, -- Amplify Curse
	[18708] = 1, -- Fel Domination
	[30283] = 1, -- Shadowfury
	[17877] = 1, -- Shadowburn
	[17962] = 1, -- Conflagrate

-- ROGUE
	[14177] = 1, -- Cold Blood
	[14251] = 1, -- Riposte
	[13877] = 1, -- Blade Flurry
	[13750] = 1, -- Adrenaline Rush
	[14185] = 1, -- Preparation
	[36554] = 1, -- Shadowstep
	[14278] = 1, -- Ghostly Strike
	[14183] = 1, -- Premeditation

-- DRUID
	[16689] = 1, -- Nature's Grasp
	[33831] = 1, -- Force of Nature
	[16979] = 1, -- Feral Charge
	[16857] = 1, -- Faerie Fire (Feral)
	[18562] = 1, -- Swiftmend

-- SHAMAN
	[16166] = 1, -- Elemental Mastery
	[17364] = 1, -- Stormstrike
	[30823] = 1, -- Shamanistic Rage
	[16190] = 1, -- Mana Tide Totem

-- HUNTER
	[19577] = 1, -- Intimidation
	[19574] = 1, -- Bestial Wrath
	[19434] = 1, -- Aimed Shot
	[34490] = 1, -- Silencing Shot
	[19503] = 1, -- Scatter Shot
	[19306] = 1, -- Counterattack
	[19263] = 1, -- Deterrence
	[19386] = 1, -- Wyvern Sting
	[23989] = 1, -- Readiness
}

TPT.Default.Shared = {
	["SHAMAN"] = {
		[8050] = 1, -- Flame Shock
		[8056] = 1, -- Frost Shock
	},
	["HUNTER"] = {
		[1499] = 1, -- Freezing Trap
		[13809] = 1, -- Frost Trap
		[13813] = 2, -- Explosive Trap
		[13795] = 2, -- Immolation Trap
	},
	["WARRIOR"] = {
		[72] = 1, -- Shield Bash
		[6552] = 1, -- Pummel
		[871] = 2, -- Shield Wall
		[20230] = 2, -- Retaliation
		[1719] = 2, -- Recklessness
	},
	["PALADIN"] = {
		[31884] = 1, -- Avenging Wrath
		[642] = 1, -- Divine Shield
		[498] = 1, -- Divine Protection
		[633] = 1, -- Lay on Hands
	},

	-- SPECIAL SHARED CD(S)
	["CD"] = {
		[72] = 12,
		[6552] = 10,
		[871] = 12,
		[20230] = 12,
		[1719] = 12,
		[31884] = 60,
		[642] = 60,
		[498] = 60,
		[633] = 60,
	},
	["CD_FALLBACK"] = {

	},
}

TPT.Default.Reset = {
	[11958] = { -- Cold Snap
		[120] = 1, -- Cone of Cold
		[122] = 1, -- Frost Nova
		[6143] = 1, -- Frost Ward
		[11426] = 1, -- Ice Barrier
		[45438] = 1, -- Ice Block
		[31687] = 1, -- Summon Water Elemental
		[12472] = 1, -- Icy Veins
	},
	[14185] = { -- Preparation
		[14177] = 1, -- Cold Blood
		[5277] = 1, -- Evasion
		[2983] = 1, -- Sprint
		[1856] = 1, -- Vanish
		[36554] = 1, -- Shadowstep
		[1766] = 1, -- Kick
	},
	[23989] = { -- Readiness
		[3045] = 1, -- Rapid Fire
		[19503] = 1, -- Scatter Shot
		[19574] = 1, -- Bestial Wrath
		[34490] = 1, -- Silencing Shot
		[19263] = 1, -- Deterrence
		[19386] = 1, -- Wyvern Sting
		[5384] = 1, -- Feign Death
		[13809] = 1, -- Frost Trap
		[1499] = 1, -- Freezing Trap
		[13813] = 1, -- Explosive Trap
		[13795] = 1, -- Immolation Trap
		[34600] = 1, -- Snake Trap
	},
}

TPT.Default.Units = {
	["party1"] = 1,
	["party2"] = 2,
	["party3"] = 3,
	["party4"] = 4,
	["partypet1"] = 1,
	["partypet2"] = 2,
	["partypet3"] = 3,
	["partypet4"] = 4,
}