if ( WOW_PROJECT_ID_RCE ~= WOW_PROJECT_WRATH_CLASSIC ) then
	return
end

local AddOn, TPT, Private = select(2, ...):Init()

TPT.Version = 2
TPT.Default = {}

TPT.Default.Spells = {
	["DRUID"] = {
		{29166, 180}, -- Innervate
		{22812, 60}, -- Barkskin
		{5211, 60}, -- Bash
		{1850, 300}, -- Dash
		{16689, 60}, -- Nature's Grasp

		{48505, 60}, -- Starfall
		{50516, 20}, -- Typhoon

		{50334, 180}, -- Berserk
		{16979, 15}, -- Feral Charge - Bear
		{61336, 180}, -- Survival Instincts

		{17116, 180}, -- Nature's Swiftness
		{18562, 13}, -- Swiftmend
	},
	["HUNTER"] = {
		{1499, 28}, -- Freezing Trap
		{3045, 300}, -- Rapid Fire
		{19263, 90}, -- Deterrence
		{34600, 30}, -- Snake Trap
		{53271, 60}, -- Master's Call
		{53480, 60}, -- Roar of Sacrifice

		{19574, 120}, -- Bestial Wrath
		{19577, 60}, -- Intimidation

		{34490, 20}, -- Silencing Shot
		{23989, 180}, -- Readiness

		{19386, 30}, -- Wyvern Sting
		{19503, 30}, -- Scatter Shot
	},
	["MAGE"] = {
		{2139, 24}, -- Counterspell
		{122, 25}, -- Frost Nova
		{1953, 15}, -- Blink
		{12051, 240}, -- Evocation
		{45438, 300}, -- Ice Block

		{12043, 60}, -- Presence of Mind
		{12042, 180}, -- Arcane Power

		{11113, 30}, -- Blast Wave
		{11129, 120}, -- Combustion
		{31661, 20}, -- Dragon's Breath

		{44572, 40}, -- Deep Freeze
		{11958, 384}, -- Cold Snap
		{12472, 180}, -- Icy Veins
	},
	["PALADIN"] = {
		{853, 40}, -- Hammer of Justice
		{1044, 25}, -- Hand of Freedom
		{6940, 120}, -- Hand of Sacrifice
		{1022, 180}, -- Hand of Protection
		{642, 300}, -- Divine Shield
		{31884, 180}, -- Avenging Wrath
		{54428, 60}, -- Divine Plea

		{20216, 120}, -- Divine Favor
		{31821, 120}, -- Aura Mastery
		{31842, 180}, -- Divine Illumination

		{64205, 120}, -- Divine Sacrifice
		{31935, 30}, -- Avenger's Shield

		{20066, 60}, -- Repentance
	},
	["PRIEST"] = {
		{6346, 180}, -- Fear Ward
		{8122, 27}, -- Psychic Scream
		{34433, 300}, -- Shadowfiend
		{32379, 12}, -- Shadow Word: Death
		{19236, 120}, -- Desperate Prayer
		{64843, 480}, -- Divine Hymn
		{64901, 360}, -- Hymn of Hope

		{10060, 96}, -- Power Infusion
		{33206, 144}, -- Pain Suppression

		{47788, 180}, -- Guardian Spirit
		{724, 180}, -- Lightwell

		{47585, 75}, -- Dispersion
		{15487, 45}, -- Silence
		{64044, 120}, -- Psychic Horror
	},
	["ROGUE"] = {
		{1766, 10}, -- Kick
		{2094, 120}, -- Blind
		{408, 20}, -- Kidney Shot
		{5277, 180}, -- Evasion
		{1856, 120}, -- Vanish
		{31224, 60}, -- Cloak of Shadows
		{51722, 60}, -- Dismantle

		{14177, 180}, -- Cold Blood

		{13877, 120}, -- Blade Flurry
		{13750, 180}, -- Adrenaline Rush
		{51690, 120}, -- Killing Spree

		{14185, 300}, -- Preparation
		{51713, 60}, -- Shadow Dance
		{36554, 20}, -- Shadowstep
	},
	["SHAMAN"] = {
		{57994, 5}, -- Wind Shear
		{8177, 15}, -- Grounding Totem
		{2484, 10}, -- Earthbind Totem
		{51514, 45}, -- Hex

		{59159, 35}, -- Thunderstorm
		{16166, 180}, -- Elemental Mastery

		{30823, 60}, -- Shamanistic Rage
		{51533, 180}, -- Feral Spirit

		{16188, 120}, -- Nature's Swiftness
		{16190, 300}, -- Mana Tide Totem
	},
	["WARLOCK"] = {
		{6789, 120}, -- Death Coil
		{19244, 24}, -- Spell Lock
		{19505, 8}, -- Devour Magic
		{5484, 40}, -- Howl of Terror
		{48020, 30}, -- Demonic Circle: Teleport

		{18708, 180}, -- Fel Domination
		{59672, 180}, -- Metamorphosis

		{30283, 20}, -- Shadowfury
	},
	["WARRIOR"] = {
		{72, 12}, -- Shield Bash
		{676, 60}, -- Disarm
		{871, 300}, -- Shield Wall
		{1719, 300}, -- Recklessness
		{2565, 60}, -- Shield Block
		{3411, 30}, -- Intervene
		{5246, 120}, -- Intimidating Shout
		{100, 13}, -- Charge
		{18499, 30}, -- Berserker Rage
		{20230, 300}, -- Retaliation
		{23920, 10}, -- Spell Reflection
		{20252, 15}, -- Intercept
		{55694, 180}, -- Enraged Regeneration

		{46924, 90}, -- Bladestorm

		{12292, 180}, -- Death Wish

		{12809, 30}, -- Concussion Blow
		{12975, 180}, -- Last Stand
		{46968, 17}, -- Shockwave
	},
	["DEATHKNIGHT"] = {
		{47528, 10}, -- Mind Freeze
		{48743, 120}, -- Death Pact
		{49576, 35}, -- Death Grip
		{48707, 45}, -- Anti-Magic Shell
		{47476, 120}, -- Strangulate
		{48792, 120}, -- Icebound Fortitude

		{49016, 180}, -- Unholy Frenzy
		{48982, 40}, -- Rune Tap
		{55233, 60}, -- Vampiric Blood

		{49203, 60}, -- Hungering Cold
		{51271, 60}, -- Unbreakable Armor
		{49039, 120}, -- Lichborne

		{47481, 20}, -- Gnaw
		{49206, 180}, -- Summon Gargoyle
	}
}

