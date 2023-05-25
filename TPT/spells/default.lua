local a, b = ...
b.defaultAbilities = {
	["DRUID"] = {
		["*"] = {
			{29166, 180}, -- Innervate
			{22812, 60}, -- Barkskin
			{8983, 60}, -- Bash
		},
		["Feral"] = {
			{50334, 180}, -- Berserk
			{16979, 15}, -- Feral Charge - Bear
			{61336, 180}, -- Survival Instincts
		},
		["Restoration"] = {
			{17116, 180}, -- Nature's Swiftness
			{18562, 13}, -- Swiftmend
		},
		["Balance"] = {
			{53201, 60}, -- Starfall
			{50516, 20}, -- Typhoon
		}
	},
	["HUNTER"] = {
		["*"] = {
			{3045, 300}, -- Rapid Fire
			{14311, 28}, -- Freezing Trap
			{19263, 90}, -- Deterrence
			{19503, 30}, -- Scatter Shot
			{34600, 30}, -- Snake Trap
			{53271, 60}, -- Master's Call
			{67481, 60}, -- Roar of Sacrifice
		},
		["Beast Mastery"] = {
			{19574, 120}, -- Bestial Wrath
		},
		["Marksmanship"] = {
			{34490, 20}, -- Silencing Shot
			{23989, 180}, -- Readiness
		},
		["Survival"] = {
			{49012, 30}, -- Wyvern Sting
		}
	},
	["MAGE"] = {
		["*"] = {
			{1953, 15}, -- Blink
			{2139, 24}, -- Counterspell
			{12051, 240}, -- Evocation
			{45438, 300}, -- Ice Block
		},
		["Frost"] = {
			{10308, 40}, -- Deep Freeze
			{11958, 384}, -- Cold Snap
		},
		["Fire"] = {
			{11129, 120}, -- Combustion
			{42950, 20}, -- Dragon's Breath
		},
		["Arcane"] = {
			{12043, 60}, -- Presence of Mind
		}
	},
	["PALADIN"] = {
		["*"] = {
			{10308, 40}, -- Hammer of Justice
			{1044, 25}, -- Hand of Freedom
			{54428, 60}, -- Divine Plea
			{6940, 120}, -- Hand of Sacrifice
			{10278, 180}, -- Hand of Protection
			{64205, 120}, -- Divine Sacrifice
			{642, 300}, -- Divine Shield
		},
		["Retribution"] = {
			{66008, 60}, -- Repentance
		},
		["Holy"] = {
			{20216, 120}, -- Divine Favor
			{31821, 120}, -- Aura Mastery
			{31842, 180}, -- Divine Illumination
		},
		["Protection"] = {
			{48827, 30}, -- Avenger's Shield
		}
	},
	["PRIEST"] = {
		["*"] = {
			{6346, 180}, -- Fear Ward
			{10890, 27}, -- Psychic Scream
			{34433, 300}, -- Shadowfiend
			{48158, 12}, -- Shadow Word: Death
			{48172, 120}, -- Desperate Prayer
			{64843, 480}, -- Divine Hymn
			{64901, 360}, -- Hymn of Hope
		},
		["Discipline"] = {
			{10060, 96}, -- Power Infusion
			{33206, 144}, -- Pain Suppression
		},
		["Holy"] = {
			{47788, 180}, -- Guardian Spirit
			{48086, 180}, -- Lightwell
		},
		["Shadow"] = {
			{47585, 75}, -- Dispersion
			{15487, 45}, -- Silence
			{64044, 120}, -- Psychic Horror
		}
	},
	["ROGUE"] = {
		["*"] = {
			{1766, 10}, -- Kick
			{2094, 120}, -- Blind
			{8643, 20}, -- Kidney Shot
			{26669, 180}, -- Evasion
			{26889, 120}, -- Vanish
			{31224, 60}, -- Cloak of Shadows
			{51722, 60}, -- Dismantle
		},
		["Assassination"] = {
			{14177, 180}, -- Cold Blood
		},
		["Combat"] = {
			{51690, 120}, -- Killing Spree
			{13750, 180}, -- Adrenaline Rush
		},
		["Subtlety"] = {
			{14185, 300}, -- Preparation
			{51713, 60}, -- Shadow Dance
			{36554, 20}, -- Shadowstep
		}
	},
	["SHAMAN"] = {
		["*"] = {
			{57994, 5}, -- Wind Shear
			{51514, 45}, -- Hex
			{8177, 15}, -- Grounding Totem
		},
		["Elemental"] = {
			{59159, 35}, -- Thunderstorm
			{16166, 180}, -- Elemental Mastery
		},
		["Enhancement"] = {
			{30823, 60}, -- Shamanistic Rage
		},
		["Restoration"] = {
			{16188, 120}, -- Nature's Swiftness
		}
	},
	["WARLOCK"] = {
		["*"] = {
			{17925, 120}, -- Death Coil
			{18708, 180}, -- Fel Domination
			{19647, 24}, -- Spell Lock
			{48011, 8}, -- Devour Magic
			{48020, 30}, -- Demonic Circle: Teleport
		},
		["Affliction"] = {

		},
		["Demonology"] = {
			{59672, 180}, -- Metamorphosis
		},
		["Destruction"] = {
			{47847, 20}, -- Shadowfury
		}
	},
	["WARRIOR"] = {
		["*"] = {
			{72, 12}, -- Shield Bash
			{676, 60}, -- Disarm
			{871, 300}, -- Shield Wall
			{1719, 300}, -- Recklessness
			{2565, 60}, -- Shield Block
			{3411, 30}, -- Intervene
			{5246, 120}, -- Intimidating Shout
			{11578, 13}, -- Charge
			{18499, 30}, -- Berserker Rage
			{20230, 300}, -- Retaliation
			{23920, 10}, -- Spell Reflection
			{47996, 15}, -- Intercept
			{55694, 180}, -- Enraged Regeneration
			{64382, 300}, -- Shattering Throw
		},
		["Arms"] = {
			{46924, 90}, -- Bladestorm
		},
		["Fury"] = {
			{12292, 180}, -- Death Wish
		},
		["Protection"] = {
			{12809, 30}, -- Concussion Blow
			{12975, 180}, -- Last Stand
			{46968, 17}, -- Shockwave
		}
	},
	["DEATHKNIGHT"] = {
		["*"] = {
			{47528, 10}, -- Mind Freeze
			{48743, 120}, -- Death Pact
			{51052, 120}, -- Anti-Magic Zone
			{49576, 35}, -- Death Grip
			{48707, 45}, -- Anti-Magic Shell
			{49039, 120}, -- Lichborne
			{47476, 120}, -- Strangulate
			{51271, 60}, -- Unbreakable Armor
			{48792, 120}, -- Icebound Fortitude
		},
		["Blood"] = {
			-- None
		},
		["Frost"] = {
			{49203, 60}, -- Hungering Cold
		},
		["Unholy"] = {
			{47481, 20}, -- Gnaw
			{49206, 180}, -- Gargoyle
		}
	}
}

