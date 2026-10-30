extends RefCounted
## Static data for Ember Front v3: unit types, prices, sprites, names, texts.

# ---------------------------------------------------------------- enemy targets
# hp, reward, name, letter on the map marker
const TYPES := {
	"inf": {"hp": 3.0, "rew": 15, "name": "Infantry position", "L": "I"},
	"sam": {"hp": 5.0, "rew": 40, "name": "Air defense site", "L": "S"},
	"plant": {"hp": 12.0, "rew": 100, "name": "Power plant", "L": "P"},
	"depot": {"hp": 5.0, "rew": 60, "name": "Supply depot", "L": "D"},
	"afield": {"hp": 9.0, "rew": 120, "name": "Enemy airfield", "L": "A"},
	"ship": {"hp": 4.0, "rew": 30, "name": "Cargo ship", "L": "C"},
	"port": {"hp": 10.0, "rew": 80, "name": "Harbor", "L": "H"},
	"bridge": {"hp": 8.0, "rew": 90, "name": "Logistics bridge", "L": "B"},
	"otrk": {"hp": 3.0, "rew": 110, "name": "Missile launcher truck", "L": "M"},
	"wship": {"hp": 6.0, "rew": 70, "name": "Enemy warship", "L": "W"},
}

# ---------------------------------------------------------------- aircraft
# gb: guided bombs, rk: rockets, aa: air-to-air, cm: cruise missiles
const ACTYPES := {
	"atk": {"name": "Attack aircraft", "short": "Attacker", "hp": 3, "sp": 72.0, "burn": 1.1, "gb": 4, "rk": 16, "aa": 2, "cm": 0,
		"price": {"c": 150, "m": 15, "o": 0}, "desc": "Guided bombs and rockets for ground targets."},
	"ftr": {"name": "Fighter", "short": "Fighter", "hp": 3, "sp": 96.0, "burn": 1.3, "gb": 0, "rk": 0, "aa": 4, "cm": 0,
		"price": {"c": 230, "m": 25, "o": 10}, "desc": "Fast. Shoots down enemy aircraft, drones and cruise missiles around it."},
	"bmb": {"name": "Bomber", "short": "Bomber", "hp": 5, "sp": 58.0, "burn": 0.9, "gb": 8, "rk": 0, "aa": 0, "cm": 2,
		"price": {"c": 320, "m": 35, "o": 20}, "desc": "Heavy bombs. Launches 2 cruise missiles from far away, then goes home."},
}
const UP_COST := [0, 220, 340, 480]  # price to go from level N to N+1 (index = current level)
const HYPER_COST := {"c": 260, "m": 20, "o": 20}