TPT.Default.Racial = {
-- ALLIANCE
	["Dwarf"] = {20594, 120},
	["NightElf"] = {58984, 120},
	["Gnome"] = {20589, 60},
	["Draenei"] = {28880, 180},

-- HORDE
	["Tauren"] = {20549, 120},
	["Scourge"] = {7744, 120},
	["Orc"] = {20572, 120},
	["Troll"] = {26297, 180},
	["BloodElf"] = {28730, 120},
}

TPT.Default.Trinket = {
	{42292, 120},
	{59752, 120},
}

TPT.Default.Spec = {
-- MULTI
	[16188] = 1, -- Nature's Swiftness

-- DK
	[48982] = 1, -- Rune Tap
	[49005] = 1, -- Mark of Blood
	[49016] = 1, -- Hysteria / Unholy Frenzy
	[55233] = 1, -- Vampiric Blood
	[49028] = 1, -- Dancing Rune Weapon
	[49039] = 1, -- Lichborne
	[49796] = 1, -- Deathchill
	[51271] = 1, -- Unbreakable Armor
	[49184] = 1, -- Howling Blast
	[49203] = 1, -- Hungering Cold
	[47481] = 1, -- Gnaw
	[49206] = 1, -- Summon Gargoyle
	[51328] = 1, -- Corpse Explosion
	[51052] = 1, -- Anti-Magic Zone
	[63560] = 1, -- Ghoul Frenzy
	[49222] = 1, -- Bone Shield

-- WARRIOR
	[12294] = 1, -- Mortal Strike
	[12328] = 1, -- Sweeping Strikes
	[46924] = 1, -- Bladestorm
	[12809] = 1, -- Concussion Blow
	[12975] = 1, -- Last Stand
	[46968] = 1, -- Shockwave
	[12292] = 1, -- Death Wish
	[23881] = 1, -- Bloodthirst
	[60970] = 1, -- Heroic Fury

-- PALADIN
	[31821] = 1, -- Aura Mastery
	[20216] = 1, -- Divine Favor
	[20473] = 1, -- Holy Shock
	[31842] = 1, -- Divine Illumination
	[31935] = 1, -- Avenger's Shield
	[64205] = 1, -- Divine Sacrifice
	[20925] = 1, -- Holy Shield
	[53595] = 1, -- Hammer of the Righteous
	[20066] = 1, -- Repentance
	[35395] = 1, -- Crusader Strike
	[53385] = 1, -- Divine Storm

-- MAGE
	[12043] = 1, -- Presence of Mind
	[12042] = 1, -- Arcane Power
	[44425] = 1, -- Arcane Barrage
	[11129] = 1, -- Combustion
	[31661] = 1, -- Dragon's Breath
	[11113] = 1, -- Blast Wave
	[44572] = 1, -- Deep Freeze
	[11958] = 1, -- Cold Snap
	[12472] = 1, -- Icy Veins
	[11426] = 1, -- Ice Barrier
	[31687] = 1, -- Summon Water Elemental

-- PRIEST
	[47540] = 1, -- Penance
	[14751] = 1, -- Inner Focus
	[10060] = 1, -- Power Infusion
	[33206] = 1, -- Pain Suppression
	[47585] = 1, -- Dispersion
	[15487] = 1, -- Silence
	[64044] = 1, -- Psychic Horror
	[47788] = 1, -- Guardian Spirit
	[724] = 1, -- Lightwell
	[34861] = 1, -- Circle of Healing
	[19236] = 1, -- Desperate Prayer

-- WARLOCK
	[48181] = 1, -- Haunt
	[18708] = 1, -- Fel Domination
	[47193] = 1, -- Demonic Empowerment
	[59672] = 1, -- Metamorphosis
	[30283] = 1, -- Shadowfury
	[17877] = 1, -- Shadowburn
	[17962] = 1, -- Conflagrate
	[50796] = 1, -- Chaos Bolt

-- ROGUE
	[14177] = 1, -- Cold Blood
	[14251] = 1, -- Riposte
	[13877] = 1, -- Blade Flurry
	[51690] = 1, -- Killing Spree
	[13750] = 1, -- Adrenaline Rush
	[14185] = 1, -- Preparation
	[51713] = 1, -- Shadow Dance
	[36554] = 1, -- Shadowstep
	[14278] = 1, -- Ghostly Strike
	[14183] = 1, -- Premeditation

-- DRUID
	[50334] = 1, -- Berserk
	[49376] = 1, -- Feral Charge - Cat
	[16979] = 1, -- Feral Charge - Bear
	[61336] = 1, -- Survival Instincts
	[48505] = 1, -- Starfall
	[33831] = 1, -- Force of Nature
	[50516] = 1, -- Typhoon
	[18562] = 1, -- Swiftmend
	[48438] = 1, -- Wild Growth

-- SHAMAN
	[51490] = 1, -- Thunderstorm
	[16166] = 1, -- Elemental Mastery
	[17364] = 1, -- Stormstrike
	[60103] = 1, -- Lava Lash
	[51533] = 1, -- Feral Spirit
	[30823] = 1, -- Shamanistic Rage
	[55198] = 1, -- Tidal Force
	[16190] = 1, -- Mana Tide Totem
	[61295] = 1, -- Riptide

-- HUNTER
	[19577] = 1, -- Intimidation
	[19574] = 1, -- Bestial Wrath
	[19434] = 1, -- Aimed Shot
	[53209] = 1, -- Chimera Shot
	[34490] = 1, -- Silencing Shot
	[23989] = 1, -- Readiness
	[19503] = 1, -- Scatter Shot
	[19306] = 1, -- Counterattack
	[19386] = 1, -- Wyvern Sting
	[3674] = 1, -- Black Arrow
	[53301] = 1, -- Explosive Shot
}