b.dbRacial = {
	-- Alliance
	["Dwarf"] = {20594, 120},
	["NightElf"] = {58984, 120},
	["Gnome"] = {20589, 60},
	["Draenei"] = {28880, 180},

	-- Horde
	["Tauren"] = {20549, 120},
	["Scourge"] = {7744, 120},
	["BloodElf"] = {28730, 120},
	["Orc"] = {20572, 120},
	["Troll"] = {26297, 180},
}

b.dbTrinket = {
	{42292, 120},
	{59752, 120},
}

b.dbSpecs = {
	["MAGE"] = {["Arcane"] = 1, ["Fire"] = 2, ["Frost"] = 3},
	["ROGUE"] = {["Assassination"] = 1, ["Combat"] = 2, ["Subtlety"] = 3},
	["PALADIN"] = {["Holy"] = 1, ["Protection"] = 2, ["Retribution"] = 3},
	["DEATHKNIGHT"] = {["Blood"] = 1, ["Frost"] = 2, ["Unholy"] = 3},
	["DRUID"] = {["Balance"] = 1, ["Feral"] = 2, ["Restoration"] = 3},
	["HUNTER"] = {["Beast Mastery"] = 1, ["Marksmanship"] = 2, ["Survival"] = 3},
	["PRIEST"] = {["Discipline"] = 1, ["Holy"] = 2, ["Shadow"] = 3},
	["SHAMAN"] = {["Elemental"] = 1, ["Enhancement"] = 2, ["Restoration"] = 3},
	["WARLOCK"] = {["Affliction"] = 1, ["Demonology"] = 2, ["Destruction"] = 3},
	["WARRIOR"] = {["Arms"] = 1, ["Fury"] = 2, ["Protection"] = 3}
}