# 11x11 pixel aircraft, nose up. Digits index into the palette below.
const PLANE_ATK := [
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
const PLANE_FTR := [
	".....1.....",
	".....1.....",
	".....1.....",
	"....131....",
	"....121....",
	"...11111...",
	"..1111111..",
	".111121111.",
	"1...111...1",
	"....111....",
	"....1.1....",
]
const PLANE_BMB := [
	".....1.....",
	"....111....",
	"....131....",
	"11..121..11",
	"11111111111",
	"11122222111",
	"11111111111",
	"...11111...",
	"....111....",
	"...11.11...",
	"..111.111..",
]
const PAL_PLAYER := {"1": "aab59a", "2": "74856a", "3": "1f3345"}
const PAL_ENEMY := {"1": "d3aaa2", "2": "a85d55", "3": "3a1a1a"}

# ---------------------------------------------------------------- things the player can build
# r: clear radius, t: build seconds
const BUILD := {
	"airfield": {"name": "Airfield", "c": 300, "m": 30, "o": 0, "r": 44.0, "t": 22.0, "hp": 9.0, "L": "A",
		"desc": "A new runway with room for 6 aircraft."},
	"droneport": {"name": "Drone port", "c": 140, "m": 10, "o": 0, "r": 16.0, "t": 10.0, "hp": 4.0, "L": "U",
		"desc": "Needed to launch UAVs and recon drones. Holds 4 UAVs."},
	"uavfac": {"name": "UAV factory", "c": 220, "m": 20, "o": 0, "r": 18.0, "t": 14.0, "hp": 5.0, "L": "F",
		"desc": "Builds one UAV every 20 seconds."},
	"rocketfac": {"name": "Rocket factory", "c": 400, "m": 40, "o": 20, "r": 20.0, "t": 20.0, "hp": 7.0, "L": "R",
		"desc": "Builds a ballistic missile every 80 seconds from oil and metal."},
	"plant": {"name": "Power plant", "c": 260, "m": 25, "o": 0, "r": 20.0, "t": 16.0, "hp": 12.0, "L": "P",
		"desc": "+1 power. Cities without power go dark and pay less."},
	"solar": {"name": "Solar station", "c": 150, "m": 10, "o": 0, "r": 16.0, "t": 10.0, "hp": 5.0, "L": "O",
		"desc": "+0.5 power. Cheap and spread out."},
	"derrick": {"name": "Oil derrick", "c": 120, "m": 10, "o": 0, "r": 12.0, "t": 8.0, "hp": 4.0, "L": "D",
		"desc": "+0.12 oil per second."},
	"mine": {"name": "Metal mine", "c": 130, "m": 0, "o": 0, "r": 14.0, "t": 8.0, "hp": 4.0, "L": "M",
		"desc": "+0.09 metal per second."},
	"warehouse": {"name": "Warehouse", "c": 140, "m": 15, "o": 0, "r": 16.0, "t": 9.0, "hp": 5.0, "L": "W",
		"desc": "Raises the oil and metal storage limit by 100."},
	"sam": {"name": "Shield SAM", "c": 160, "m": 12, "o": 0, "r": 14.0, "t": 9.0, "hp": 5.0, "L": "S",
		"desc": "Short range air defense. Good against drones and aircraft."},
	"lsam": {"name": "Long range SAM", "c": 380, "m": 30, "o": 0, "r": 18.0, "t": 14.0, "hp": 6.0, "L": "L",
		"desc": "Long range air defense. The best answer to ballistic missiles."},
	"port": {"name": "Harbor", "c": 220, "m": 20, "o": 0, "r": 18.0, "t": 14.0, "hp": 8.0, "L": "H",
		"desc": "Needed to build a fleet. Build it on the southern coast."},
}

# bought at HQ (stock items and units)
const BUY := {
	"atk": {"name": "Attack aircraft", "c": 150, "m": 15, "o": 0},
	"ftr": {"name": "Fighter", "c": 230, "m": 25, "o": 10},
	"bmb": {"name": "Bomber", "c": 320, "m": 35, "o": 20},
	"truck": {"name": "Missile launcher truck", "c": 140, "m": 20, "o": 5},
	"msl": {"name": "Ballistic missile", "c": 200, "m": 20, "o": 10},
	"uav": {"name": "UAV", "c": 40, "m": 0, "o": 3},
	"fleet": {"name": "Fleet of 3 ships", "c": 320, "m": 30, "o": 20},
	"brig": {"name": "Infantry brigade", "c": 120, "m": 10, "o": 0},
	"smoke": {"name": "Smoke screen x2", "c": 50, "m": 0, "o": 0},
	"shell": {"name": "Artillery shells x10", "c": 80, "m": 6, "o": 0},
	"med": {"name": "Field hospital x2", "c": 70, "m": 5, "o": 0},
}

# ---------------------------------------------------------------- names
const PLAYER_TOWNS := ["Vell Haven", "Ostrand", "Marrow Fell", "Kestrel", "Dunmere", "Halcyon", "Brightwater"]
const ENEMY_TOWNS := ["Drossvik", "Grau Pass", "Ironmoor", "Tessal", "Volkhar", "Nordrake", "Kamennograd"]

const NATIONS := [
	{"id": "nor", "name": "Norlovia", "c1": "e8c14a", "c2": "2f6b3f"},
	{"id": "ilr", "name": "Ilrivia", "c1": "e5483f", "c2": "f0b429"},
	{"id": "mol", "name": "Mololia", "c1": "4aa3e8", "c2": "f4f4f4"},
]
const STAGES := ["Protest", "Threat", "Demand", "Ultimatum"]
const STAGE_T := [60.0, 50.0, 40.0, 30.0]

# [name, hex colour of the cargo on deck]
const CARGO := [["oil", "2b2b2b"], ["metal", "aab2c0"], ["grain", "d9b84a"], ["containers", "c75d43"]]

# flavour lines for the news feed
const NEWS_GOOD := [
	"Engineers laid a pontoon crossing near the broken bridge",
	"Group reorganizes at the front",
	"Our recon drone spotted enemy columns",
	"Field kitchens reached the front line",
]
const NEWS_BAD := [
	"Enemy recon drone spotted near our rear",
	"Enemy sabotage group seen near a depot",
	"Counterattack repelled at the front",
]

const INTRO_TITLE := "Ember Front"
const INTRO_SUB := "Pixel war strategy. You command Azuria (blue) against Karmin (red)."
const INTRO := [
	"Seven tabs at the bottom: Map, Cities, Aviation, Air defense, Army, Politics, Industry.",
	"Aviation: tap STRIKE, then an enemy marker. Pick an aircraft first to give it a route or a target. Buy aircraft and trucks at HQ (right side).",
	"Ballistic missiles are fired from missile trucks. Buy a truck, select it, tap a target. Enemy trucks hide: use RECON to find them.",
	"Build airfields, drone ports, factories, power plants, air defense and mines. Tap the building, then tap a free spot on your land.",
	"Army groups push the front. Support them with air strikes, artillery, smoke and field hospitals. Capture cities to grow.",
	"Power plants feed your cities. When the grid is overloaded or plants die, cities go dark and income falls.",
	"Neutral ships carry yellow flags. Sinking them starts a diplomatic case in Politics. Reach the score goal or take Karmin City to win.",
]
const GOAL := 15000.0