TPT.Default.Shared = {
	["DRUID"] = {
		[16979] = 1, -- Feral Charge - Bear
		[49376] = 1, -- Feral Charge - Cat
	},
	["SHAMAN"] = {
		[8042] = 1, -- Earth Shock
		[8050] = 1, -- Flame Shock
		[8056] = 1, -- Frost Shock
	},
	["HUNTER"] = {
		[60192] = 1, -- Freezing Arrow
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
		[31884] = 30,
	},
	["CD_FALLBACK"] = {
		[642] = 120,
		[498] = 120,
		[633] = 120,
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
		[44572] = 1, -- Deep Freeze
		[12472] = 1, -- Icy Veins
	},
	[14185] = { -- Preparation
		[14177] = 1, -- Cold Blood
		[5277] = 1, -- Evasion
		[2983] = 1, -- Sprint
		[1856] = 1, -- Vanish
		[36554] = 1, -- Shadowstep
		[1766] = 1, -- Kick
		[51722] = 1,-- Dismantle
	},
	[23989] = { -- Readiness
		[53271] = 1, -- Master's Call
		[19503] = 1, -- Scatter Shot
		[19574] = 1, -- Bestial Wrath
		[34490] = 1, -- Silencing Shot
		[19263] = 1, -- Deterrence
		[19386] = 1, -- Wyvern Sting
		[5384] = 1, -- Feign Death
		[60192] = 1, -- Freezing Arrow
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