extends RefCounted
## Static data for Ember Front: target types, prices, sprites, names, text.

const TYPES := {
	"inf": {"hp": 3.0, "rew": 15, "name": "Infantry position", "L": "I"},
	"sam": {"hp": 5.0, "rew": 40, "name": "Air defense site", "L": "S"},
	"plant": {"hp": 12.0, "rew": 100, "name": "Power plant", "L": "P"},
	"depot": {"hp": 5.0, "rew": 60, "name": "Supply depot", "L": "D"},
	"afield": {"hp": 9.0, "rew": 120, "name": "Enemy airfield", "L": "A"},
	"ship": {"hp": 4.0, "rew": 30, "name": "Cargo ship", "L": "C"},
	"port": {"hp": 10.0, "rew": 80, "name": "Harbor", "L": "H"},
}

const PRICE := {
	"ac": {"c": 150, "m": 15, "o": 0},
	"msl": {"c": 200, "m": 20, "o": 10},
	"uav": {"c": 40, "m": 0, "o": 3},
	"ad": {"c": 160, "m": 12, "o": 0},
	"plant": {"c": 260, "m": 25, "o": 0},
	"brig": {"c": 120, "m": 10, "o": 0},
}

# 11x11 pixel plane, nose up. Digits index into the palette below.
const PLANE := [
	".....1.....",
	".....1.....",
	"....131....",
	"....131....",
	"....121....",
	"1...111...1",
	"11111111111",
	"11112221111",
	"....111....",
	"...11.11...",
	"..111.111..",
]
const PAL_PLAYER := {"1": "aab59a", "2": "74856a", "3": "1f3345"}
const PAL_ENEMY := {"1": "d3aaa2", "2": "a85d55", "3": "3a1a1a"}

const PLAYER_TOWNS := ["Vell Haven", "Ostrand", "Marrow Fell", "Kestrel", "Dunmere", "Halcyon"]
const ENEMY_TOWNS := ["Drossvik", "Grau Pass", "Ironmoor", "Tessal", "Volkhar", "Nordrake"]

const NATIONS := [
	{"id": "nor", "name": "Norlovia", "c1": "e8c14a", "c2": "2f6b3f"},
	{"id": "ilr", "name": "Ilrivia", "c1": "e5483f", "c2": "f0b429"},
	{"id": "mol", "name": "Mololia", "c1": "4aa3e8", "c2": "f4f4f4"},
]
const STAGES := ["Protest", "Threat", "Demand", "Ultimatum"]
const STAGE_T := [60.0, 50.0, 40.0, 30.0]

# [name, hex colour of the cargo on deck]
const CARGO := [["oil", "2b2b2b"], ["metal", "aab2c0"], ["grain", "d9b84a"], ["containers", "c75d43"]]

const INTRO_TITLE := "Ember Front"
const INTRO_SUB := "Air-strike war game. You command Azuria (blue) against Karmin (red)."
const INTRO := [
	"Tap an aircraft chip, then tap an enemy marker to send it on a strike. Tap empty ground to make it loiter. Drag to move the map, pinch to zoom.",
	"Each plane has fuel and limited ordnance: GB guided bombs, RKT rockets, AA air-to-air missiles. It lands and rearms on its own when empty, using your coins.",
	"Destroy infantry positions (I) to push the front line east. Take Karmin City to win.",
	"Air defense sites (S) shoot at aircraft inside their ring. Hit them first.",
	"Ballistic missiles wreck power plants. At night, dark cities mean a weaker enemy.",
	"Use the tabs at the bottom to buy: aircraft, missiles and UAVs (Strike), air defense and power plants (Defense), brigades (Army).",
	"Cargo ships (C) sail along the east coast. Sinking Karmin ships weakens its front. Yellow markers are neutral flags: sinking them starts a diplomatic case in Politics.",
]
const LEGEND := "I Infantry   S Air defense   P Power plant   D Depot   A Airfield   H Harbor   C Cargo ship"
