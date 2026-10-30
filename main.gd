extends Node2D
## Ember Front v3: pixel-art war strategy for phones (Godot 4).
## Everything is drawn in code, so the project only needs this script,
## Main.tscn and assets_data.gd.

const D = preload("res://assets_data.gd")

const TS := 6
const GW := 288
const GH := 384
const W := 1728.0
const H := 2304.0
const NB := 48
const BH := 48.0
const GB_DMG := 2.5
const RK_DMG := 0.4
const TURN := 2.0
const MAX_GROUPS := 4
const TRUCK_RANGE := 620.0
const SEA_Y := 0.905  # fraction of the map height where the southern sea starts

# ---------------------------------------------------------------- world
var rng := RandomNumberGenerator.new()
var n_elev := FastNoiseLite.new()
var n_moist := FastNoiseLite.new()
var n_field := FastNoiseLite.new()
var n_coast := FastNoiseLite.new()
var n_river := FastNoiseLite.new()
var n_front := FastNoiseLite.new()
var T := PackedByteArray()
var terr_tex: ImageTexture
var towns: Array = []
var placed: Array = []
var roads: Array = []
var rivers: Array = []
var pcap := Vector2(W * 0.12, H * 0.5)
var ecap := Vector2(W * 0.88, H * 0.5)
var pp_pos: Array = []
var ep_pos: Array = []
var dep_pos: Array = []
var ports_pos: Array = []
var spr := {}
var clouds: Array = []
var decals: Array = []

# ---------------------------------------------------------------- game state
var t := 0.0
var coins := 400.0
var oil := 60.0
var metal := 80.0
var speed := 1
var started := false
var over := ""
var idc := 0
var acn := 0
var truckn := 0
var fleetn := 0
var ac: Array = []
var trucks: Array = []
var fleets: Array = []
var bl: Array = []
var af_p: Array = []
var tg: Array = []
var pr: Array = []
var pt: Array = []
var msl: Array = []
var ea: Array = []
var eu: Array = []
var fires: Array = []
var trail: Array = []
var uavs: Array = []
var shells: Array = []
var smokes: Array = []
var loglist: Array = []
var feed: Array = []
var banners: Array = []
var unread := 0
var sel = null
var mode := ""
var mode_arg := ""
var route_pts: Array = []
var place_type := ""
var place_ok := false
var place_pos := Vector2.ZERO
var mis := 2
var uav_stock := 2
var smoke_n := 2
var shell_n := 20
var med_n := 2
var kills := 0
var kill_val := 0.0
var lost := 0
var cities_taken := 0
var earned := 0.0
var score := 0.0
var income := 0.0
var supply := 0.0
var demand := 0.0
var dark_n := 0
var epow := 1.0
var disc := 1.0
var disc_t := 0.0
var estock := 2.0
var bridge_cut := 0.0
var oil_rate := 0.0
var metal_rate := 0.0
var stock_cap := 200.0
var war_pen := 0.0
var combat_view := false
var tab := "map"
var nat: Array = []
var cases: Array = []
var offers: Array = []
var groups: Array = []
var F := PackedFloat32Array()
var SUP := PackedFloat32Array()
var NET := PackedFloat32Array()
var gtimer := {}

# ---------------------------------------------------------------- timers
var ev_t := 80.0
var res_t := 12.0
var sam_t := 60.0
var ea_t := 40.0
var eu_t := 110.0
var ship_t := 10.0
var off_t := 60.0
var wship_t := 90.0
var news_t := 50.0
var otrk_t := 100.0
var rec_t := 0.0
var fac_t := 0.0
var uav_t := 0.0

# ---------------------------------------------------------------- camera / input
var cam := Vector2.ZERO
var zoom := 1.0
var vw := 720.0
var vh := 1280.0
var touches := {}
var pinch_d := 0.0
var use_touch := false
var hud_t := 0.0
var toast_t := 0.0

var COL := {}


# ====================================================================== setup
func _ready() -> void:
	DisplayServer.screen_set_orientation(DisplayServer.SCREEN_PORTRAIT)
	var win := get_window()
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	win.content_scale_size = Vector2i(720, 1280)
	get_tree().quit_on_go_back = false
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	use_touch = DisplayServer.is_touchscreen_available()
	F.resize(NB)
	SUP.resize(NB)
	NET.resize(NB)
	COL = {
		"ink": Color.html("0d130f"), "text": Color.html("efe6c8"), "dim": Color.html("a9a283"),
		"orange": Color.html("ff8a2a"), "blue": Color.html("4d93ff"), "red": Color.html("ff5a4d"),
		"green": Color.html("86d963"), "brass": Color.html("8b6f33"), "gold": Color.html("f0c660"),
		"olive": Color.html("3a4a2a"), "panel": Color.html("1a2214"),
	}
	setup_noise()
	gen_world()
	render_terrain()
	make_sprites()
	make_clouds()
	build_ui()
	new_game()
	show_overlay()
	get_viewport().size_changed.connect(_on_resize)
	_on_resize()


func _on_resize() -> void:
	var r := get_viewport_rect().size
	vw = r.x
	vh = r.y
	clamp_cam()


func setup_noise() -> void:
	rng.seed = 20261029
	var list := [[n_elev, 11], [n_moist, 23], [n_field, 31], [n_coast, 41], [n_river, 7], [n_front, 5]]
	for pair in list:
		var n: FastNoiseLite = pair[0]
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		n.fractal_type = FastNoiseLite.FRACTAL_FBM
		n.fractal_octaves = 4
		n.frequency = 1.0
		n.seed = pair[1]


func fb(n: FastNoiseLite, x: float, y: float) -> float:
	return n.get_noise_2d(x, y) * 0.5 + 0.5


func rhash(x: int, y: int, s: int) -> float:
	var h: int = (x * 374761393 + y * 668265263 + s * 1274126177) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	return float((h ^ (h >> 16)) & 0xffff) / 65536.0


func coast_g(gy: float) -> float:
	return GW * 0.945 + (fb(n_coast, 3.0, gy / 14.0) - 0.5) * 9.0


func south_g(gx: float) -> float:
	return GH * SEA_Y + (fb(n_coast, gx / 16.0, 9.0) - 0.5) * 7.0


func sea_x(y: float) -> float:
	return minf(W - 6.0, coast_g(clampf(y / TS, 0.0, GH)) * TS)


func sea_y(x: float) -> float:
	return south_g(clampf(x / TS, 0.0, GW)) * TS


func in_sea(x: float, y: float) -> bool:
	return x > sea_x(y) + 8.0 or y > sea_y(x) + 8.0


func tile_at(x: float, y: float) -> int:
	var gx := clampi(int(x / TS), 0, GW - 1)
	var gy := clampi(int(y / TS), 0, GH - 1)
	return T[gy * GW + gx]


func gen_world() -> void:
	T.resize(GW * GH)
	for gy in range(GH):
		for gx in range(GW):
			var e: float = fb(n_elev, gx / 38.0, gy / 38.0)
			var d1 := Vector2((gx - GW * 0.42) / 24.0, (gy - GH * 0.73) / 19.0).length()
			e -= 0.46 * maxf(0.0, 1.0 - d1 * d1)
			var dm := Vector2((gx - GW * 0.7) / 26.0, (gy - GH * 0.16) / 22.0).length()
			e += 0.4 * maxf(0.0, 1.0 - dm * dm)
			var d2 := Vector2((gx - GW * 0.56) / 11.0, (gy - GH * 0.36) / 14.0).length()
			e += 0.34 * maxf(0.0, 1.0 - d2 * d2)
			var m: float = fb(n_moist, gx / 24.0, gy / 24.0)
			var tt := 2
			if e < 0.33:
				tt = 0
			elif e < 0.38:
				tt = 1
			elif e > 0.86:
				tt = 6
			elif e > 0.72:
				tt = 5
			elif e > 0.64:
				tt = 4
			elif m > 0.5 and e < 0.66:
				tt = 3
			var cs := coast_g(gy)
			if gx > cs:
				tt = 0 if gx > cs + 2 else 1
			var sy := south_g(gx)
			if gy > sy:
				tt = 0 if gy > sy + 3 else 1
			T[gy * GW + gx] = tt
	rivers.append(make_river(GW * 0.66, int(GH * 0.22), 1.0))
	make_river(GW * 0.2, 0, 2.0)
	rivers.append(make_river(GW * 0.86, int(GH * 0.4), 3.0))
	placed.append({"x": pcap.x, "y": pcap.y, "r": 62.0})
	placed.append({"x": ecap.x, "y": ecap.y, "r": 62.0})
	mk_town(pcap.x, pcap.y, 58.0, "AZURIA CITY", true)
	mk_town(ecap.x, ecap.y, 58.0, "KARMIN CITY", true)
	for i in range(10):
		var p := spot(W * 0.06, W * 0.4, H * 0.04, H * 0.84, 34.0)
		mk_town(p.x, p.y, rng.randf_range(24.0, 38.0), D.PLAYER_TOWNS[i], false)
	for i in range(10):
		var p := spot(W * 0.6, W * 0.9, H * 0.06, H * 0.84, 34.0)
		mk_town(p.x, p.y, rng.randf_range(24.0, 38.0), D.ENEMY_TOWNS[i], false)
	var afs := [Vector2(W * 0.23, H * 0.27), Vector2(W * 0.2, H * 0.72), Vector2(W * 0.84, H * 0.19)]
	for a in afs:
		placed.append({"x": a.x, "y": a.y, "r": 46.0})
		carve(a.x, a.y, 50.0)
	pp_pos = [spot(W * 0.1, W * 0.36, H * 0.12, H * 0.82, 20.0), spot(W * 0.1, W * 0.36, H * 0.12, H * 0.82, 20.0),
		spot(W * 0.08, W * 0.36, H * 0.1, H * 0.82, 16.0)]
	ep_pos = [spot(W * 0.65, W * 0.88, H * 0.12, H * 0.82, 20.0), spot(W * 0.65, W * 0.88, H * 0.12, H * 0.82, 20.0), spot(W * 0.65, W * 0.88, H * 0.12, H * 0.82, 20.0)]
	for i in range(5):
		dep_pos.append(spot(W * 0.66, W * 0.88, H * 0.08, H * 0.82, 16.0))
	for arr in [pp_pos, ep_pos, dep_pos]:
		for p in arr:
			carve(p.x, p.y, 16.0)
	for f in [0.3, 0.62]:
		var gy := int(f * GH)
		ports_pos.append(Vector2(coast_g(gy) * TS - 14.0, gy * TS))
	ports_pos.append(Vector2(W * 0.78, sea_y(W * 0.78) - 14.0))
	# player harbor position and enemy airfield are stored for new_game
	# roads: every town to its two nearest neighbours, facilities to the nearest town
	var seen := {}
	for i in range(towns.size()):
		var dl: Array = []
		for j in range(towns.size()):
			if j != i:
				dl.append([j, Vector2(towns[i].x, towns[i].y).distance_to(Vector2(towns[j].x, towns[j].y))])
		dl.sort_custom(func(a, b): return a[1] < b[1])
		for k in range(2):
			var j: int = dl[k][0]
			var key := "%d-%d" % [mini(i, j), maxi(i, j)]
			if not seen.has(key):
				seen[key] = true
				roads.append([Vector2(towns[i].x, towns[i].y), Vector2(towns[j].x, towns[j].y)])
	var facs: Array = []
	facs.append_array(afs)
	facs.append_array(pp_pos)
	facs.append_array(ep_pos)
	facs.append_array(dep_pos)
	facs.append_array(ports_pos)
	for f in facs:
		var best: Dictionary = towns[0]
		for tw in towns:
			if Vector2(tw.x, tw.y).distance_to(Vector2(f.x, f.y)) < Vector2(best.x, best.y).distance_to(Vector2(f.x, f.y)):
				best = tw
		roads.append([Vector2(f.x, f.y), Vector2(best.x, best.y)])
	# remember airfield spots in the placed list for new_game
	afs_pos = afs


func make_river(gx0: float, gy0: int, k: float) -> Array:
	var gx := gx0
	var pts: Array = []
	for gy in range(gy0, GH):
		gx += (fb(n_river, gy / 12.0, k) - 0.5) * 2.4
		var x := int(round(gx))
		pts.append([gy, x])
		for w in range(2):
			var i := gy * GW + clampi(x + w, 0, GW - 1)
			if T[i] != 0 and T[i] < 5:
				T[i] = 1
	return pts


func carve(x: float, y: float, r: float) -> void:
	var g := r / TS
	for gy in range(int(y / TS - g) - 1, int(y / TS + g) + 2):
		for gx in range(int(x / TS - g) - 1, int(x / TS + g) + 2):
			if gx < 0 or gy < 0 or gx >= GW or gy >= GH:
				continue
			if Vector2(gx * TS - x, gy * TS - y).length() <= r:
				T[gy * GW + gx] = 2


func ok_spot(x: float, y: float, r: float) -> bool:
	for p in placed:
		if Vector2(p.x - x, p.y - y).length() < p.r + r + 34.0:
			return false
	for off in [Vector2(0, 0), Vector2(r * 0.7, 0), Vector2(-r * 0.7, 0), Vector2(0, r * 0.7), Vector2(0, -r * 0.7)]:
		var tt := tile_at(x + off.x, y + off.y)
		if tt < 2 or tt > 4:
			return false
	return true


func spot(x0: float, x1: float, y0: float, y1: float, r: float) -> Vector2:
	for i in range(500):
		var x := rng.randf_range(x0, x1)
		var y := rng.randf_range(y0, y1)
		if ok_spot(x, y, r):
			placed.append({"x": x, "y": y, "r": r})
			return Vector2(x, y)
	var fx := (x0 + x1) / 2.0
	var fy := (y0 + y1) / 2.0
	placed.append({"x": fx, "y": fy, "r": r})
	return Vector2(fx, fy)


func mk_town(x: float, y: float, r: float, nm: String, cap: bool) -> void:
	carve(x, y, r * 1.05)
	var b: Array = []
	for cy in range(-int(r), int(r) + 1, 7):
		for cx in range(-int(r), int(r) + 1, 8):
			if Vector2(cx, cy).length() < r and rng.randf() < (0.88 if cap else 0.72):
				b.append([round(x + cx + rng.randf_range(-1.5, 1.5)), round(y + cy + rng.randf_range(-1.5, 1.5)),
					4.0 + rng.randi_range(0, 2), 3.0 + rng.randi_range(0, 1), rng.randf()])
	towns.append({"x": x, "y": y, "r": r, "name": nm, "cap": cap, "b": b, "side": 0, "lit": true, "pop": int(r * 1.7),
		"burn": 0.0})


func render_terrain() -> void:
	var img := Image.create(int(W), int(H), false, Image.FORMAT_RGBA8)
	var gr := [Color.html("69a83e"), Color.html("62a038"), Color.html("6fb043")]
	var fo := [Color.html("4c8a33"), Color.html("478230")]
	var hi := [Color.html("948256"), Color.html("8a7a50")]
	var rk := [Color.html("7a746d"), Color.html("6b665f")]
	var sn := [Color.html("eef3f6"), Color.html("dfe7ec")]
	var dw := [Color.html("25559f"), Color.html("2a5ca8")]
	var sw := [Color.html("3a78c9"), Color.html("4083d4")]
	var f1 := Color.html("a9bb4a")
	var f2 := Color.html("97b042")
	for gy in range(GH):
		for gx in range(GW):
			var tt: int = T[gy * GW + gx]
			var h := rhash(gx, gy, 5)
			var c: Color
			match tt:
				0: c = dw[int(h * 2)]
				1: c = sw[int(h * 2)]
				2:
					if fb(n_field, gx / 7.0, gy / 7.0) > 0.66:
						c = f1 if ((gy >> 1) & 1) == 1 else f2
					else:
						c = gr[int(h * 3)]
				3: c = fo[int(h * 2)]
				4: c = hi[int(h * 2)]
				5: c = rk[int(h * 2)]
				_: c = sn[int(h * 2)]
			img.fill_rect(Rect2i(gx * TS, gy * TS, TS, TS), c)
			if tt == 5 or tt == 6:
				if T[maxi(0, gy - 1) * GW + gx] < 5:
					img.fill_rect(Rect2i(gx * TS, gy * TS, TS, 2), c.lightened(0.25))
				if gx < GW - 1 and T[gy * GW + gx + 1] < 5:
					img.fill_rect(Rect2i(gx * TS + TS - 2, gy * TS, 2, TS), c.darkened(0.2))
			if tt == 1:
				# foam on the shore
				var near_land := false
				for off in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
					var nx: int = gx + off.x
					var ny: int = gy + off.y
					if nx >= 0 and ny >= 0 and nx < GW and ny < GH and T[ny * GW + nx] >= 2:
						near_land = true
				if near_land and h < 0.5:
					img.fill_rect(Rect2i(gx * TS + 1, gy * TS + 2, 3, 1), Color(1, 1, 1, 0.55))
	var tcol_a := Color.html("2b5a24")
	var tcol_b := Color.html("3f7d31")
	var tcol_c := Color.html("55391f")
	for gy in range(GH):
		for gx in range(GW):
			var tt: int = T[gy * GW + gx]
			var h := rhash(gx, gy, 9)
			var px := -100
			var py := -100
			if tt == 3 and h < 0.82:
				px = gx * TS + (int(h * 7) % 2)
				py = gy * TS - (int(h * 13) % 2)
			elif tt == 2 and h < 0.05:
				px = gx * TS + 1
				py = gy * TS - 1
			elif tt == 4 and h < 0.1:
				img.fill_rect(Rect2i(gx * TS + 2, gy * TS + 2, 2, 2), Color.html("4b6a34"))
			if px > -100:
				img.fill_rect(Rect2i(px, py + 2, 5, 3), tcol_a)
				img.fill_rect(Rect2i(px + 1, py, 3, 5), tcol_a)
				img.fill_rect(Rect2i(px + 1, py + 1, 2, 2), tcol_b)
				img.fill_rect(Rect2i(px + 2, py + 5, 1, 2), tcol_c)
	var road_dark := Color.html("6b5c3e")
	var road_lite := Color.html("b5a583")
	for rd in roads:
		var a: Vector2 = rd[0]
		var b: Vector2 = rd[1]
		var n := maxi(2, int(a.distance_to(b) / 16.0))
		var pts: Array = []
		for i in range(n + 1):
			var u := float(i) / n
			var j := 0.0 if (i == 0 or i == n) else rng.randf_range(-3.0, 3.0)
			pts.append(Vector2(lerpf(a.x, b.x, u) + j, lerpf(a.y, b.y, u) + j * 0.6))
		for pass_i in range(2):
			for i in range(pts.size() - 1):
				var p0: Vector2 = pts[i]
				var p1: Vector2 = pts[i + 1]
				var steps := maxi(1, int(p0.distance_to(p1)))
				for s in range(steps + 1):
					var q := p0.lerp(p1, float(s) / steps)
					if tile_at(q.x, q.y) < 2:
						continue
					if pass_i == 0:
						img.fill_rect(Rect2i(int(q.x) - 1, int(q.y) - 1, 3, 3), road_dark)
					else:
						img.fill_rect(Rect2i(int(q.x), int(q.y), 1, 1), road_lite)
	terr_tex = ImageTexture.create_from_image(img)


func shape_tex(shape: Array, pal: Dictionary, black: bool) -> ImageTexture:
	var img := Image.create(11, 11, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in range(shape.size()):
		var row: String = shape[y]
		for x in range(row.length()):
			var ch := row[x]
			if ch != ".":
				img.set_pixel(x, y, Color(0, 0, 0, 1) if black else Color.html(pal[ch]))
	return ImageTexture.create_from_image(img)


func make_sprites() -> void:
	var shapes := {"atk": D.PLANE_ATK, "ftr": D.PLANE_FTR, "bmb": D.PLANE_BMB}
	for k in shapes:
		spr[k + "_p"] = shape_tex(shapes[k], D.PAL_PLAYER, false)
		spr[k + "_e"] = shape_tex(shapes[k], D.PAL_ENEMY, false)
		spr[k + "_s"] = shape_tex(shapes[k], D.PAL_PLAYER, true)


func make_clouds() -> void:
	var cr := RandomNumberGenerator.new()
	cr.seed = 77
	for i in range(16):
		var puffs: Array = []
		var n := cr.randi_range(4, 8)
		for j in range(n):
			puffs.append(Vector3(cr.randf_range(-26, 26), cr.randf_range(-9, 9), cr.randf_range(9, 20)))
		clouds.append({"x": cr.randf_range(0, W), "y": cr.randf_range(0, H), "v": cr.randf_range(2.0, 5.0), "p": puffs})


# ====================================================================== game setup
func band_of(y: float) -> int:
	return clampi(int(y / BH), 0, NB - 1)


func front_at(y: float) -> float:
	var f := clampf(y / BH - 0.5, 0.0, NB - 1.001)
	var i := int(f)
	return lerpf(F[i], F[i + 1], f - i)


func add_target(type: String, x: float, y: float, extra: Dictionary = {}) -> Dictionary:
	idc += 1
	var d: Dictionary = D.TYPES[type]
	var o := {"id": idc, "k": "tg", "type": type, "x": x, "y": y, "hp": d.hp, "maxhp": d.hp, "alive": true,
		"cool": randf_range(0.0, 3.0), "hidden": false, "reveal": 0.0, "assigned": 0}
	o.merge(extra, true)
	tg.append(o)
	return o


func add_bld(type: String, x: float, y: float, built: bool) -> Dictionary:
	idc += 1
	var d: Dictionary = D.BUILD[type]
	var b := {"id": idc, "k": "bld", "type": type, "x": x, "y": y, "hp": d.hp, "maxhp": d.hp, "alive": true,
		"prog": 1.0 if built else 0.0, "tm": d.t, "warn": 0.0, "rebuild": 0.0, "cool": randf_range(0.0, 2.0),
		"name": "%s %d" % [d.name, idc], "ammo": 6, "lvl": 1, "eng": false, "anim": randf() * 6.0}
	if type == "airfield":
		b["slots"] = []
		b["ang"] = 0.0
		b["own"] = 0
		af_p.append(b)
	bl.append(b)
	return b


func blds(type: String) -> Array:
	return bl.filter(func(b): return b.type == type and b.alive and b.prog >= 1.0)


func count_blds(type: String, include_building: bool = true) -> int:
	var n := 0
	for b in bl:
		if b.type == type and (b.alive or b.prog < 1.0) and (include_building or b.prog >= 1.0):
			n += 1
	return n


func find_free(x: float, y: float, type: String) -> Vector2:
	var best := Vector2(x, y)
	for ring in range(0, 14):
		for k in range(12):
			var ang := TAU * k / 12.0 + ring
			var p := Vector2(x + cos(ang) * ring * 10.0, y + sin(ang) * ring * 10.0)
			if can_place(type, p):
				return p
	return best


func new_game() -> void:
	t = 0.0
	coins = 420.0
	oil = 60.0
	metal = 80.0
	speed = 1
	over = ""
	idc = 0
	acn = 0
	truckn = 0
	fleetn = 0
	for arr in [ac, trucks, fleets, bl, af_p, tg, pr, pt, msl, ea, eu, fires, trail, uavs, shells, smokes, loglist, feed,
			banners, cases, offers, groups, decals]:
		arr.clear()
	unread = 0
	sel = null
	mode = ""
	mode_arg = ""
	route_pts.clear()
	place_type = ""
	mis = 2
	uav_stock = 2
	smoke_n = 2
	shell_n = 20
	med_n = 2
	kills = 0
	kill_val = 0.0
	lost = 0
	cities_taken = 0
	earned = 0.0
	score = 0.0
	income = 0.0
	epow = 1.0
	disc = 1.0
	disc_t = 0.0
	estock = 2.0
	bridge_cut = 0.0
	war_pen = 0.0
	combat_view = false
	ev_t = 80.0
	res_t = 12.0
	sam_t = 60.0
	ea_t = 40.0
	eu_t = 110.0
	ship_t = 10.0
	off_t = 60.0
	wship_t = 90.0
	news_t = 50.0
	otrk_t = 100.0
	fac_t = 0.0
	uav_t = 0.0
	tab = "map"
	for i in range(NB):
		F[i] = W * 0.5 + (fb(n_front, i / 5.0, 3.0) - 0.5) * 150.0
		SUP[i] = 0.0
		NET[i] = 0.0
	for tw in towns:
		tw.side = 0 if tw.x < front_at(tw.y) else 1
		tw.lit = true
		tw.burn = 0.0
	# enemy side
	for j in range(20):
		var y := (j + 0.5) * H / 20.0 * 0.9 + randf_range(-25.0, 25.0)
		add_target("inf", F[band_of(y)] + randf_range(28.0, 70.0), y)
	for f in [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8]:
		var y: float = H * f
		add_target("sam", F[band_of(y)] + randf_range(80.0, 170.0), y)
	for p in ep_pos:
		add_target("plant", p.x, p.y, {"rebuild": 0.0})
	for p in dep_pos:
		add_target("depot", p.x, p.y)
	add_target("afield", afs_pos[2].x, afs_pos[2].y)
	for p in ports_pos:
		add_target("port", p.x, p.y, {"rebuild": 0.0})
	for k in range(2):
		var r: Array = rivers[k]
		var frac := 0.5 if k == 0 else 0.7
		var entry: Array = r[0]
		for e in r:
			if e[0] >= int(GH * frac):
				entry = e
				break
		add_target("bridge", entry[1] * TS + TS, entry[0] * TS, {"rebuild": 0.0})
	for k in range(2):
		spawn_otrk()
	nat.clear()
	for n in D.NATIONS:
		nat.append({"id": n.id, "name": n.name, "c1": Color.html(n.c1), "c2": Color.html(n.c2),
			"mood": 60.0, "inc": 0, "promise": 0.0, "war": false})
	# our buildings
	for i in range(2):
		var a := add_bld("airfield", afs_pos[i].x, afs_pos[i].y, true)
		a.name = "Airfield North" if i == 0 else "Airfield South"
	var pa := add_bld("plant", pp_pos[0].x, pp_pos[0].y, true)
	pa.name = "Power plant 1"
	var pb := add_bld("plant", pp_pos[1].x, pp_pos[1].y, true)
	pb.name = "Power plant 2"
	add_bld("solar", pp_pos[2].x, pp_pos[2].y, true)
	var dp := find_free(afs_pos[0].x + 50.0, afs_pos[0].y + 30.0, "droneport")
	add_bld("droneport", dp.x, dp.y, true)
	var hp := find_free(W * 0.2, sea_y(W * 0.2) - 16.0, "port")
	var hpb: Dictionary = add_bld("port", hp.x, hp.y, true)
	# army groups
	for i in range(MAX_GROUPS):
		var b0 := i * (NB / MAX_GROUPS)
		var b1 := b0 + NB / MAX_GROUPS - 1
		groups.append({"n": i + 1, "b0": b0, "b1": b1, "mode": "attack" if i != 1 else "defend", "str": 60.0, "alive": true,
			"smoke": 0.0, "fight": 0.0, "lost_t": 0.0})
	for i in range(3):
		add_aircraft("atk")
	add_truck()
	var sf = add_fleet_at(hpb)
	if sf != null:
		sf.n = 1
	cam = Vector2(W * 0.3, H * 0.4)
	zoom = vw / 520.0
	clamp_cam()
	reset_tut()
	select(null)
	set_tab("map")
	say("Orders received. Good luck, commander.", "")


func free_slots(af: Dictionary) -> int:
	return 6 - af.slots.size()


func pick_airfield() -> Variant:
	var best = null
	for f in af_p:
		if f.alive and f.prog >= 1.0 and free_slots(f) > 0:
			if best == null or free_slots(f) > free_slots(best):
				best = f
	return best


func add_aircraft(type: String) -> Variant:
	var af = pick_airfield()
	if af == null:
		return null
	acn += 1
	var d: Dictionary = D.ACTYPES[type]
	var a := {"id": acn, "k": "ac", "n": acn, "type": type, "lvl": 1, "x": 0.0, "y": 0.0, "ang": af.ang, "sp": 0.0,
		"hp": d.hp, "maxhp": d.hp, "fuel": 100.0, "gb": d.gb, "rk": d.rk, "aa": d.aa, "cm": d.cm, "hyper": 0,
		"st": "parked", "af": af, "slot": 0, "order": null, "ph": "app", "wp": Vector2.ZERO, "cool": 0.0, "tm": 0.0,
		"aac": 0.0, "tr": 0.0, "loit": Vector2.ZERO, "lx": 0.0, "ly": 0.0, "dead": false, "alt": 0.0, "bank": 0.0,
		"route": [], "ri": 0, "chase": null}
	slot_in(a, af)
	ac.append(a)
	return a


func slot_pos(af: Dictionary, s: int) -> Vector2:
	return Vector2(af.x - 30.0 + (s % 3) * 24.0, af.y + 20.0 + floorf(s / 3.0) * 16.0)


func slot_in(a: Dictionary, af: Dictionary) -> void:
	var s := 0
	while af.slots.has(s):
		s += 1
	af.slots.append(s)
	a.slot = s
	a.af = af
	var p := slot_pos(af, s)
	a.x = p.x
	a.y = p.y
	a.ang = -PI / 2.0


func slot_out(a: Dictionary) -> void:
	var i: int = a.af.slots.find(a.slot)
	if i >= 0:
		a.af.slots.remove_at(i)


func add_truck() -> Variant:
	truckn += 1
	var c: Dictionary = towns[0]
	var tr := {"id": 1000 + truckn, "k": "truck", "n": truckn, "x": c.x + 30.0, "y": c.y + c.r + 14.0, "ang": 0.0, "st": "idle",
		"tx": 0.0, "ty": 0.0, "t": 0.0, "hp": 3.0, "maxhp": 3.0, "dead": false, "fire": null, "dust": 0.0}
	tr.x = clampf(tr.x, 40.0, W * 0.4)
	trucks.append(tr)
	return tr


func add_fleet_at(port: Dictionary) -> Variant:
	fleetn += 1
	var f := {"id": 2000 + fleetn, "k": "fleet", "n": fleetn, "x": port.x + 14.0, "y": sea_y(port.x) + 22.0, "ang": 0.0,
		"ships": 3, "hp": [4.0, 4.0, 4.0], "order": null, "cool": 3.0, "dead": false, "cmcool": 0.0, "wake": 0.0, "mis": 4}
	fleets.append(f)
	return f


func spawn_otrk() -> void:
	var cand: Array = []
	for d in dep_pos:
		cand.append(d)
	var p: Vector2 = cand[randi() % cand.size()]
	add_target("otrk", p.x + randf_range(-60, 60), p.y + randf_range(-40, 60), {"hidden": true, "st": "idle", "t": 0.0,
		"cd": randf_range(50.0, 110.0), "tx": 0.0, "ty": 0.0, "ang": PI})


# ====================================================================== placement rules
func can_place(type: String, p: Vector2) -> bool:
	var d: Dictionary = D.BUILD[type]
	var r: float = d.r
	if p.x < 30.0 or p.y < 30.0 or p.x > W - 30.0 or p.y > H - 30.0:
		return false
	if p.x > front_at(p.y) - 46.0:
		return false
	if type == "port":
		var tt := tile_at(p.x, p.y)
		if tt < 1 or tt > 4:
			return false
		var near_sea := false
		for off in [Vector2(0, 14), Vector2(0, 24), Vector2(14, 0), Vector2(-14, 0), Vector2(0, 34)]:
			if in_sea(p.x + off.x, p.y + off.y):
				near_sea = true
		if not near_sea:
			return false
	else:
		for off in [Vector2(0, 0), Vector2(r * 0.7, 0), Vector2(-r * 0.7, 0), Vector2(0, r * 0.7), Vector2(0, -r * 0.7)]:
			var tt := tile_at(p.x + off.x, p.y + off.y)
			if tt < 2 or tt > 4:
				return false
	for b in bl:
		if b.alive or b.prog < 1.0:
			var br: float = D.BUILD[b.type].r
			if Vector2(b.x - p.x, b.y - p.y).length() < br + r + 6.0:
				return false
	for tw in towns:
		if Vector2(tw.x - p.x, tw.y - p.y).length() < tw.r + r * 0.4:
			return false
	for o in tg:
		if o.alive and Vector2(o.x - p.x, o.y - p.y).length() < 40.0:
			return false
	return true


# ====================================================================== prices and shop
func price(k: String) -> Dictionary:
	var p: Dictionary
	if D.BUY.has(k):
		p = D.BUY[k]
	else:
		p = D.BUILD[k]
	return {"c": ceili(p.c * disc), "m": ceili(p.m * disc), "o": ceili(p.o * disc)}


func can_pay(p: Dictionary) -> bool:
	return coins >= p.c and metal >= p.m and oil >= p.o


func spend(p: Dictionary) -> void:
	coins -= p.c
	metal -= p.m
	oil -= p.o


func money(p: Dictionary) -> String:
	var s: String = "%d" % p.c
	if p.m > 0:
		s += " + %dm" % p.m
	if p.o > 0:
		s += " + %do" % p.o
	return s


func buy(k: String) -> void:
	var p := price(k)
	if not can_pay(p):
		toast("Not enough coins, metal or oil")
		return
	match k:
		"atk", "ftr", "bmb":
			if ac.size() >= 14:
				toast("Too many aircraft (14 max)")
				return
			var a = add_aircraft(k)
			if a == null:
				toast("All hangars are full. Build another airfield.")
				return
			spend(p)
			select(a)
			toast("New %s No.%d delivered" % [String(D.ACTYPES[k].short).to_lower(), a.n])
		"truck":
			if trucks.size() >= 5:
				toast("Maximum 5 launcher trucks")
				return
			spend(p)
			var tr = add_truck()
			toast("Missile truck T%d is ready" % tr.n)
		"msl":
			if mis >= 10:
				toast("Missile depot is full")
				return
			spend(p)
			mis += 1
			toast("Ballistic missile delivered (%d in stock)" % mis)
		"uav":
			if uav_stock >= uav_cap():
				toast("UAV storage is full. Build a drone port.")
				return
			spend(p)
			uav_stock += 1
			toast("UAV delivered (%d in stock)" % uav_stock)
		"fleet":
			var pts: Array = blds("port")
			if pts.is_empty():
				toast("Build a harbor first")
				return
			if fleets.size() >= 3:
				toast("Maximum 3 fleets")
				return
			spend(p)
			var f = add_fleet_at(pts[0])
			select(f)
			toast("Fleet %d launched" % f.n)
		"brig":
			var wk = null
			for g in groups:
				if wk == null or g.str < wk.str:
					wk = g
			if wk.str >= 99.0 and wk.alive:
				toast("All army groups are at full strength")
				return
			spend(p)
			wk.alive = true
			wk.str = minf(100.0, wk.str + 30.0)
			toast("Reinforcements reached group %d" % wk.n)
		"smoke":
			spend(p)
			smoke_n += 2
			toast("Smoke canisters: %d" % smoke_n)
		"shell":
			spend(p)
			shell_n += 10
			toast("Artillery shells: %d" % shell_n)
		"med":
			spend(p)
			med_n += 2
			toast("Field hospitals: %d" % med_n)
	disc_check()


func disc_check() -> void:
	pass


func uav_cap() -> int:
	return 2 + 4 * count_blds("droneport", false)


func start_build(type: String, pos: Vector2) -> void:
	var p := price(type)
	if not can_pay(p):
		toast("Not enough resources")
		return
	if not can_place(type, pos):
		toast("You cannot build here")
		return
	spend(p)
	var b := add_bld(type, pos.x, pos.y, false)
	b.prog = 0.0
	say("Construction started: %s" % D.BUILD[type].name, "")
	mode = ""
	place_type = ""


func upgrade_cost(a: Dictionary) -> int:
	if a.lvl >= 4:
		return 0
	return D.UP_COST[a.lvl]


func upgrade_aircraft(a: Dictionary) -> void:
	if a.lvl >= 4:
		toast("Maximum level")
		return
	if a.st != "parked" and a.st != "rearm":
		toast("Land the aircraft first")
		return
	var cost := upgrade_cost(a)
	if coins < cost:
		toast("Upgrade costs %d coins" % cost)
		return
	coins -= cost
	a.lvl += 1
	a.maxhp += 1
	a.hp = a.maxhp
	var d: Dictionary = D.ACTYPES[a.type]
	a.gb = d.gb + (a.lvl - 1) if d.gb > 0 else 0
	a.rk = d.rk + (a.lvl - 1) * 4 if d.rk > 0 else 0
	a.aa = d.aa + (a.lvl - 1) if d.aa > 0 else 0
	say("Aircraft No.%d upgraded to level %d" % [a.n, a.lvl], "good")


func buy_hyper(a: Dictionary) -> void:
	if a.type != "ftr":
		toast("Only fighters can carry a hypersonic missile")
		return
	if a.hyper >= 1:
		toast("Hypersonic missile already mounted")
		return
	if a.st != "parked" and a.st != "rearm":
		toast("Land the fighter first")
		return
	var p: Dictionary = D.HYPER_COST
	if not can_pay(p):
		toast("Not enough resources")
		return
	spend(p)
	a.hyper = 1
	say("Hypersonic missile mounted on fighter No.%d" % a.n, "good")


# ====================================================================== messages
func toast(m: String) -> void:
	if l_toast == null:
		return
	l_toast.text = m
	pn_toast.visible = true
	toast_t = 2.8


func say(m: String, kind: String = "", show_toast: bool = false) -> void:
	loglist.push_front({"t": t, "m": m, "k": kind})
	if loglist.size() > 50:
		loglist.pop_back()
	unread += 1
	feed.push_front({"m": m, "k": kind, "life": 9.0})
	if feed.size() > 12:
		feed.pop_back()
	if show_toast:
		toast(m)
	feed_dirty = true


func banner(text: String, kind: String, sub: String = "") -> void:
	banners.push_front({"m": text, "k": kind, "s": sub, "life": 5.0})
	if banners.size() > 2:
		banners.pop_back()
	feed_dirty = true


func tstr(s: float) -> String:
	var v := maxf(0.0, s)
	return "%d:%02d" % [int(v / 60.0), int(fmod(v, 60.0))]


# ====================================================================== combat helpers
func boom(x: float, y: float, s: float) -> void:
	pt.append({"k": "flash", "x": x, "y": y, "vx": 0.0, "vy": 0.0, "l": 0.18, "m": 0.18, "s": 9.0 * s})
	pt.append({"k": "ring", "x": x, "y": y, "vx": 0.0, "vy": 0.0, "l": 0.5, "m": 0.5, "s": 10.0 * s})
	for i in range(int(9 * s)):
		var a := randf() * TAU
		var v := randf_range(10.0, 55.0) * s
		pt.append({"k": "fire", "x": x, "y": y, "vx": cos(a) * v, "vy": sin(a) * v - 12.0,
			"l": randf_range(0.3, 0.8), "m": 0.8, "s": randf_range(2, 4.5) * sqrt(s)})
	for i in range(int(5 * s)):
		var a := randf() * TAU
		var v := randf_range(20.0, 70.0) * s
		pt.append({"k": "deb", "x": x, "y": y, "vx": cos(a) * v, "vy": sin(a) * v - 20.0, "l": randf_range(0.6, 1.3), "m": 1.3,
			"s": 2.0, "c": Color(0.2, 0.17, 0.14)})
	for i in range(int(4 * s)):
		pt.append({"k": "smoke", "x": x + randf_range(-5, 5), "y": y + randf_range(-5, 5), "vx": randf_range(-8, 8),
			"vy": randf_range(-16, -5), "l": randf_range(2.4, 4.4), "m": 4.4, "s": randf_range(5, 9) * sqrt(s), "dark": true})
	if s >= 1.0 and decals.size() < 160:
		decals.append({"x": x + randf_range(-3, 3), "y": y + randf_range(-3, 3), "r": 3.0 + 2.5 * s, "l": 150.0})


func boom_chain(x: float, y: float, n: int) -> void:
	for i in range(n):
		pend.append({"t": 0.25 + i * 0.3, "x": x + randf_range(-14, 14), "y": y + randf_range(-10, 10), "s": randf_range(0.8, 1.4)})


func hit_target(o: Dictionary, dmg: float) -> void:
	if not o.alive:
		return
	o.hp -= dmg
	if o.hp <= 0.0:
		kill_target(o, true)


func kill_target(o: Dictionary, by_player: bool) -> void:
	if o.type == "ship" or o.type == "wship":
		o.alive = false
		ship_sunk(o)
		return
	o.alive = false
	var big: bool = o.type == "plant" or o.type == "afield"
	boom(o.x, o.y, 3.0 if big else 1.6)
	fires.append({"x": o.x, "y": o.y, "t": 40.0 if o.type == "plant" else 18.0})
	var d: Dictionary = D.TYPES[o.type]
	if by_player:
		coins += d.rew
		kills += 1
		kill_val += d.rew
		say("%s destroyed  +%d" % [d.name, d.rew], "good")
	else:
		coins += d.rew * 0.4
		say("%s overrun by our ground forces" % d.name, "good")
	if o.type == "inf":
		for i in range(NB):
			var w := 1.0 - absf((i + 0.5) * BH - o.y) / 160.0
			if w > 0.0:
				SUP[i] += 0.5 * w
	elif o.type == "plant":
		o.rebuild = 110.0
		say("Karmin power grid is failing. Cities are going dark.", "good")
	elif o.type == "port":
		o.rebuild = 120.0
	elif o.type == "depot":
		boom_chain(o.x, o.y, 3)
		estock = maxf(0.0, estock - 1.0)
	elif o.type == "bridge":
		o.rebuild = 160.0
		bridge_cut = 100.0
		banner("BRIDGE DESTROYED", "good", "Enemy supply is cut. Sappers will build a crossing.")
		boom_chain(o.x, o.y, 4)
	elif o.type == "otrk":
		o.rebuild = 160.0
		say("Missile launcher truck destroyed. Karmin will bring another.", "good")
		otrk_t = minf(otrk_t, 140.0)


func damage_aircraft(a: Dictionary, dmg: int) -> void:
	a.hp -= dmg
	pt.append({"k": "smoke", "x": a.x, "y": a.y, "vx": 0.0, "vy": 0.0, "l": 2.0, "m": 2.0, "s": 5.0, "dark": true})
	if a.hp <= 0:
		crash(a, "Aircraft No.%d shot down" % a.n)
	else:
		toast("Aircraft No.%d is hit!" % a.n)


func crash(a: Dictionary, msg: String) -> void:
	boom(a.x, a.y, 1.4)
	a.dead = true
	lost += 1
	if sel != null and is_same(sel, a):
		select(null)
	say(msg, "bad", true)
	chips_dirty = true


func proj(k: String, from: Dictionary, to, extra: Dictionary = {}) -> Dictionary:
	var p := {"k": k, "x": from.x, "y": from.y, "sx": from.x, "sy": from.y, "tx": to.x, "ty": to.y, "tg": to,
		"t": 0.0, "dur": 0.7, "dmg": 0.0, "hit": false, "done": false, "tr": 0.0}
	p.merge(extra, true)
	pr.append(p)
	return p


func airborne(a: Dictionary) -> bool:
	return a.st == "fly" or a.st == "loiter" or a.st == "rtb" or a.st == "takeoff"


func enemy_air() -> Array:
	var out: Array = []
	for e in ea:
		if e.hp > 0:
			out.append(e)
	for e in eu:
		if e.hp > 0:
			out.append(e)
	return out


func spd(a: Dictionary) -> float:
	return float(D.ACTYPES[a.type].sp) * (1.0 + 0.07 * (a.lvl - 1))


# ====================================================================== orders
func nearest_af(a: Dictionary) -> Dictionary:
	var best: Dictionary = af_p[0]
	var bd := 1e9
	for f in af_p:
		if not f.alive or f.prog < 1.0:
			continue
		var d := Vector2(f.x - a.x, f.y - a.y).length() + (0.0 if free_slots(f) > 0 else 400.0)
		if d < bd:
			bd = d
			best = f
	return best


func engage(a: Dictionary) -> void:
	var o = a.order
	if o == null:
		a.st = "loiter"
		a.loit = Vector2(a.x + 60.0 * cos(a.ang), a.y + 60.0 * sin(a.ang))
		return
	if o.t == "attack":
		a.st = "fly"
		a.ph = "app"
	elif o.t == "loiter":
		a.st = "loiter"
		a.loit = Vector2(o.x, o.y)
	elif o.t == "route":
		a.st = "fly"
		a.route = o.pts.duplicate()
		a.ri = 0
	else:
		a.st = "rtb"
		a.af = o.af if o.has("af") else nearest_af(a)


func set_order(a: Dictionary, o) -> void:
	if a.order != null and a.order.t == "attack" and a.order.has("tg"):
		a.order.tg.assigned = maxi(0, a.order.tg.assigned - 1)
	a.order = o
	if o != null and o.t == "attack":
		o.tg.assigned += 1


func give_order(a: Dictionary, o: Dictionary) -> void:
	if a.st == "landing" or a.st == "rearm":
		toast("No.%d is on the ground, rearming" % a.n)
		return
	if a.st == "parked" or a.st == "taxi":
		if o.t == "rtb":
			return
		if o.t == "attack" and a.gb + a.rk + a.cm <= 0:
			toast("Ordnance empty")
			return
		if a.st == "parked":
			slot_out(a)
			a.st = "taxi"
			a.tm = 0.0
			a.sp = 0.0
			a.lx = a.x
			a.ly = a.y
		set_order(a, o)
		return
	if o.t == "attack" and a.gb + a.rk + a.cm <= 0:
		toast("No.%d is out of ordnance" % a.n)
		o = {"t": "rtb"}
	set_order(a, o)
	engage(a)


func finish_rearm(a: Dictionary) -> void:
	var d: Dictionary = D.ACTYPES[a.type]
	var gbm: int = d.gb + (a.lvl - 1) if d.gb > 0 else 0
	var rkm: int = d.rk + (a.lvl - 1) * 4 if d.rk > 0 else 0
	var aam: int = d.aa + (a.lvl - 1) if d.aa > 0 else 0
	var w1: int = mini(gbm - a.gb, int(coins / 8.0))
	coins -= w1 * 8
	a.gb += w1
	var w2: int = mini(aam - a.aa, int(coins / 12.0))
	coins -= w2 * 12
	a.aa += w2
	var w3: int = mini(rkm - a.rk, int(coins))
	coins -= w3
	a.rk += w3
	if d.cm > 0:
		var w4: int = mini(d.cm - a.cm, int(coins / 40.0))
		coins -= w4 * 40
		a.cm += w4
	a.fuel = 100.0
	a.hp = a.maxhp
	a.st = "parked"
	a.order = null
	a.chase = null
	if a.gb < gbm or a.aa < aam or a.rk < rkm:
		toast("No.%d only partly rearmed: not enough coins" % a.n)


# ====================================================================== aircraft update
func steer(a: Dictionary, tx: float, ty: float, dt: float, tr: float = TURN) -> void:
	var dd := wrapf(atan2(ty - a.y, tx - a.x) - a.ang, -PI, PI)
	var m := tr * dt
	var turn := clampf(dd, -m, m)
	a.ang += turn
	a.bank = lerpf(a.bank, clampf(turn / maxf(0.001, m), -1.0, 1.0), minf(1.0, dt * 6.0))
	var s := spd(a)
	a.sp = minf(s, a.sp + 60.0 * dt)
	a.x += cos(a.ang) * a.sp * dt
	a.y += sin(a.ang) * a.sp * dt


func ground_hit_pos(target: Dictionary, spread: float) -> Dictionary:
	return {"x": target.x + randf_range(-spread, spread), "y": target.y + randf_range(-spread, spread)}


func attack_pass(a: Dictionary) -> void:
	var o: Dictionary = a.order
	var target: Dictionary = o.tg
	if a.gb > 0:
		var n: int = 1 if a.type == "atk" else mini(4, a.gb)
		for i in range(n):
			a.gb -= 1
			var aim := ground_hit_pos(target, 3.0 if n == 1 else 12.0)
			proj("gb", a, aim, {"dmg": GB_DMG, "dur": 0.85 + i * 0.12, "tg": target})
	if a.rk > 0:
		var n2 := mini(4, a.rk)
		a.rk -= n2
		for i in range(n2):
			var aim2 := ground_hit_pos(target, 9.0)
			proj("rk", a, aim2, {"dmg": RK_DMG, "dur": 0.5 + i * 0.07, "tg": target})
	if a.gb + a.rk <= 0 and a.cm <= 0:
		set_order(a, {"t": "rtb"})
		a.st = "rtb"
		a.af = nearest_af(a)
		toast("No.%d is out of ordnance. Returning." % a.n)


func launch_cruise(a: Dictionary, target: Dictionary) -> void:
	for i in range(a.cm):
		var d := Vector2(target.x - a.x, target.y - a.y).length()
		msl.append({"side": 0, "kind": "cru", "sx": a.x, "sy": a.y + i * 6.0, "tx": target.x + randf_range(-6, 6),
			"ty": target.y + randf_range(-6, 6), "t": -i * 0.6, "dur": d / 150.0 + 0.5, "tgt": target, "done": false, "fade": 2.0,
			"name": "Cruise missile"})
	a.cm = 0
	say("Bomber %d: cruise missiles launched." % a.n, "")


func fire_hyper(a: Dictionary, target: Dictionary) -> void:
	if a.hyper <= 0:
		return
	a.hyper = 0
	var d := Vector2(target.x - a.x, target.y - a.y).length()
	proj("hyp", a, target, {"dur": 0.5 + d / 1100.0, "dmg": 12.0, "tg": target})
	say("Hypersonic missile fired by fighter %d" % a.n, "")
	banner("HYPERSONIC STRIKE", "good", "Impact in %.1fs" % (0.5 + d / 1100.0))


func upd_aircraft(a: Dictionary, dt: float) -> void:
	a.cool -= dt
	a.aac -= dt
	if a.st == "parked":
		a.alt = 0.0
		return
	if a.st == "rearm":
		a.tm -= dt
		a.alt = 0.0
		if a.tm <= 0.0:
			finish_rearm(a)
		return
	if a.st == "taxi":
		a.tm += dt
		var rw := Vector2(a.af.x - 44.0, a.af.y)
		var u := clampf(a.tm / 1.5, 0.0, 1.0)
		a.x = lerpf(a.lx, rw.x, u)
		a.y = lerpf(a.ly, rw.y, u)
		a.ang = atan2(rw.y - a.ly, rw.x - a.lx) if u < 1.0 else 0.0
		a.sp = 20.0
		if u >= 1.0:
			a.st = "takeoff"
			a.tm = 0.0
			a.sp = 0.0
			a.ang = 0.0
		return
	if a.st == "landing":
		a.tm += dt
		var u2 := clampf(a.tm / 1.8, 0.0, 1.0)
		var sp := slot_pos(a.af, a.slot)
		a.x = lerpf(a.lx, sp.x, u2)
		a.y = lerpf(a.ly, sp.y, u2)
		a.sp = lerpf(spd(a) * 0.5, 0.0, u2)
		a.alt = 1.0 - u2
		if u2 >= 1.0:
			a.st = "rearm"
			a.tm = 6.0
			a.ang = -PI / 2.0
		return
	var d: Dictionary = D.ACTYPES[a.type]
	a.fuel -= float(d.burn) * dt
	if a.fuel <= 0.0:
		crash(a, "Aircraft No.%d ran out of fuel and crashed" % a.n)
		return
	if a.st == "takeoff":
		a.tm += dt
		a.sp = minf(spd(a), a.sp + spd(a) / 2.0 * dt)
		a.ang = 0.0
		a.x += cos(a.ang) * a.sp * dt
		a.y += sin(a.ang) * a.sp * dt
		a.alt = clampf(a.tm / 2.2, 0.0, 1.0)
		if a.tm >= 2.2:
			engage(a)
		trail_add(a, dt)
		return
	a.alt = 1.0
	if a.st == "fly" or a.st == "loiter":
		var home := nearest_af(a)
		var need := Vector2(a.x - home.x, a.y - home.y).length() / spd(a) * float(d.burn) + 9.0
		if a.fuel < need:
			set_order(a, {"t": "rtb"})
			a.st = "rtb"
			a.af = home
			toast("No.%d is low on fuel. Returning." % a.n)
	if a.st == "fly":
		var o = a.order
		if o != null and o.t == "route":
			if a.ri >= a.route.size():
				var lp: Vector2 = a.route[a.route.size() - 1]
				set_order(a, {"t": "loiter", "x": lp.x, "y": lp.y})
				a.st = "loiter"
				a.loit = lp
			else:
				var wp: Vector2 = a.route[a.ri]
				steer(a, wp.x, wp.y, dt)
				if Vector2(a.x - wp.x, a.y - wp.y).length() < 16.0:
					a.ri += 1
		elif o == null or o.t != "attack" or not o.tg.alive:
			var px: float = a.x
			var py: float = a.y
			if o != null and o.has("tg"):
				px = o.tg.x
				py = o.tg.y
			set_order(a, {"t": "loiter", "x": px, "y": py})
			a.st = "loiter"
			a.loit = Vector2(px, py)
			if o != null and o.has("tg"):
				toast("Target down. No.%d is loitering." % a.n)
		elif a.ph == "app":
			var target: Dictionary = o.tg
			steer(a, target.x, target.y, dt)
			var dist := Vector2(a.x - target.x, a.y - target.y).length()
			if a.cm > 0 and dist < 300.0:
				launch_cruise(a, target)
				if a.gb + a.rk <= 0:
					set_order(a, {"t": "rtb"})
					a.st = "rtb"
					a.af = nearest_af(a)
					banner("LAUNCH COMPLETE", "good", "Bomber %d returning to base" % a.n)
			elif dist < 20.0 and a.cool <= 0.0 and a.gb + a.rk > 0:
				attack_pass(a)
				a.cool = 3.5
				if a.st == "fly":
					a.ph = "egr"
					var g := atan2(target.y - a.y, target.x - a.x) + randf_range(-0.6, 0.6)
					a.wp = Vector2(target.x + cos(g) * 70.0, target.y + sin(g) * 70.0)
		else:
			steer(a, a.wp.x, a.wp.y, dt)
			if Vector2(a.x - a.wp.x, a.y - a.wp.y).length() < 14.0:
				a.ph = "app"
	elif a.st == "loiter":
		var l: Vector2 = a.loit
		var ch = null
		if a.aa > 0 and a.type == "ftr":
			var bd := 280.0
			for e in enemy_air():
				var dd := Vector2(e.x - a.x, e.y - a.y).length()
				if dd < bd:
					bd = dd
					ch = e
		if ch != null:
			steer(a, ch.x, ch.y, dt, TURN * 1.3)
		elif Vector2(a.x - l.x, a.y - l.y).length() > 85.0:
			steer(a, l.x, l.y, dt)
		else:
			a.ang += 1.5 * dt
			a.bank = lerpf(a.bank, 0.8, minf(1.0, dt * 4.0))
			a.sp = minf(spd(a), a.sp + 60.0 * dt)
			a.x += cos(a.ang) * a.sp * dt
			a.y += sin(a.ang) * a.sp * dt
	elif a.st == "rtb":
		var f: Dictionary = a.af
		steer(a, f.x - 10.0, f.y + 14.0, dt)
		if Vector2(a.x - f.x + 10.0, a.y - f.y - 14.0).length() < 16.0:
			if free_slots(f) <= 0:
				a.af = nearest_af(a)
			else:
				slot_in(a, f)
				a.lx = a.x
				a.ly = a.y
				a.st = "landing"
				a.tm = 0.0
				set_order(a, null)
	trail_add(a, dt)
	if a.aa > 0 and a.aac <= 0.0:
		var rng_aa := 130.0 if a.type == "ftr" else 80.0
		for e in enemy_air():
			if Vector2(e.x - a.x, e.y - a.y).length() < rng_aa:
				a.aa -= 1
				a.aac = 1.8 if a.type == "ftr" else 2.5
				proj("aa", a, e, {"dur": 0.5, "hit": randf() < (0.8 if a.type == "ftr" else 0.6)})
				break
	a.x = clampf(a.x, 0.0, W)
	a.y = clampf(a.y, 0.0, H)
	# spotting hidden units
	for o in tg:
		if o.alive and o.hidden and Vector2(o.x - a.x, o.y - a.y).length() < 100.0:
			o.reveal = maxf(o.reveal, 4.0)


func trail_add(a: Dictionary, dt: float) -> void:
	a.tr -= dt
	if a.tr <= 0.0:
		a.tr = 0.07
		var heavy: bool = a.type == "bmb"
		trail.append({"x": a.x - cos(a.ang) * 4.0, "y": a.y - sin(a.ang) * 4.0, "l": 1.6, "m": 1.6, "w": 2.6 if heavy else 2.0})


# ====================================================================== economy, power grid, buildings
func calc_grid() -> void:
	supply = 0.0
	for b in bl:
		if b.alive and b.prog >= 1.0:
			if b.type == "plant":
				supply += 1.0
			elif b.type == "solar":
				supply += 0.5
	var mine: Array = []
	for tw in towns:
		if tw.side == 0:
			mine.append(tw)
	mine.sort_custom(func(a, b): return (1000 if a.cap else 0) + a.pop > (1000 if b.cap else 0) + b.pop)
	demand = 0.0
	var left := supply
	var dn := 0
	for tw in mine:
		var need := 0.7 if tw.cap else 0.3
		demand += need
		if left >= need - 0.001:
			left -= need
			tw.lit = true
		else:
			tw.lit = false
			dn += 1
	if dn != dark_n:
		if dn > dark_n and started:
			banner("GRID OVERLOADED  %.1f/%.1f" % [supply, demand], "warn",
				"Cities without light: %d. Build a power plant or a solar station." % dn)
		dark_n = dn
	# enemy side
	var ep_alive := 0
	var ep_n := 0
	for o in tg:
		if o.type == "plant":
			ep_n += 1
			if o.alive:
				ep_alive += 1
	epow = float(ep_alive) / maxf(1.0, ep_n)
	var eleft := float(ep_alive)
	var theirs: Array = []
	for tw in towns:
		if tw.side == 1:
			theirs.append(tw)
	theirs.sort_custom(func(a, b): return (1000 if a.cap else 0) + a.pop > (1000 if b.cap else 0) + b.pop)
	for tw in theirs:
		var need2 := 0.7 if tw.cap else 0.3
		if eleft >= need2 - 0.001:
			eleft -= need2
			tw.lit = true
		else:
			tw.lit = false


func upd_econ(dt: float) -> void:
	income = 0.45
	for tw in towns:
		if tw.side == 0:
			income += 0.28 if tw.lit else 0.08
	income *= (1.0 - war_pen * 0.4)
	coins += income * dt
	earned += income * dt
	oil_rate = 0.12
	metal_rate = 0.10
	stock_cap = 200.0
	for b in bl:
		if b.alive and b.prog >= 1.0:
			if b.type == "derrick":
				oil_rate += 0.12
			elif b.type == "mine":
				metal_rate += 0.09
			elif b.type == "warehouse":
				stock_cap += 100.0
	oil = minf(stock_cap, oil + oil_rate * dt)
	metal = minf(stock_cap, metal + metal_rate * dt)
	estock = maxf(0.0, estock - 0.01 * dt)
	score = earned * 2.5 + kill_val * 8.0 + cities_taken * 400.0 + coins * 0.5
	if score >= D.GOAL and over == "":
		finish("score")


func upd_build(dt: float) -> void:
	var nf := 0
	var nu := 0
	for b in bl:
		b.warn = maxf(0.0, b.warn - dt)
		b.anim += dt
		if b.prog < 1.0 and b.alive:
			b.prog = minf(1.0, b.prog + dt / float(D.BUILD[b.type].t))
			if randf() < dt * 6.0:
				pt.append({"k": "smoke", "x": b.x + randf_range(-6, 6), "y": b.y + 4, "vx": randf_range(-3, 3), "vy": -randf_range(6, 12),
					"l": 1.4, "m": 1.4, "s": 3.0})
			if b.prog >= 1.0:
				say("%s is ready" % D.BUILD[b.type].name, "good")
				toast("%s is ready" % D.BUILD[b.type].name)
				if b.type == "airfield":
					carve(b.x, b.y, 30.0)
		elif b.alive:
			b.hp = minf(b.maxhp, b.hp + 0.05 * dt)
			if b.type == "rocketfac":
				nf += 1
			elif b.type == "uavfac":
				nu += 1
		elif not b.alive:
			b.rebuild -= dt
			if b.rebuild <= 0.0:
				b.alive = true
				b.hp = ceilf(b.maxhp / 2.0)
				b.prog = 1.0
				say("%s is back online" % b.name, "good")
	if nf > 0:
		fac_t += dt * nf
		if fac_t >= 80.0:
			fac_t = 0.0
			if mis < 10 and oil >= 10.0 and metal >= 20.0:
				oil -= 10.0
				metal -= 20.0
				mis += 1
				say("Rocket factory: ballistic missile ready (%d)" % mis, "good", true)
	if nu > 0:
		uav_t += dt * nu
		if uav_t >= 20.0:
			uav_t = 0.0
			if uav_stock < uav_cap():
				uav_stock += 1
	for tw in towns:
		tw.burn = maxf(0.0, tw.burn - dt)
	# smoke screens and decals age
	for s in smokes:
		s.t -= dt
	smokes = smokes.filter(func(s): return s.t > 0.0)
	for d in decals:
		d.l -= dt
	decals = decals.filter(func(d): return d.l > 0.0)
	for p in pend:
		p.t -= dt
		if p.t <= 0.0:
			boom(p.x, p.y, p.s)
	pend = pend.filter(func(p): return p.t > 0.0)


# ====================================================================== ground war: army groups, front line, cities
func group_of_band(i: int) -> Variant:
	for g in groups:
		if i >= g.b0 and i <= g.b1:
			return g
	return null


func group_pos(g: Dictionary) -> Vector2:
	var y: float = (g.b0 + g.b1 + 1) / 2.0 * BH
	return Vector2(front_at(y) - 36.0, y)


func upd_ground(dt: float) -> void:
	var power := 0.8 + 0.2 * (1.0 - float(dark_n) / maxf(1.0, float(towns.size() / 2)))
	var eg := {}
	for g in groups:
		eg[g.n] = 0.0
	for i in range(NB):
		var yc := (i + 0.5) * BH
		var s := 0.0
		for o in tg:
			if o.alive and o.type == "inf":
				s += maxf(0.0, 1.0 - absf(o.y - yc) / 90.0)
		var g = group_of_band(i)
		var pw := 0.5
		if g != null and g.alive:
			var base: float = 0.35 + 0.012 * g.str
			pw = base * (1.35 if g.mode == "attack" else 0.9)
		var p: float = (pw + 0.0) * power - war_pen
		var e := (0.82 + 0.6 * s) * (0.75 + 0.25 * epow) + 0.035 * estock - SUP[i]
		if bridge_cut > 0.0:
			e *= 0.72
		if g != null and g.smoke > 0.0:
			e *= 0.85
		NET[i] = p - e
		if g != null and g.mode == "defend":
			NET[i] = maxf(NET[i], -0.25)
		SUP[i] = maxf(0.0, SUP[i] - 0.012 * dt)
		if g != null:
			eg[g.n] += e / float(g.b1 - g.b0 + 1)
	bridge_cut = maxf(0.0, bridge_cut - dt)
	for g in groups:
		g.smoke = maxf(0.0, g.smoke - dt)
		g.fight = maxf(0.0, g.fight - dt)
		if not g.alive:
			continue
		var att: bool = g.mode == "attack"
		var loss := (0.04 + 0.1 * float(eg[g.n])) * (1.6 if att else 0.8) * 0.35 * (0.6 if g.smoke > 0.0 else 1.0)
		g.str -= loss * dt
		if not att:
			g.str = minf(100.0, g.str + 0.05 * dt)
		if att:
			g.fight = 2.0
		if g.str <= 0.0:
			g.str = 0.0
			g.alive = false
			banner("GROUP %d DESTROYED" % g.n, "bad", "Buy a brigade at HQ to rebuild it.")
			say("Army group %d was destroyed" % g.n, "bad")
	for i in range(NB):
		F[i] = clampf(F[i] + NET[i] * 2.2 * dt, 90.0, W - 90.0)
	var c := F.duplicate()
	for i in range(NB):
		var a: float = c[maxi(0, i - 1)]
		var b: float = c[mini(NB - 1, i + 1)]
		F[i] += ((a + b) / 2.0 - c[i]) * 0.35 * dt
	for o in tg:
		if o.alive and o.type != "ship" and o.type != "wship" and o.type != "otrk" and o.x < front_at(o.y) + 6.0:
			kill_target(o, false)
	for tw in towns:
		var ns := 0 if tw.x < front_at(tw.y) else 1
		if ns != tw.side:
			tw.side = ns
			if ns == 0:
				cities_taken += 1
				coins += 90.0
				banner("CITY CAPTURED", "good", "%s is ours. +90 coins, more income, more power needed." % tw.name)
				say("City captured: %s" % tw.name, "good")
			else:
				coins = maxf(0.0, coins - 40.0)
				banner("CITY LOST: %s" % String(tw.name).to_upper(), "bad", "TO BATTLE")
				say("City lost: %s" % tw.name, "bad")
	var ci := band_of(ecap.y)
	var pi2 := band_of(pcap.y)
	var wf := (F[ci - 1] + F[ci] + F[ci + 1]) / 3.0
	var lf := (F[pi2 - 1] + F[pi2] + F[pi2 + 1]) / 3.0
	if wf >= ecap.x - 30.0:
		finish("win")
	elif lf <= pcap.x + 30.0:
		finish("lose")


# ====================================================================== enemy AI
func upd_enemy(dt: float) -> void:
	res_t -= dt
	if res_t <= 0.0:
		res_t = 16.0
		var inf_list: Array = tg.filter(func(o): return o.alive and o.type == "inf")
		if inf_list.size() < 14:
			var best := 0
			var bc := 99.0
			for j in range(12):
				var y0 := j * H * 0.9 / 12.0
				var y1 := y0 + H * 0.9 / 12.0
				var c := 0.0
				for o in inf_list:
					if o.y >= y0 and o.y < y1:
						c += 1.0
				c += randf()
				if c < bc:
					bc = c
					best = j
			var y := (best + 0.5) * H * 0.9 / 12.0 + randf_range(-30.0, 30.0)
			add_target("inf", front_at(y) + randf_range(30.0, 80.0), y)
	sam_t -= dt
	if sam_t <= 0.0:
		sam_t = 100.0
		var sams: Array = tg.filter(func(o): return o.alive and o.type == "sam")
		if sams.size() < 5:
			var y := randf_range(H * 0.1, H * 0.8)
			add_target("sam", front_at(y) + randf_range(90.0, 170.0), y)
			say("Enemy has set up a new air defense site", "bad")
	for o in tg:
		if not o.alive and (o.type == "plant" or o.type == "port" or o.type == "bridge" or o.type == "otrk") and o.rebuild > 0.0:
			o.rebuild -= dt
			if o.rebuild <= 0.0:
				o.alive = true
				o.hp = ceilf(o.maxhp / 2.0)
				if o.type == "bridge":
					say("Enemy sappers restored the bridge", "bad")
				if o.type == "otrk":
					var d: Vector2 = dep_pos[randi() % dep_pos.size()]
					o.x = d.x + randf_range(-40, 40)
					o.y = d.y + randf_range(-30, 50)
					o.hidden = true
					o.reveal = 0.0
					o.st = "idle"
					o.cd = randf_range(60.0, 100.0)
	# hidden units fade back into hiding
	for o in tg:
		if o.alive and o.hidden:
			o.reveal = maxf(0.0, o.reveal - dt)
	# enemy air defense sites
	for s in tg:
		if not s.alive or s.type != "sam":
			continue
		s.cool -= dt
		s.eng = false
		var target = null
		var bd := 88.0
		for a in ac:
			if not a.dead and airborne(a):
				var d := Vector2(a.x - s.x, a.y - s.y).length()
				if d < bd:
					bd = d
					target = a
		if target != null:
			s.eng = true
			if s.cool <= 0.0:
				s.cool = 4.2
				proj("sam", s, target, {"dur": 0.8, "hit": randf() < 0.28})
	# interceptors
	ea_t -= dt
	var afl = null
	for o in tg:
		if o.type == "afield" and o.alive:
			afl = o
	if ea_t <= 0.0:
		ea_t = 55.0
		var any_air := false
		for a in ac:
			if not a.dead and airborne(a):
				any_air = true
		if afl != null and ea.size() < 2 and any_air:
			idc += 1
			ea.append({"id": idc, "k": "ea", "x": afl.x, "y": afl.y, "ang": PI, "hp": 1, "life": 70.0, "cool": 1.5})
			say("Enemy interceptor scrambled", "bad")
	for e in ea:
		e.life -= dt
		e.cool -= dt
		var target = null
		var bd := 500.0
		for a in ac:
			if not a.dead and airborne(a):
				var d := Vector2(a.x - e.x, a.y - e.y).length()
				if d < bd:
					bd = d
					target = a
		var home := Vector2(W, H * 0.2)
		if afl != null:
			home = Vector2(afl.x, afl.y)
		var goal := home
		if target != null and e.life > 0.0:
			goal = Vector2(target.x, target.y)
		var dd := wrapf(atan2(goal.y - e.y, goal.x - e.x) - e.ang, -PI, PI)
		e.ang += clampf(dd, -1.8 * dt, 1.8 * dt)
		e.x += cos(e.ang) * 88.0 * dt
		e.y += sin(e.ang) * 88.0 * dt
		if target != null and bd < 52.0 and e.cool <= 0.0:
			e.cool = 1.4
			var cover := 0.12 * count_blds("sam", false) + 0.1 * count_blds("lsam", false)
			proj("ab", e, target, {"dur": 0.18, "hit": randf() < 0.3 * (1.0 - minf(0.5, cover))})
		if target == null and e.life < 0.0 and Vector2(e.x - home.x, e.y - home.y).length() < 30.0:
			e.hp = 0
	ea = ea.filter(func(e): return e.hp > 0 and e.life > -30.0)
	# enemy missile trucks
	for o in tg:
		if not o.alive or o.type != "otrk":
			continue
		upd_enemy_truck(o, dt)
	# enemy drone waves
	eu_t -= dt
	if eu_t <= 0.0:
		eu_t = randf_range(120.0, 170.0)
		var targets: Array = bl.filter(func(b): return b.alive and b.prog >= 1.0)
		if not targets.is_empty():
			var n := randi_range(2, 4) + int(t / 400.0)
			for i in range(n):
				var tgt: Dictionary = targets[randi() % targets.size()]
				idc += 1
				eu.append({"id": idc, "k": "eu", "x": W + 20.0 + i * 14.0, "y": randf_range(H * 0.1, H * 0.8), "ang": PI, "hp": 1, "tg": tgt,
					"life": 70.0, "tr": 0.0})
			say("INBOUND: %d enemy drones heading for our rear" % n, "bad")
			banner("INBOUND DRONES x%d" % n, "bad", "Air defense and fighters will engage them.")


func upd_enemy_truck(o: Dictionary, dt: float) -> void:
	o.cd -= dt
	if o.reveal > 0.0 and o.st == "idle" and o.reveal > 12.0:
		o.reveal = 12.0
	if o.st == "idle":
		# small patrol drift along the depot area
		if randf() < dt * 0.4:
			o.tx = clampf(o.x + randf_range(-40, 40), W * 0.6, W * 0.9)
			o.ty = clampf(o.y + randf_range(-40, 40), 60.0, H * 0.82)
		var dd := Vector2(o.tx - o.x, o.ty - o.y)
		if o.tx != 0.0 and dd.length() > 4.0:
			o.ang = dd.angle()
			o.x += dd.normalized().x * 12.0 * dt
			o.y += dd.normalized().y * 12.0 * dt
		if o.cd <= 0.0:
			var targets: Array = bl.filter(func(b): return b.alive and b.prog >= 1.0)
			if not targets.is_empty():
				var w: Dictionary = targets[randi() % targets.size()]
				for b in targets:
					if b.type == "plant" and randf() < 0.4:
						w = b
				o["tgt"] = w
				o.st = "deploy"
				o.t = 0.0
				o.reveal = 999.0
	elif o.st == "deploy":
		o.t += dt
		if o.t >= 6.0:
			var w: Dictionary = o["tgt"]
			if w.alive:
				var d2 := Vector2(w.x - o.x, w.y - o.y).length()
				w.warn = 8.0
				msl.append({"side": 1, "kind": "bal", "sx": o.x, "sy": o.y, "tx": w.x, "ty": w.y, "t": 0.0, "dur": d2 / 150.0 + 3.0,
					"tgt": w, "done": false, "fade": 3.0, "name": "Ballistic missile"})
				say("INBOUND: ballistic missile heading for %s" % w.name, "bad")
				banner("INBOUND BALLISTIC MISSILE", "bad", "Target: %s. Fighters and long range SAMs can stop it." % w.name)
				launch_plume(o.x, o.y)
			o.st = "stow"
			o.t = 0.0
	elif o.st == "stow":
		o.t += dt
		if o.t >= 6.0:
			o.st = "idle"
			o.cd = randf_range(95.0, 150.0)
			o.reveal = 10.0


func launch_plume(x: float, y: float) -> void:
	for i in range(14):
		pt.append({"k": "smoke", "x": x + randf_range(-4, 4), "y": y + randf_range(-3, 3), "vx": randf_range(-14, 14), "vy": randf_range(-14, 2),
			"l": randf_range(1.6, 3.2), "m": 3.2, "s": randf_range(5, 11)})
	pt.append({"k": "flash", "x": x, "y": y, "vx": 0.0, "vy": 0.0, "l": 0.3, "m": 0.3, "s": 10.0})
	for i in range(6):
		pt.append({"k": "fire", "x": x, "y": y, "vx": randf_range(-8, 8), "vy": randf_range(4, 22), "l": 0.5, "m": 0.5, "s": 3.0})


# ====================================================================== buildings: damage
func destroy_bld(b: Dictionary) -> void:
	b.alive = false
	b.rebuild = 140.0 if b.type == "airfield" else 100.0
	boom(b.x, b.y, 3.0)
	fires.append({"x": b.x, "y": b.y, "t": 30.0})
	if b.type == "airfield":
		for a in ac:
			if not a.dead and (a.st == "parked" or a.st == "rearm" or a.st == "taxi") and is_same(a.af, b):
				a.dead = true
				lost += 1
				boom(a.x, a.y, 1.2)
		b.slots.clear()
		chips_dirty = true
	say("%s destroyed. It will be rebuilt in about %d s." % [b.name, int(b.rebuild)], "bad")
	banner("%s DESTROYED" % String(D.BUILD[b.type].name).to_upper(), "bad", "")
	calc_grid()


func hit_bld(b: Dictionary, dmg: float) -> void:
	if not b.alive or b.prog < 1.0:
		return
	b.hp -= dmg
	if b.hp <= 0.0:
		destroy_bld(b)
	else:
		say("%s damaged" % b.name, "bad")


# ====================================================================== player air defense
func upd_player_ad(dt: float) -> void:
	var threats: Array = enemy_air()
	for m in msl:
		if m.side == 1 and not m.done and m.t >= 0.0:
			threats.append(m)
	for s in bl:
		if not s.alive or s.prog < 1.0 or (s.type != "sam" and s.type != "lsam"):
			continue
		s.cool -= dt
		s.ammo = minf(6.0, s.ammo + dt / 5.0)
		s.eng = false
		var rr := 150.0 if s.type == "sam" else 270.0
		var thr = null
		var bd := rr
		for e in threats:
			if not e.has("x"):
				continue
			if e.has("hp") and e.hp <= 0:
				continue
			if e.has("done") and e.done:
				continue
			var d := Vector2(e.x - s.x, e.y - s.y).length()
			if d < bd:
				bd = d
				thr = e
		if thr != null:
			s.eng = true
			if s.cool <= 0.0 and s.ammo >= 1.0:
				s.cool = 2.6 if s.type == "sam" else 3.4
				s.ammo -= 1.0
				var pk := 0.5
				if thr.has("kind"):
					if thr.kind == "bal":
						pk = 0.12 if s.type == "sam" else 0.45
					else:
						pk = 0.45 if s.type == "sam" else 0.55
				elif thr.k == "eu":
					pk = 0.6
				pk *= 0.92 + 0.08 * s.lvl
				proj("psam", s, thr, {"dur": 0.7, "hit": randf() < pk})


func kill_threat(e: Dictionary, reward: bool) -> void:
	if e.has("kind"):
		e.done = true
		e.fade = 0.6
		boom(e.x, e.y, 1.2)
		say("%s intercepted" % e.get("name", "Missile"), "good")
		banner("INTERCEPTED", "good", "")
	else:
		e.hp = 0
		boom(e.x, e.y, 1.0)
		if reward:
			coins += 20.0
			kills += 1
			kill_val += 20.0
			say("Enemy %s shot down  +20" % ("drone" if e.k == "eu" else "interceptor"), "good")


# ====================================================================== projectiles
func upd_proj(dt: float) -> void:
	for p in pr:
		p.t += dt
		var f := clampf(p.t / p.dur, 0.0, 1.0)
		if (p.k == "sam" or p.k == "aa" or p.k == "ab" or p.k == "psam" or p.k == "nm") and p.tg != null:
			if p.tg.has("x"):
				p.tx = p.tg.x
				p.ty = p.tg.y
		p.x = lerpf(p.sx, p.tx, f)
		p.y = lerpf(p.sy, p.ty, f)
		p.tr -= dt
		if p.tr <= 0.0:
			if p.k == "rk" or p.k == "aa" or p.k == "psam" or p.k == "sam" or p.k == "nm":
				p.tr = 0.035
				pt.append({"k": "smoke", "x": p.x, "y": p.y, "vx": 0.0, "vy": 0.0, "l": 0.9, "m": 0.9, "s": 2.4})
			elif p.k == "hyp":
				p.tr = 0.02
				pt.append({"k": "spark", "x": p.x, "y": p.y, "vx": 0.0, "vy": 0.0, "l": 0.5, "m": 0.5, "s": 3.0})
		if f >= 1.0:
			p.done = true
			if p.k == "gb" or p.k == "rk":
				boom(p.tx, p.ty, 1.2 if p.k == "gb" else 0.35)
				if p.tg != null and p.tg.alive and Vector2(p.tg.x - p.tx, p.tg.y - p.ty).length() < 60.0:
					hit_target(p.tg, p.dmg)
			elif p.k == "hyp":
				boom(p.tx, p.ty, 2.2)
				if p.tg != null and p.tg.alive:
					hit_target(p.tg, p.dmg)
			elif p.k == "nm":
				boom(p.tx, p.ty, 0.8)
				if p.tg != null and p.tg.alive:
					hit_target(p.tg, p.dmg)
			elif p.k == "enm":
				boom(p.tx, p.ty, 0.8)
				if p.tg != null and not p.tg.dead:
					damage_fleet(p.tg, p.dmg)
			elif p.k == "sam" or p.k == "ab":
				if p.hit and not p.tg.dead:
					damage_aircraft(p.tg, 1)
				else:
					pt.append({"k": "smoke", "x": p.tx, "y": p.ty, "vx": 0.0, "vy": 0.0, "l": 1.2, "m": 1.2, "s": 4.0})
			elif p.k == "aa":
				if p.hit and p.tg != null and (not p.tg.has("hp") or p.tg.hp > 0):
					kill_threat(p.tg, true)
				else:
					toast("Air-to-air missile missed")
			elif p.k == "psam":
				if p.hit and p.tg != null and (not p.tg.has("hp") or p.tg.hp > 0) and not (p.tg.has("done") and p.tg.done):
					kill_threat(p.tg, true)
				else:
					pt.append({"k": "smoke", "x": p.tx, "y": p.ty, "vx": 0.0, "vy": 0.0, "l": 1.0, "m": 1.0, "s": 4.0})
	pr = pr.filter(func(p): return not p.done)


func bez(m: Dictionary, f: float) -> Vector2:
	var cx: float = (m.sx + m.tx) / 2.0 + (m.ty - m.sy) * 0.28
	var cy: float = (m.sy + m.ty) / 2.0 - (m.tx - m.sx) * 0.28
	var u := f
	return Vector2((1 - u) * (1 - u) * m.sx + 2 * (1 - u) * u * cx + u * u * m.tx,
		(1 - u) * (1 - u) * m.sy + 2 * (1 - u) * u * cy + u * u * m.ty)


func msl_pos(m: Dictionary, f: float) -> Vector2:
	if m.kind == "bal":
		return bez(m, f)
	var p := Vector2(lerpf(m.sx, m.tx, f), lerpf(m.sy, m.ty, f))
	var dir := Vector2(m.tx - m.sx, m.ty - m.sy).normalized()
	var perp := Vector2(-dir.y, dir.x)
	return p + perp * sin(f * PI * 5.0) * 3.0 * (1.0 - f)


func msl_alt_km(m: Dictionary) -> float:
	var f := clampf(m.t / m.dur, 0.0, 1.0)
	return 16.0 * 4.0 * f * (1.0 - f) if m.kind == "bal" else 0.3


func msl_mach(m: Dictionary) -> float:
	var f := clampf(m.t / m.dur, 0.0, 1.0)
	return 1.4 + 4.2 * sin(PI * f) if m.kind == "bal" else 0.8


func upd_msl(dt: float) -> void:
	for m in msl:
		if not m.has("x"):
			m["x"] = m.sx
			m["y"] = m.sy
			m["hp"] = 1
		if m.done:
			m.fade -= dt
			continue
		m.t += dt
		if m.t < 0.0:
			continue
		var f := clampf(m.t / m.dur, 0.0, 1.0)
		var hp := msl_pos(m, f)
		m.x = hp.x
		m.y = hp.y
		if randf() < dt * 22.0:
			pt.append({"k": "smoke", "x": hp.x, "y": hp.y, "vx": randf_range(-2, 2), "vy": randf_range(-2, 2), "l": 1.8 if m.kind == "bal" else 1.2,
				"m": 1.8 if m.kind == "bal" else 1.2, "s": 3.0 if m.kind == "bal" else 2.2})
		if m.t >= m.dur:
			impact_msl(m)
	msl = msl.filter(func(m): return not m.done or m.fade > 0.0)


func impact_msl(m: Dictionary) -> void:
	m.done = true
	m.fade = 3.0
	if m.side == 1:
		var w: Dictionary = m.tgt
		if w.has("b"):
			boom(w.x + randf_range(-16, 16), w.y + randf_range(-16, 16), 2.0)
			w.burn = 40.0
			coins = maxf(0.0, coins - 25.0)
			say("Missile hit %s" % w.name, "bad")
		else:
			boom(w.x, w.y, 3.0 if m.kind == "bal" else 1.6)
			hit_bld(w, 7.0 if m.kind == "bal" else 3.0)
	else:
		if m.kind == "bal":
			boom(m.tx, m.ty, 3.5)
			var n := 0
			for o in tg:
				if o.alive:
					var d := Vector2(o.x - m.tx, o.y - m.ty).length()
					if d < 60.0:
						hit_target(o, 14.0 if d < 30.0 else 8.0)
						n += 1
			if n == 0:
				say("Ballistic missile hit empty ground", "")
		else:
			boom(m.tx, m.ty, 1.8)
			var n2 := 0
			for o in tg:
				if o.alive and Vector2(o.x - m.tx, o.y - m.ty).length() < 26.0:
					hit_target(o, 4.0)
					n2 += 1
			if n2 == 0:
				say("Cruise missile hit empty ground", "")


# ====================================================================== our missile trucks
func order_truck_fire(tr: Dictionary, wx: float, wy: float) -> void:
	if tr.st != "idle":
		toast("Truck T%d is busy" % tr.n)
		return
	if mis <= 0:
		toast("No ballistic missiles in stock. Buy one at HQ or build a rocket factory.")
		return
	tr.fire = Vector2(wx, wy)
	tr.st = "move"
	tr.t = 0.0
	toast("T%d: moving into range" % tr.n)


func order_truck_move(tr: Dictionary, wx: float, wy: float) -> void:
	if tr.st == "deploy" or tr.st == "stow":
		toast("Truck T%d is busy" % tr.n)
		return
	tr.tx = clampf(wx, 40.0, front_at(wy) - 50.0)
	tr.ty = clampf(wy, 40.0, H * 0.84)
	tr.st = "drive"
	tr.fire = null


func upd_trucks(dt: float) -> void:
	for tr in trucks:
		if tr.dead:
			continue
		tr.dust = maxf(0.0, tr.dust - dt)
		var moving := false
		var gx: float = tr.x
		var gy: float = tr.y
		if tr.st == "drive":
			gx = tr.tx
			gy = tr.ty
			moving = true
			if Vector2(tr.x - gx, tr.y - gy).length() < 6.0:
				tr.st = "idle"
				moving = false
		elif tr.st == "move":
			var fp: Vector2 = tr.fire
			var d := Vector2(fp.x - tr.x, fp.y - tr.y)
			if d.length() <= TRUCK_RANGE - 25.0:
				tr.st = "deploy"
				tr.t = 0.0
			else:
				var goal := fp - d.normalized() * (TRUCK_RANGE - 60.0)
				gx = clampf(goal.x, 40.0, front_at(goal.y) - 50.0)
				gy = clampf(goal.y, 40.0, H * 0.84)
				moving = true
				if Vector2(tr.x - gx, tr.y - gy).length() < 6.0:
					tr.st = "deploy"
					tr.t = 0.0
					moving = false
		elif tr.st == "deploy":
			tr.t += dt
			if tr.t >= 3.0:
				var fp2: Vector2 = tr.fire
				if mis > 0:
					mis -= 1
					var d2 := Vector2(fp2.x - tr.x, fp2.y - tr.y).length()
					msl.append({"side": 0, "kind": "bal", "sx": tr.x, "sy": tr.y, "tx": fp2.x, "ty": fp2.y, "t": 0.0,
						"dur": d2 / 170.0 + 2.4, "tgt": null, "done": false, "fade": 3.0, "name": "Ballistic missile"})
					launch_plume(tr.x, tr.y)
					say("Truck T%d launched a ballistic missile (%d left)" % [tr.n, mis], "")
				tr.st = "stow"
				tr.t = 0.0
		elif tr.st == "stow":
			tr.t += dt
			if tr.t >= 2.5:
				tr.st = "idle"
		if moving:
			var dd := Vector2(gx - tr.x, gy - tr.y)
			tr.ang = lerp_angle(tr.ang, dd.angle(), minf(1.0, dt * 4.0))
			tr.x += cos(tr.ang) * 30.0 * dt
			tr.y += sin(tr.ang) * 30.0 * dt
			if randf() < dt * 8.0:
				pt.append({"k": "smoke", "x": tr.x - cos(tr.ang) * 6.0, "y": tr.y - sin(tr.ang) * 6.0, "vx": 0.0, "vy": -3.0, "l": 0.9, "m": 0.9,
					"s": 2.6, "dust": true})
		# enemy interceptors or drones can hurt a truck out in the open
		for e in ea:
			if Vector2(e.x - tr.x, e.y - tr.y).length() < 30.0 and randf() < dt * 0.6:
				tr.hp -= 1.0
				if tr.hp <= 0.0:
					tr.dead = true
					boom(tr.x, tr.y, 1.4)
					say("Truck T%d was destroyed" % tr.n, "bad", true)
	trucks = trucks.filter(func(tr): return not tr.dead)


# ====================================================================== UAVs and recon
func nearest_dp(x: float, y: float) -> Variant:
	var best = null
	var bd := 1e9
	for d in blds("droneport"):
		var dd := Vector2(d.x - x, d.y - y).length()
		if dd < bd:
			bd = dd
			best = d
	return best


func launch_uav(wx: float, wy: float, target, recon: bool) -> void:
	var src = nearest_dp(wx, wy)
	if src == null:
		toast("Build a drone port first")
		return
	if recon:
		if coins < 20.0:
			toast("Recon costs 20 coins")
			return
		coins -= 20.0
	else:
		if uav_stock <= 0:
			toast("No UAVs in stock. Buy at HQ or build a UAV factory.")
			return
		uav_stock -= 1
	var tx := wx
	var ty := wy
	if target != null:
		tx = target.x
		ty = target.y
	uavs.append({"x": src.x, "y": src.y, "ang": 0.0, "tg": target, "tx": tx, "ty": ty, "life": 50.0 if not recon else 42.0, "tr": 0.0,
		"dead": false, "rec": recon, "t": 0.0})
	say("Recon drone launched" if recon else "UAV launched", "")


func upd_uavs(dt: float) -> void:
	for u in uavs:
		u.life -= dt
		u.t += dt
		if u.rec:
			var d := Vector2(u.tx - u.x, u.ty - u.y)
			if d.length() > 60.0:
				u.ang = lerp_angle(u.ang, d.angle(), minf(1.0, dt * 3.0))
			else:
				u.ang += 1.4 * dt
			u.x += cos(u.ang) * 70.0 * dt
			u.y += sin(u.ang) * 70.0 * dt
			for o in tg:
				if o.alive and o.hidden and Vector2(o.x - u.x, o.y - u.y).length() < 150.0:
					if o.reveal <= 0.0:
						say("Recon: %s spotted" % D.TYPES[o.type].name.to_lower(), "good", true)
					o.reveal = maxf(o.reveal, 6.0)
			if u.life <= 0.0:
				u.dead = true
				say("Recon drone returned to base", "")
		else:
			if u.tg != null and u.tg.alive:
				u.tx = u.tg.x
				u.ty = u.tg.y
			var dd := wrapf(atan2(u.ty - u.y, u.tx - u.x) - u.ang, -PI, PI)
			u.ang += clampf(dd, -3.0 * dt, 3.0 * dt)
			u.x += cos(u.ang) * 95.0 * dt
			u.y += sin(u.ang) * 95.0 * dt
			if Vector2(u.tx - u.x, u.ty - u.y).length() < 8.0:
				u.dead = true
				boom(u.tx, u.ty, 0.9)
				if u.tg != null and u.tg.alive:
					hit_target(u.tg, 1.8)
				else:
					for o in tg:
						if o.alive and Vector2(o.x - u.tx, o.y - u.ty).length() < 22.0:
							hit_target(o, 1.8)
			elif u.life <= 0.0:
				u.dead = true
				boom(u.x, u.y, 0.5)
		u.tr -= dt
		if u.tr <= 0.0:
			u.tr = 0.1
			trail.append({"x": u.x, "y": u.y, "l": 0.8, "m": 0.8, "w": 1.5})
	uavs = uavs.filter(func(u): return not u.dead)


func upd_eu(dt: float) -> void:
	for e in eu:
		e.life -= dt
		var w: Dictionary = e.tg
		if not w.alive:
			var cand: Array = bl.filter(func(b): return b.alive and b.prog >= 1.0)
			if cand.is_empty():
				e.hp = 0
				continue
			e.tg = cand[randi() % cand.size()]
			w = e.tg
		var dd := wrapf(atan2(w.y - e.y, w.x - e.x) - e.ang, -PI, PI)
		e.ang += clampf(dd, -2.4 * dt, 2.4 * dt)
		e.x += cos(e.ang) * 78.0 * dt
		e.y += sin(e.ang) * 78.0 * dt
		e.tr -= dt
		if e.tr <= 0.0:
			e.tr = 0.12
			trail.append({"x": e.x, "y": e.y, "l": 0.7, "m": 0.7, "w": 1.3})
		if Vector2(w.x - e.x, w.y - e.y).length() < 10.0:
			e.hp = 0
			boom(w.x, w.y, 1.1)
			hit_bld(w, 2.5)
		elif e.life <= 0.0:
			e.hp = 0
	eu = eu.filter(func(e): return e.hp > 0)


# ====================================================================== artillery, smoke, field hospital
func front_dist(wx: float, wy: float) -> float:
	return wx - front_at(wy)


func use_artillery(wx: float, wy: float) -> void:
	if shell_n < 4:
		toast("Not enough shells. Buy more at HQ.")
		return
	var fd := front_dist(wx, wy)
	if fd < -30.0 or fd > 270.0:
		toast("Out of artillery range. Target must be within 270 of the front.")
		return
	shell_n -= 4
	for i in range(4):
		shells.append({"delay": i * 0.45, "sx": front_at(wy) - 80.0, "sy": wy + randf_range(-20, 20), "tx": wx + randf_range(-26, 26),
			"ty": wy + randf_range(-22, 22), "t": 0.0, "dur": 1.1, "x": 0.0, "y": 0.0, "done": false})
	say("Artillery barrage called in", "")


func upd_shells(dt: float) -> void:
	for s in shells:
		if s.delay > 0.0:
			s.delay -= dt
			s.x = s.sx
			s.y = s.sy
			if s.delay <= 0.0:
				pt.append({"k": "flash", "x": s.sx, "y": s.sy, "vx": 0.0, "vy": 0.0, "l": 0.15, "m": 0.15, "s": 7.0})
			continue
		s.t += dt
		var f := clampf(s.t / s.dur, 0.0, 1.0)
		s.x = lerpf(s.sx, s.tx, f)
		s.y = lerpf(s.sy, s.ty, f)
		if f >= 1.0:
			s.done = true
			boom(s.tx, s.ty, 0.75)
			for o in tg:
				if o.alive and not o.hidden and Vector2(o.x - s.tx, o.y - s.ty).length() < 26.0:
					hit_target(o, 1.5 if o.type == "inf" else 0.6)
			for i in range(NB):
				var w := 1.0 - absf((i + 0.5) * BH - s.ty) / 120.0
				if w > 0.0:
					SUP[i] += 0.04 * w
	shells = shells.filter(func(s): return not s.done)


func use_smoke(wx: float, wy: float) -> void:
	if smoke_n <= 0:
		toast("No smoke canisters. Buy more at HQ.")
		return
	if absf(front_dist(wx, wy)) > 240.0:
		toast("Place smoke near the front line")
		return
	smoke_n -= 1
	smokes.append({"x": wx, "y": wy, "r": 64.0, "t": 45.0, "seed": randf() * 100.0})
	for g in groups:
		if wy >= g.b0 * BH - 30.0 and wy <= (g.b1 + 1) * BH + 30.0:
			g.smoke = 45.0
	say("Smoke screen laid", "")


func use_med(wx: float, wy: float) -> void:
	if med_n <= 0:
		toast("No field hospitals. Buy more at HQ.")
		return
	var g = group_of_band(band_of(wy))
	if g == null or not g.alive:
		toast("No living army group there")
		return
	if g.str >= 95.0:
		toast("Group %d is at full strength" % g.n)
		return
	med_n -= 1
	g.str = minf(100.0, g.str + 35.0)
	var gp := group_pos(g)
	for i in range(10):
		pt.append({"k": "plus", "x": gp.x + randf_range(-18, 18), "y": gp.y + randf_range(-10, 10), "vx": 0.0, "vy": -randf_range(12, 26),
			"l": 1.3, "m": 1.3, "s": 6.0})
	say("Field hospital treated group %d" % g.n, "good")


# ====================================================================== sea: cargo ships, warships, our fleets
func spawn_ship(lane: String = "") -> Dictionary:
	if lane == "":
		lane = "e" if randf() < 0.6 else "s"
	var dir := 1.0 if randf() < 0.5 else -1.0
	var flag := "kar"
	if randf() >= 0.45:
		flag = nat[randi() % nat.size()].id
	var cg: Array = D.CARGO[randi() % D.CARGO.size()]
	var s: Dictionary
	if lane == "e":
		var y := -10.0 if dir > 0.0 else H + 10.0
		s = add_target("ship", 0.0, y, {"flag": flag, "dir": dir, "sp": randf_range(17.0, 22.0), "off": randf_range(16.0, 32.0),
			"cargo": cg[0], "col": Color.html(cg[1]), "want_dock": randf() < 0.75, "dock": 0.0, "lane": "e", "ang": PI / 2.0 * dir})
		s.x = sea_x(y) + s.off
	else:
		var x := -10.0 if dir > 0.0 else W + 10.0
		s = add_target("ship", x, 0.0, {"flag": flag, "dir": dir, "sp": randf_range(17.0, 22.0), "off": randf_range(14.0, 30.0),
			"cargo": cg[0], "col": Color.html(cg[1]), "want_dock": randf() < 0.6, "dock": 0.0, "lane": "s", "ang": 0.0 if dir > 0.0 else PI})
		s.y = sea_y(x) + s.off
	return s


func spawn_wships() -> void:
	for i in range(2):
		var s := add_target("wship", 0.0, 20.0 + i * 36.0, {"lane": "w", "dir": 1.0, "sp": 15.0, "off": 24.0 + i * 16.0, "phase": "down",
			"px": W * (0.4 + 0.08 * i), "cool": randf_range(20.0, 40.0), "ang": PI / 2.0, "dock": 0.0, "flag": "kar",
			"cargo": "", "col": Color.html("3a3f45")})
		s.x = sea_x(s.y) + s.off
	say("Enemy warships spotted off the coast", "bad")
	banner("ENEMY FLEET", "bad", "Warships are heading for our harbor.")


func upd_ships(dt: float) -> void:
	ship_t -= dt
	var ships: Array = tg.filter(func(o): return o.type == "ship" and o.alive)
	if ship_t <= 0.0:
		ship_t = randf_range(16.0, 26.0)
		if ships.size() < 7:
			spawn_ship()
	wship_t -= dt
	if wship_t <= 0.0:
		wship_t = randf_range(140.0, 200.0)
		var wn := 0
		for o in tg:
			if o.type == "wship" and o.alive:
				wn += 1
		if wn < 2:
			spawn_wships()
	var ports: Array = tg.filter(func(o): return o.type == "port" and o.alive)
	for s in ships:
		if s.dock > 0.0:
			s.dock -= dt
			if s.dock <= 0.0:
				estock = minf(9.0, estock + 1.0)
			continue
		if s.lane == "e":
			s.y += s.dir * s.sp * dt
			s.x = lerpf(s.x, sea_x(s.y) + s.off, minf(1.0, dt * 3.0))
			s.ang = PI / 2.0 * s.dir
			if s.want_dock:
				for p in ports:
					if p.y < H * 0.8 and absf(s.y - p.y) < 4.0:
						s.dock = 9.0
						s.want_dock = false
						s.x = p.x + 34.0
			if s.y < -40.0 or s.y > H + 40.0:
				s.alive = false
		else:
			s.x += s.dir * s.sp * dt
			s.y = lerpf(s.y, sea_y(s.x) + s.off, minf(1.0, dt * 3.0))
			s.ang = 0.0 if s.dir > 0.0 else PI
			if s.want_dock:
				for p in ports:
					if p.y > H * 0.8 and absf(s.x - p.x) < 4.0:
						s.dock = 9.0
						s.want_dock = false
			if s.x < -40.0 or s.x > W + 40.0:
				s.alive = false
		if randf() < dt * 3.0:
			pt.append({"k": "wake", "x": s.x - cos(s.ang) * 8.0, "y": s.y - sin(s.ang) * 8.0, "vx": 0.0, "vy": 0.0, "l": 1.4, "m": 1.4, "s": 3.0})
	# enemy warships
	for w in tg:
		if w.type != "wship" or not w.alive:
			continue
		w.cool -= dt
		if w.phase == "down":
			w.y += w.sp * dt
			w.x = lerpf(w.x, sea_x(w.y) + w.off, minf(1.0, dt * 3.0))
			w.ang = PI / 2.0
			if w.y >= H - 50.0:
				w.phase = "west"
		elif w.phase == "west":
			w.x -= w.sp * dt
			w.y = lerpf(w.y, sea_y(w.x) + w.off, minf(1.0, dt * 3.0))
			w.ang = PI
			if w.x <= w.px:
				w.phase = "hold"
		if w.phase != "hold" and randf() < dt * 3.0:
			pt.append({"k": "wake", "x": w.x - cos(w.ang) * 9.0, "y": w.y - sin(w.ang) * 9.0, "vx": 0.0, "vy": 0.0, "l": 1.4, "m": 1.4, "s": 3.5})
		if w.cool <= 0.0:
			var tf = null
			for f in fleets:
				if not f.dead and Vector2(f.x - w.x, f.y - w.y).length() < 230.0:
					tf = f
			if tf != null:
				w.cool = 6.0
				proj("enm", w, tf, {"dur": 0.9, "dmg": 1.2})
			elif w.phase == "hold" or w.y > H * 0.5:
				w.cool = 55.0
				var cand: Array = bl.filter(func(b): return b.alive and b.prog >= 1.0 and Vector2(b.x - w.x, b.y - w.y).length() < 620.0)
				if not cand.is_empty():
					var tb: Dictionary = cand[randi() % cand.size()]
					var d := Vector2(tb.x - w.x, tb.y - w.y).length()
					tb.warn = 8.0
					msl.append({"side": 1, "kind": "cru", "sx": w.x, "sy": w.y, "tx": tb.x, "ty": tb.y, "t": 0.0, "dur": d / 150.0 + 0.6,
						"tgt": tb, "done": false, "fade": 2.0, "name": "Cruise missile"})
					say("INBOUND: cruise missile from the sea, target %s" % tb.name, "bad")
					banner("INBOUND CRUISE MISSILE", "bad", "Target: %s" % tb.name)
				else:
					w.cool = 12.0
	tg = tg.filter(func(o): return (o.type != "ship" and o.type != "wship") or o.alive)


func ship_sunk(s: Dictionary) -> void:
	boom(s.x, s.y, 1.8)
	for i in range(10):
		pt.append({"k": "deb", "x": s.x + randf_range(-8, 8), "y": s.y + randf_range(-10, 10), "vx": randf_range(-2, 2),
			"vy": randf_range(-2, 2), "l": randf_range(20, 40), "m": 40.0, "s": 3.0, "c": s.col, "still": true})
	pt.append({"k": "oil", "x": s.x, "y": s.y, "vx": 0.0, "vy": 0.0, "l": 40.0, "m": 40.0, "s": 14.0})
	if s.type == "wship":
		coins += 70.0
		kills += 1
		kill_val += 70.0
		say("Enemy warship sunk  +70", "good")
		return
	estock = maxf(0.0, estock - 1.0)
	coins += 30.0
	kills += 1
	kill_val += 30.0
	if s.flag == "kar":
		say("Enemy convoy sunk  +30. Their supply falls.", "good")
	else:
		var n := nat_of(s.flag)
		say("%s cargo ship sunk  +30" % n.name, "good")
		incident(n)


func nat_of(id: String) -> Dictionary:
	for n in nat:
		if n.id == id:
			return n
	return {}


func is_neutral(o: Dictionary) -> bool:
	if o.type != "ship" or o.flag == "kar":
		return false
	var n := nat_of(o.flag)
	return not n.is_empty() and not n.war


func tg_name(o: Dictionary) -> String:
	if o.type == "ship":
		var who := "Karmin" if o.flag == "kar" else String(nat_of(o.flag).name)
		return "%s cargo ship (%s)" % [who, o.cargo]
	return D.TYPES[o.type].name


func damage_fleet(f: Dictionary, dmg: float) -> void:
	for i in range(f.hp.size()):
		if f.hp[i] > 0.0:
			f.hp[i] -= dmg
			if f.hp[i] <= 0.0:
				f.ships -= 1
				boom(f.x + randf_range(-10, 10), f.y + randf_range(-10, 10), 1.2)
				say("A ship of fleet %d was sunk" % f.n, "bad")
			break
	if f.ships <= 0:
		f.dead = true
		if sel != null and is_same(sel, f):
			select(null)
		banner("FLEET %d LOST" % f.n, "bad", "")


func sea_goal(f: Dictionary, goal: Vector2) -> Vector2:
	var corner := Vector2(W - 36.0, H - 36.0)
	var f_south: bool = f.y > sea_y(f.x) + 4.0 and f.x <= sea_x(f.y)
	var f_east: bool = f.x > sea_x(f.y) + 4.0 and f.y <= sea_y(f.x)
	var g_south: bool = goal.y > sea_y(goal.x) + 4.0 and goal.x <= sea_x(goal.y)
	var g_east: bool = goal.x > sea_x(goal.y) + 4.0 and goal.y <= sea_y(goal.x)
	if (f_south and g_east) or (f_east and g_south):
		if Vector2(f.x - corner.x, f.y - corner.y).length() > 50.0:
			return corner
	return goal


func clamp_sea(p: Vector2) -> Vector2:
	var q := p
	if not in_sea(q.x, q.y):
		# push to the nearest sea
		var ds := sea_y(q.x) + 12.0 - q.y
		var de := q.x - (sea_x(q.y) + 12.0)
		if absf(ds) < absf(de):
			q.y = sea_y(q.x) + 12.0
		else:
			q.x = sea_x(q.y) + 12.0
	return q


func upd_fleets(dt: float) -> void:
	for f in fleets:
		if f.dead:
			continue
		f.cool -= dt
		f.cmcool -= dt
		f.mis = minf(4.0, f.mis + dt / 40.0)
		var o = f.order
		var goal = null
		var stopd := 4.0
		if o != null:
			if o.t == "move":
				goal = Vector2(o.x, o.y)
			elif o.t == "attack":
				if o.tg.alive:
					goal = Vector2(o.tg.x, o.tg.y)
					stopd = 110.0
				else:
					f.order = null
			elif o.t == "strike":
				if o.tg.alive:
					var d := Vector2(o.tg.x - f.x, o.tg.y - f.y).length()
					if d <= 480.0:
						if f.cmcool <= 0.0 and f.mis >= 1.0:
							f.mis -= 1.0
							f.cmcool = 7.0
							msl.append({"side": 0, "kind": "cru", "sx": f.x, "sy": f.y, "tx": o.tg.x + randf_range(-5, 5), "ty": o.tg.y + randf_range(-5, 5),
								"t": 0.0, "dur": d / 150.0 + 0.5, "tgt": o.tg, "done": false, "fade": 2.0, "name": "Cruise missile"})
							say("Fleet %d launched a cruise missile" % f.n, "")
						elif f.mis < 1.0 and f.cmcool <= 0.0:
							f.order = null
							toast("Fleet %d is out of cruise missiles" % f.n)
				else:
					f.order = null
		if goal != null:
			var wp := sea_goal(f, goal)
			var dd := Vector2(wp.x - f.x, wp.y - f.y)
			if dd.length() > stopd:
				f.ang = lerp_angle(f.ang, dd.angle(), minf(1.0, dt * 2.0))
				var nx: float = f.x + cos(f.ang) * 26.0 * dt
				var ny: float = f.y + sin(f.ang) * 26.0 * dt
				var q := clamp_sea(Vector2(nx, ny))
				f.x = q.x
				f.y = q.y
				f.wake -= dt
				if f.wake <= 0.0:
					f.wake = 0.12
					pt.append({"k": "wake", "x": f.x - cos(f.ang) * 10.0, "y": f.y - sin(f.ang) * 10.0, "vx": 0.0, "vy": 0.0, "l": 1.6, "m": 1.6, "s": 4.0})
			elif o != null and o.t == "move":
				f.order = null
		# ship to ship fire
		if f.cool <= 0.0:
			var tgt = null
			var bd := 175.0
			if o != null and o.t == "attack" and o.tg.alive and Vector2(o.tg.x - f.x, o.tg.y - f.y).length() < 200.0:
				tgt = o.tg
			else:
				for s in tg:
					if s.alive and (s.type == "wship" or (s.type == "ship" and s.flag == "kar")):
						var d2 := Vector2(s.x - f.x, s.y - f.y).length()
						if d2 < bd:
							bd = d2
							tgt = s
			if tgt != null:
				f.cool = 5.0
				for i in range(f.ships):
					proj("nm", f, tgt, {"dur": 0.9 + i * 0.12, "dmg": 0.8})
	fleets = fleets.filter(func(f): return not f.dead)


# ====================================================================== diplomacy and trade
func new_case(n: Dictionary, stage: int) -> Dictionary:
	var c := {"n": n, "stage": stage, "t": D.STAGE_T[stage], "tm": D.STAGE_T[stage]}
	cases.append(c)
	return c


func case_for(n: Dictionary) -> Variant:
	for c in cases:
		if c.n.id == n.id:
			return c
	return null


func incident(n: Dictionary) -> void:
	if n.war:
		return
	n.inc += 1
	n.mood = maxf(0.0, n.mood - 10.0)
	var c = case_for(n)
	if n.promise > 0.0:
		n.promise = 0.0
		if c != null:
			c.stage = mini(3, c.stage + 1)
		else:
			c = new_case(n, 2)
		c.t = D.STAGE_T[c.stage]
		c.tm = D.STAGE_T[c.stage]
		say("%s: you broke your word! %s" % [n.name, String(D.STAGES[c.stage]).to_upper()], "bad")
	elif c == null:
		new_case(n, 0)
		say("%s protests: stop sinking our ships" % n.name, "bad")
		banner("%s PROTESTS" % String(n.name).to_upper(), "warn", "Open Politics to answer.")
	sheet_sig = ""


func declare_war(c: Dictionary) -> void:
	var n: Dictionary = c.n
	n.war = true
	cases = cases.filter(func(x): return x.n.id != n.id)
	offers = offers.filter(func(o): return o.n.id != n.id)
	war_pen += 0.12
	ea_t = minf(ea_t, 10.0)
	say("%s declares war on Azuria and joins Karmin." % n.name, "bad")
	banner("WAR: %s" % String(n.name).to_upper(), "war", "Their fleet and drones will join Karmin.")
	sheet_sig = ""


func upd_diplo(dt: float) -> void:
	for n in nat:
		if n.promise > 0.0:
			n.promise -= dt
	for c in cases.duplicate():
		c.t -= dt
		if c.t <= 0.0:
			c.stage += 1
			if c.stage > 3:
				declare_war(c)
			else:
				c.t = D.STAGE_T[c.stage]
				c.tm = D.STAGE_T[c.stage]
				say("%s: %s" % [c.n.name, String(D.STAGES[c.stage]).to_upper()], "bad")
			sheet_sig = ""
	off_t -= dt
	if off_t <= 0.0:
		off_t = randf_range(70.0, 110.0)
		make_offer()
	for o in offers.duplicate():
		o.t -= dt
		if o.t <= 0.0:
			offers.erase(o)
			sheet_sig = ""
	if disc_t > 0.0:
		disc_t -= dt
		if disc_t <= 0.0:
			disc = 1.0
			say("Trade treaty discount ended", "")
			sheet_sig = ""
	news_t -= dt
	if news_t <= 0.0:
		news_t = randf_range(45.0, 80.0)
		if randf() < 0.6:
			say(D.NEWS_GOOD[randi() % D.NEWS_GOOD.size()], "")
		else:
			say(D.NEWS_BAD[randi() % D.NEWS_BAD.size()], "")


func make_offer() -> void:
	var ok: Array = nat.filter(func(n):
		if n.war or n.mood <= 25.0:
			return false
		for o in offers:
			if o.n.id == n.id:
				return false
		return true)
	if ok.is_empty():
		return
	var n: Dictionary = ok[randi() % ok.size()]
	var r := randf()
	if r < 0.4 or disc < 1.0:
		offers.append({"n": n, "kind": "sell", "res": "oil", "t": 70.0, "tm": 70.0, "q": 30, "coins": 19 * 30})
		say("%s wants to buy oil x30 at 19 each" % n.name, "")
	elif r < 0.7:
		offers.append({"n": n, "kind": "sell", "res": "metal", "t": 70.0, "tm": 70.0, "q": 12, "coins": 50})
		say("%s wants to buy metal x12 for 50 coins" % n.name, "")
	else:
		offers.append({"n": n, "kind": "treaty", "res": "", "t": 70.0, "tm": 70.0, "q": 0, "coins": 0})
		say("%s proposes a trade treaty: purchases cost 10%% less" % n.name, "")
	sheet_sig = ""


func case_act(i: int, act: String) -> void:
	if i >= cases.size():
		return
	var c: Dictionary = cases[i]
	var n: Dictionary = c.n
	if act == "stop":
		n.promise = 180.0
		n.mood = minf(100.0, n.mood + 8.0)
		cases.remove_at(i)
		say("Agreed with %s: we leave their ships alone for 3 minutes" % n.name, "good")
	elif act == "pay":
		if coins < 120.0:
			toast("Not enough coins")
			return
		coins -= 120.0
		n.mood = minf(100.0, n.mood + 14.0)
		cases.remove_at(i)
		say("%s accepts compensation of 120 coins" % n.name, "good")
	elif act == "refuse":
		c.stage += 1
		if c.stage > 3:
			declare_war(c)
		else:
			c.t = D.STAGE_T[c.stage]
			c.tm = D.STAGE_T[c.stage]
			say("%s: %s" % [n.name, String(D.STAGES[c.stage]).to_upper()], "bad")
	sheet_sig = ""


func offer_act(i: int, act: String) -> void:
	if i >= offers.size():
		return
	var o: Dictionary = offers[i]
	if act == "ok":
		if o.kind == "sell":
			if o.res == "oil":
				if oil < o.q:
					toast("Not enough oil")
					return
				oil -= o.q
			else:
				if metal < o.q:
					toast("Not enough metal")
					return
				metal -= o.q
			coins += o.coins
			o.n.mood = minf(100.0, o.n.mood + 6.0)
			say("Sold %s x%d to %s  +%d" % [o.res, o.q, o.n.name, o.coins], "good")
		else:
			disc = 0.9
			disc_t = 150.0
			o.n.mood = minf(100.0, o.n.mood + 10.0)
			say("Trade treaty with %s: purchases cost 10%% less for 2:30" % o.n.name, "good")
	offers.remove_at(i)
	sheet_sig = ""


# ====================================================================== effects, end, main step
func upd_fx(dt: float) -> void:
	for p in pt:
		p.l -= dt
		p.x += p.vx * dt
		p.y += p.vy * dt
		if p.k == "smoke":
			p.s += dt * 3.0
		elif p.k == "deb" and not p.get("still", false):
			p.vy += 70.0 * dt
	pt = pt.filter(func(p): return p.l > 0.0)
	for o in trail:
		o.l -= dt
	trail = trail.filter(func(o): return o.l > 0.0)
	for f in fires:
		f.t -= dt
		if randf() < dt * 5.0:
			pt.append({"k": "smoke", "x": f.x + randf_range(-4, 4), "y": f.y, "vx": randf_range(-4, 4), "vy": -randf_range(8, 16),
				"l": 3.2, "m": 3.2, "s": 5.0, "dark": true})
		if randf() < dt * 4.0:
			pt.append({"k": "fire", "x": f.x + randf_range(-5, 5), "y": f.y + randf_range(-3, 3), "vx": 0.0, "vy": -12.0,
				"l": 0.5, "m": 0.5, "s": 3.0})
	fires = fires.filter(func(f): return f.t > 0.0)
	for c in clouds:
		c.x += c.v * dt
		if c.x > W + 60.0:
			c.x = -60.0


func finish(r: String) -> void:
	if over != "":
		return
	over = r
	speed = 0
	update_speed_buttons()
	show_overlay()


func step(dt: float) -> void:
	if over != "" or not started:
		return
	t += dt
	calc_t -= dt
	if calc_t <= 0.0:
		calc_t = 0.5
		calc_grid()
	upd_econ(dt)
	upd_build(dt)
	if grace > 0.0:
		grace -= dt
		wship_t = maxf(wship_t, 60.0)
		if grace <= 0.0:
			banner("PEACE IS OVER", "war", "Karmin attacks now. Defend and strike back.")
	else:
		upd_ground(dt)
		upd_enemy(dt)
	upd_ships(dt)
	upd_fleets(dt)
	upd_trucks(dt)
	upd_player_ad(dt)
	upd_diplo(dt)
	upd_uavs(dt)
	upd_eu(dt)
	for a in ac:
		if not a.dead:
			upd_aircraft(a, dt)
	var before := ac.size()
	ac = ac.filter(func(a): return not a.dead)
	if ac.size() != before:
		chips_dirty = true
	upd_proj(dt)
	upd_msl(dt)
	upd_shells(dt)
	upd_fx(dt)
	for g in groups:
		pass


# ====================================================================== input
func clamp_cam() -> void:
	var zmin := maxf(vw / W, vh / H)
	zoom = clampf(zoom, zmin, vw / 230.0)
	cam.x = clampf(cam.x, 0.0, maxf(0.0, W - vw / zoom))
	cam.y = clampf(cam.y, 0.0, maxf(0.0, H - vh / zoom))


func zoom_at(sp: Vector2, nz: float) -> void:
	var wx := cam.x + sp.x / zoom
	var wy := cam.y + sp.y / zoom
	zoom = nz
	clamp_cam()
	cam.x = wx - sp.x / zoom
	cam.y = wy - sp.y / zoom
	clamp_cam()


func w2s(x: float, y: float) -> Vector2:
	return Vector2((x - cam.x) * zoom, (y - cam.y) * zoom)


func s2w(sp: Vector2) -> Vector2:
	return Vector2(cam.x + sp.x / zoom, cam.y + sp.y / zoom)


func over_ui(p: Vector2) -> bool:
	for b in blockers:
		if is_instance_valid(b) and b.is_visible_in_tree() and b.get_global_rect().has_point(p):
			return true
	return false


func _input(event: InputEvent) -> void:
	if over != "" or not started:
		return
	if use_touch:
		if event is InputEventScreenTouch:
			if event.pressed:
				touch_down(event.index, event.position)
			else:
				touch_up(event.index, event.position)
		elif event is InputEventScreenDrag:
			touch_move(event.index, event.position)
	else:
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT:
				if event.pressed:
					touch_down(0, event.position)
				else:
					touch_up(0, event.position)
			elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
				zoom_at(event.position, zoom * 1.12)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
				zoom_at(event.position, zoom * 0.89)
		elif event is InputEventMouseMotion:
			if touches.has(0):
				touch_move(0, event.position)
			if place_type != "":
				place_pos = s2w(event.position)


func touch_down(idx: int, pos: Vector2) -> void:
	if over_ui(pos):
		return
	touches[idx] = {"pos": pos, "start": pos, "time": Time.get_ticks_msec(), "moved": false}
	if touches.size() == 2:
		var ks := touches.keys()
		pinch_d = touches[ks[0]].pos.distance_to(touches[ks[1]].pos)


func touch_move(idx: int, pos: Vector2) -> void:
	if not touches.has(idx):
		return
	var p: Dictionary = touches[idx]
	var delta: Vector2 = pos - p.pos
	p.pos = pos
	if pos.distance_to(p.start) > 14.0:
		p.moved = true
	if touches.size() == 1 and p.moved:
		cam -= delta / zoom
		clamp_cam()
		if place_type != "":
			place_pos = s2w(pos)
	elif touches.size() == 2:
		var ks := touches.keys()
		var a: Dictionary = touches[ks[0]]
		var b: Dictionary = touches[ks[1]]
		var d: float = a.pos.distance_to(b.pos)
		if pinch_d > 0.0:
			zoom_at((a.pos + b.pos) / 2.0, zoom * d / pinch_d)
		pinch_d = d
		a.moved = true
		b.moved = true


func touch_up(idx: int, pos: Vector2) -> void:
	if not touches.has(idx):
		return
	var p: Dictionary = touches[idx]
	touches.erase(idx)
	if not p.moved and touches.is_empty() and Time.get_ticks_msec() - p.time < 600:
		tap(pos)
	if touches.size() < 2:
		pinch_d = 0.0


func pick(list: Array, sp: Vector2, r: float) -> Variant:
	var best = null
	var bd := r
	for o in list:
		var d := w2s(o.x, o.y).distance_to(sp)
		if d < bd:
			bd = d
			best = o
	return best


func visible_targets() -> Array:
	return tg.filter(func(o): return o.alive and not (o.hidden and o.reveal <= 0.0) and o.y > -5.0 and o.y < H + 5.0)


func select(a) -> void:
	sel = a
	if mode != "place":
		mode = ""
	route_pts.clear()
	if a != null and tab != "map":
		set_tab("map")
	chips_dirty = true
	refresh_panels()


func tap(sp: Vector2) -> void:
	if not started or over != "":
		return
	var w := s2w(sp)
	var wx := w.x
	var wy := w.y
	# ---- modes
	if mode == "place":
		if place_type != "":
			place_pos = w
			if can_place(place_type, w):
				start_build(place_type, w)
				set_tab("map")
			else:
				toast("You cannot build here: it must be free land on our side")
		return
	if mode == "uav":
		var tgt = pick(visible_targets(), sp, 60.0)
		launch_uav(wx, wy, tgt, false)
		mode = ""
		return
	if mode == "recon":
		launch_uav(wx, wy, null, true)
		mode = ""
		return
	if mode == "strike":
		var tgt2 = pick(visible_targets(), sp, 56.0)
		if tgt2 == null:
			toast("Tap an enemy marker")
			return
		auto_strike(tgt2)
		mode = ""
		return
	if mode == "art":
		use_artillery(wx, wy)
		return
	if mode == "smoke":
		use_smoke(wx, wy)
		mode = ""
		return
	if mode == "med":
		use_med(wx, wy)
		mode = ""
		return
	if mode == "route":
		if sel == null or sel.k != "ac":
			toast("Select an aircraft first")
			mode = ""
			return
		route_pts.append(w)
		if route_pts.size() >= 5:
			commit_route()
		return
	if mode == "hyper":
		var tgt3 = pick(visible_targets(), sp, 60.0)
		if tgt3 == null:
			toast("Tap an enemy marker")
			return
		if sel != null and sel.k == "ac" and sel.hyper > 0 and (sel.st == "fly" or sel.st == "loiter"):
			fire_hyper(sel, tgt3)
		else:
			toast("The fighter must be in the air")
		mode = ""
		return
	# ---- ordinary tap
	var own = pick(ac, sp, 56.0)
	if own != null:
		select(null if (sel != null and is_same(sel, own)) else own)
		return
	var tr = pick(trucks, sp, 50.0)
	if tr != null:
		select(null if (sel != null and is_same(sel, tr)) else tr)
		return
	var fl = pick(fleets, sp, 54.0)
	if fl != null:
		select(null if (sel != null and is_same(sel, fl)) else fl)
		return
	var ms = pick(msl.filter(func(m): return not m.done and m.t >= 0.0 and m.has("x")), sp, 44.0)
	if ms != null:
		select(ms)
		return
	var live2: Array = visible_targets()
	var target2 = pick(live2, sp, 52.0)
	if sel != null and sel.k == "ac":
		if target2 != null:
			var nm := tg_name(target2)
			var neu := is_neutral(target2)
			if sel.type == "ftr":
				if sel.hyper > 0:
					toast("Fighters do not bomb. Use the hypersonic button, or pick an attacker.")
				else:
					toast("Fighters do not bomb. Pick an attacker or a bomber.")
				return
			give_order(sel, {"t": "attack", "tg": target2})
			toast("No.%d: attacking %s%s" % [sel.n, nm.to_lower(), ". Neutral flag: diplomatic incident." if neu else ""])
			return
		var afp = pick(af_p, sp, 60.0)
		if afp != null and sel.st != "parked":
			give_order(sel, {"t": "rtb", "af": afp})
			toast("No.%d: returning to %s" % [sel.n, String(afp.name).to_lower()])
			return
		give_order(sel, {"t": "loiter", "x": wx, "y": wy})
		return
	if sel != null and sel.k == "truck":
		if wx > front_at(wy) - 30.0:
			order_truck_fire(sel, wx, wy)
		else:
			order_truck_move(sel, wx, wy)
		return
	if sel != null and sel.k == "fleet":
		if target2 != null and (target2.type == "ship" or target2.type == "wship"):
			sel.order = {"t": "attack", "tg": target2}
			toast("Fleet %d attacks %s" % [sel.n, tg_name(target2).to_lower()])
		elif target2 != null:
			var d := Vector2(target2.x - sel.x, target2.y - sel.y).length()
			if d > 480.0:
				toast("Too far (%d). Move the fleet within 480." % int(d))
			else:
				sel.order = {"t": "strike", "tg": target2}
				toast("Fleet %d: cruise strike on %s" % [sel.n, tg_name(target2).to_lower()])
		else:
			var q := clamp_sea(Vector2(wx, wy))
			sel.order = {"t": "move", "x": q.x, "y": q.y}
		return
	if target2 != null:
		toast("%s  armor %d/%d" % [tg_name(target2), ceili(target2.hp), int(target2.maxhp)])
		return
	var bb = pick(bl, sp, 50.0)
	if bb != null:
		toast("%s  armor %d/%d%s" % [bb.name, ceili(bb.hp), int(bb.maxhp), "" if bb.prog >= 1.0 else "  (under construction)"])
		return
	var gg = null
	for g in groups:
		var gp := group_pos(g)
		if w2s(gp.x, gp.y).distance_to(sp) < 60.0:
			gg = g
	if gg != null:
		gg.mode = "defend" if gg.mode == "attack" else "attack"
		toast("Group %d: %s" % [gg.n, String(gg.mode).to_upper()])
		return
	select(null)


func auto_strike(target: Dictionary) -> void:
	if sel != null and sel.k == "ac" and sel.type != "ftr":
		give_order(sel, {"t": "attack", "tg": target})
		toast("No.%d: attacking %s" % [sel.n, tg_name(target).to_lower()])
		return
	var best = null
	var bd := 1e9
	for a in ac:
		if a.dead or a.type == "ftr":
			continue
		if a.st != "parked" and a.st != "loiter" and a.st != "fly":
			continue
		if a.gb + a.rk + a.cm <= 0:
			continue
		var d := Vector2(a.x - target.x, a.y - target.y).length()
		if d < bd:
			bd = d
			best = a
	if best == null:
		toast("No aircraft with ordnance is available")
		return
	give_order(best, {"t": "attack", "tg": target})
	toast("No.%d: attacking %s" % [best.n, tg_name(target).to_lower()])


func commit_route() -> void:
	if sel == null or sel.k != "ac" or route_pts.size() == 0:
		return
	var pts: Array = route_pts.duplicate()
	give_order(sel, {"t": "route", "pts": pts})
	if sel.st != "taxi" and sel.st != "parked":
		sel.route = pts.duplicate()
		sel.ri = 0
		sel.st = "fly"
	toast("No.%d: flying the route (%d points)" % [sel.n, pts.size()])
	route_pts.clear()
	mode = ""


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if mode != "":
			mode = ""
			place_type = ""
			route_pts.clear()
		elif over == "" and started and tab != "map":
			set_tab("map")


# ====================================================================== drawing
func night_f() -> float:
	var h := fmod(16.0 + t / 300.0 * 24.0, 24.0)
	return 0.62 * (0.5 - 0.5 * cos(TAU * (h - 14.0) / 24.0))


func _draw() -> void:
	if terr_tex == null:
		return
	draw_rect(Rect2(0, 0, vw, vh), COL.ink)
	draw_set_transform(-cam * zoom, 0.0, Vector2(zoom, zoom))
	draw_world()
	draw_fx()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_hud_layer()


func in_view(x: float, y: float, m: float) -> bool:
	return x > cam.x - m and x < cam.x + vw / zoom + m and y > cam.y - m and y < cam.y + vh / zoom + m


func draw_world() -> void:
	var nf := night_f()
	draw_texture_rect(terr_tex, Rect2(0, 0, W, H), false)
	# craters
	for d in decals:
		if in_view(d.x, d.y, 20.0):
			var al := clampf(d.l / 40.0, 0.0, 1.0)
			draw_circle(Vector2(d.x, d.y), d.r, Color(0.16, 0.12, 0.09, 0.55 * al))
			draw_circle(Vector2(d.x, d.y), d.r * 0.55, Color(0.07, 0.05, 0.04, 0.6 * al))
	# territory tint
	var pts := PackedVector2Array()
	pts.append(Vector2(F[0], 0.0))
	for i in range(NB):
		pts.append(Vector2(F[i], (i + 0.5) * BH))
	pts.append(Vector2(F[NB - 1], H))
	var en := pts.duplicate()
	en.append(Vector2(W, H))
	en.append(Vector2(W, 0.0))
	draw_colored_polygon(en, Color(0.84, 0.22, 0.16, 0.09))
	var pl := pts.duplicate()
	pl.append(Vector2(0.0, H))
	pl.append(Vector2(0.0, 0.0))
	draw_colored_polygon(pl, Color(0.2, 0.43, 0.92, 0.07))
	# bridges first (under everything)
	for o in tg:
		if o.type == "bridge" and in_view(o.x, o.y, 40.0):
			draw_bridge(o)
	# towns
	for tw in towns:
		if not in_view(tw.x, tw.y, tw.r + 10.0):
			continue
		draw_town(tw)
	# facilities
	for b in bl:
		if in_view(b.x, b.y, 70.0):
			draw_bld(b)
	for o in tg:
		if not o.alive or not in_view(o.x, o.y, 70.0):
			continue
		match o.type:
			"afield":
				draw_field(o, Color.html("8f4a40"))
			"plant":
				draw_plant(o.x, o.y, true, Color.html("9a6a62"))
			"port":
				draw_port(o.x, o.y, Color.html("7b6a52"))
			"depot":
				facil(o.x - 7, o.y, 12, 9, Color.html("8d8470"))
				facil(o.x + 7, o.y, 12, 9, Color.html("8d8470"))
			"inf":
				for off in [Vector2(-6, -3), Vector2(5, -4), Vector2(0, 5)]:
					facil(o.x + off.x, o.y + off.y, 8, 6, Color.html("a8503e"))
			"sam":
				facil(o.x, o.y, 12, 10, Color.html("6c5a58"))
				draw_rect(Rect2(o.x - 1, o.y - 8, 2, 6), Color.html("d6cfc8"))
				draw_rect(Rect2(o.x - 4, o.y - 8, 8, 2), Color.html("d6cfc8"))
			"ship", "wship":
				draw_ship(o)
			"otrk":
				if o.reveal > 0.0:
					draw_truck(o.x, o.y, o.ang, true, 1.0 if o.st != "deploy" and o.st != "stow" else 0.0)
	# range circles
	if combat_view or (sel != null and sel.k == "truck"):
		for s in bl:
			if s.alive and s.prog >= 1.0 and (s.type == "sam" or s.type == "lsam") and in_view(s.x, s.y, 300.0):
				var rr := 150.0 if s.type == "sam" else 270.0
				ring_dashed(Vector2(s.x, s.y), rr, Color(0.3, 0.6, 1.0, 0.55 if s.eng else 0.3))
	for s in tg:
		if s.alive and s.type == "sam" and in_view(s.x, s.y, 100.0):
			ring_dashed(Vector2(s.x, s.y), 88.0, Color(1, 0.27, 0.23, 0.7) if s.get("eng", false) else Color(1, 0.35, 0.27, 0.25))
	# night
	if nf > 0.01:
		draw_rect(Rect2(0, 0, W, H), Color(6.0 / 255.0, 12.0 / 255.0, 46.0 / 255.0, nf))
		if nf > 0.08:
			var la := clampf(nf * 1.6, 0.0, 1.0)
			for tw in towns:
				if not in_view(tw.x, tw.y, tw.r + 10.0) or not tw.lit:
					continue
				draw_circle(Vector2(tw.x, tw.y), tw.r * 1.05, Color(1, 0.8, 0.39, 0.08 * la))
				var lc := Color(1, 0.84, 0.43, la)
				for b in tw.b:
					if rhash(int(b[0]), int(b[1]), 3) < 0.85:
						draw_rect(Rect2(b[0] + 1, b[1] + 1, 1, 1), lc)
			for b in bl:
				if b.alive and b.prog >= 1.0 and in_view(b.x, b.y, 40.0):
					draw_circle(Vector2(b.x, b.y), 14.0, Color(1, 0.85, 0.5, 0.06 * la))
	# clouds
	for c in clouds:
		if in_view(c.x, c.y, 60.0):
			for pf in c.p:
				draw_circle(Vector2(c.x + pf.x + 8.0, c.y + pf.y + 26.0), pf.z, Color(0, 0, 0, 0.1))
			for pf in c.p:
				draw_circle(Vector2(c.x + pf.x, c.y + pf.y), pf.z, Color(1, 1, 1, 0.55 * (1.0 - nf)))
	# smoke screens
	for s in smokes:
		var al := clampf(s.t / 8.0, 0.0, 1.0)
		for i in range(9):
			var a: float = TAU * i / 9.0 + s.seed
			var rr: float = s.r * (0.3 + 0.5 * fmod(i * 0.37, 1.0))
			draw_circle(Vector2(s.x + cos(a) * rr, s.y + sin(a) * rr * 0.8), 20.0, Color(0.88, 0.9, 0.92, 0.5 * al))
		draw_circle(Vector2(s.x, s.y), 30.0, Color(0.9, 0.92, 0.94, 0.55 * al))
	# front line
	var fl := PackedVector2Array()
	fl.append(Vector2(F[0], 0.0))
	for i in range(NB):
		fl.append(Vector2(F[i], (i + 0.5) * BH))
	fl.append(Vector2(F[NB - 1], H))
	draw_polyline(fl, Color(0.04, 0.04, 0.08, 0.7), 6.0)
	draw_polyline(offset_line(fl, -2.0), Color.html("4d93ff"), 2.0)
	draw_polyline(offset_line(fl, 2.0), Color.html("e5483f"), 2.0)
	# enemy push arrows
	for i in range(2, NB, 4):
		var n := NET[i]
		if n < -0.04:
			draw_arrow(F[i] + 26.0, (i + 0.5) * BH, -1.0, clampf(-n * 60.0, 14.0, 52.0), Color.html("ff5a4d"))
	# army groups
	for g in groups:
		var gp := group_pos(g)
		if not in_view(gp.x, gp.y, 80.0):
			continue
		if g.alive:
			var col := Color.html("ff8a2a") if g.mode == "attack" else Color.html("86d963")
			var ln := clampf(20.0 + g.str * 0.4, 20.0, 60.0)
			if g.mode == "attack":
				draw_arrow(gp.x - 4.0, gp.y, 1.0, ln, col)
			else:
				draw_shield(gp.x - 10.0, gp.y, col)
			var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 200.0)
			if g.fight > 0.0:
				draw_circle(Vector2(gp.x + 14.0, gp.y), 8.0 + 4.0 * pulse, Color(1, 0.4, 0.1, 0.25 * pulse))
		else:
			draw_shield(gp.x - 10.0, gp.y, Color(0.4, 0.4, 0.4))


func ring_dashed(c: Vector2, r: float, col: Color) -> void:
	for k in range(20):
		var a0 := TAU * k / 20.0
		draw_arc(c, r, a0, a0 + TAU / 40.0, 4, col, 1.4)


func offset_line(src: PackedVector2Array, dx: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in src:
		out.append(Vector2(p.x + dx, p.y))
	return out


func facil(x: float, y: float, w: float, h: float, c: Color) -> void:
	draw_rect(Rect2(x - w / 2.0 + 2, y - h / 2.0 + 2, w, h), Color(0, 0, 0, 0.3))
	draw_rect(Rect2(x - w / 2.0, y - h / 2.0, w, h), c)
	draw_rect(Rect2(x - w / 2.0, y - h / 2.0, w, 2), Color(1, 1, 1, 0.18))


func draw_shield(x: float, y: float, col: Color) -> void:
	var dark := Color.html("1d1a10")
	var pts := PackedVector2Array([Vector2(x - 9, y - 10), Vector2(x + 9, y - 10), Vector2(x + 9, y + 2), Vector2(x, y + 12), Vector2(x - 9, y + 2)])
	draw_colored_polygon(pts, dark)
	var inner := PackedVector2Array([Vector2(x - 6, y - 7), Vector2(x + 6, y - 7), Vector2(x + 6, y + 1), Vector2(x, y + 8), Vector2(x - 6, y + 1)])
	draw_colored_polygon(inner, col)


func draw_town(tw: Dictionary) -> void:
	var roofs := [
		[Color.html("7a9bd0"), Color.html("6688bd"), Color.html("8aaadb")],
		[Color.html("c75d43"), Color.html("b04d38"), Color.html("d97250")],
	]
	var pal: Array = roofs[tw.side]
	for b in tw.b:
		draw_rect(Rect2(b[0] + 1, b[1] + 1, b[2], b[3]), Color(0, 0, 0, 0.28))
	for b in tw.b:
		var r: float = b[4]
		if r > 0.82:
			# apartment block / industrial
			draw_rect(Rect2(b[0], b[1] - 1, b[2] + 1, b[3] + 1), Color.html("8a8f96"))
			draw_rect(Rect2(b[0], b[1] - 1, b[2] + 1, 1), Color.html("b5bac2"))
			draw_rect(Rect2(b[0] + 1, b[1] + 1, 1, 1), Color.html("2c3440"))
		else:
			draw_rect(Rect2(b[0], b[1], b[2], b[3]), pal[int(r * 3.5) % 3])
			draw_rect(Rect2(b[0], b[1] + b[3] - 1, b[2], 1), Color(0, 0, 0, 0.25))
			draw_rect(Rect2(b[0] + b[2] / 2.0 - 0.5, b[1], 1, b[3] - 1), Color(1, 1, 1, 0.16))
	if tw.burn > 0.0:
		for i in range(3):
			var bx: float = tw.x + (i - 1) * 14.0
			var by: float = tw.y + sin(i * 2.0) * 8.0
			if randf() < 0.1:
				pt.append({"k": "fire", "x": bx, "y": by, "vx": 0.0, "vy": -10.0, "l": 0.5, "m": 0.5, "s": 3.0})
			if randf() < 0.06:
				pt.append({"k": "smoke", "x": bx, "y": by, "vx": randf_range(-3, 3), "vy": -12.0, "l": 3.0, "m": 3.0, "s": 5.0, "dark": true})


func draw_bridge(o: Dictionary) -> void:
	var x: float = o.x
	var y: float = o.y
	if not o.alive:
		draw_rect(Rect2(x - 22, y - 3, 8, 6), Color.html("4a4036"))
		draw_rect(Rect2(x + 14, y - 3, 8, 6), Color.html("4a4036"))
		return
	draw_rect(Rect2(x - 22, y - 4, 44, 9), Color(0, 0, 0, 0.3))
	draw_rect(Rect2(x - 22, y - 4, 44, 7), Color.html("8a7d66"))
	draw_rect(Rect2(x - 22, y - 4, 44, 1), Color.html("c5b89c"))
	draw_rect(Rect2(x - 22, y + 2, 44, 1), Color.html("5c5140"))
	for i in range(-20, 22, 8):
		draw_rect(Rect2(x + i, y - 5, 2, 9), Color.html("5c5140"))


func draw_field(a: Dictionary, col: Color) -> void:
	draw_rect(Rect2(a.x - 48, a.y - 5, 96, 10), Color.html("4f545a"))
	var i := -44
	while i < 44:
		draw_rect(Rect2(a.x + i, a.y - 0.5, 5, 1), Color.html("d9d9d0"))
		i += 10
	draw_rect(Rect2(a.x - 34, a.y + 12, 70, 24), Color.html("6d7278"))
	facil(a.x - 40, a.y - 18, 14, 9, col)
	facil(a.x - 20, a.y - 18, 14, 9, col)
	facil(a.x, a.y - 18, 14, 9, col)
	draw_rect(Rect2(a.x + 24, a.y - 22, 3, 12), Color.html("3a3e44"))
	draw_rect(Rect2(a.x + 22, a.y - 26, 8, 5), Color.html("9aa3ad"))


func draw_port(x: float, y: float, col: Color) -> void:
	facil(x, y, 16, 10, col)
	draw_rect(Rect2(x + 6, y - 3, 24, 6), Color.html("5b4a30"))
	draw_rect(Rect2(x - 2, y - 12, 2, 10), Color.html("3a3e44"))
	draw_rect(Rect2(x - 2, y - 12, 8, 2), Color.html("3a3e44"))
	draw_rect(Rect2(x - 14, y + 8, 28, 4), Color.html("6b6f75"))


func draw_plant(x: float, y: float, alive: bool, col: Color) -> void:
	if not alive:
		draw_rect(Rect2(x - 10, y - 7, 20, 14), Color.html("2a2623"))
		return
	facil(x, y, 22, 14, col)
	for dx in [-8.0, 3.0]:
		# cooling towers
		var poly := PackedVector2Array([Vector2(x + dx, y - 14), Vector2(x + dx + 6, y - 14), Vector2(x + dx + 5, y - 4), Vector2(x + dx + 1, y - 4)])
		draw_colored_polygon(poly, Color.html("c8c4bc"))
		draw_rect(Rect2(x + dx, y - 14, 6, 1), Color.html("8f8b84"))
	if randf() < 0.03:
		pt.append({"k": "smoke", "x": x - 5, "y": y - 15, "vx": 3.0, "vy": -9.0, "l": 2.6, "m": 2.6, "s": 4.0})
	if randf() < 0.03:
		pt.append({"k": "smoke", "x": x + 6, "y": y - 15, "vx": 3.0, "vy": -9.0, "l": 2.6, "m": 2.6, "s": 4.0})


func draw_bld(b: Dictionary) -> void:
	var x: float = b.x
	var y: float = b.y
	var built: bool = b.prog >= 1.0
	if not b.alive:
		draw_rect(Rect2(x - 10, y - 7, 20, 14), Color.html("2a2623"))
		return
	var blue := Color.html("59708f")
	match b.type:
		"airfield":
			draw_field(b, blue)
		"plant":
			draw_plant(x, y, true, Color.html("6e7f99"))
		"solar":
			for i in range(3):
				for j in range(2):
					draw_rect(Rect2(x - 12 + i * 8, y - 8 + j * 9, 7, 7), Color.html("1f3a6b"))
					draw_rect(Rect2(x - 12 + i * 8, y - 8 + j * 9, 7, 1), Color.html("6a8fd0"))
		"droneport":
			facil(x, y, 18, 12, blue)
			draw_rect(Rect2(x - 4, y - 8, 8, 3), Color.html("c9d3df"))
			draw_rect(Rect2(x - 1, y - 11, 2, 4), Color.html("c9d3df"))
		"uavfac":
			facil(x, y, 22, 14, Color.html("6a7a8d"))
			draw_rect(Rect2(x - 9, y - 11, 5, 5), Color.html("3a3e44"))
			draw_rect(Rect2(x + 4, y - 3, 6, 3), Color.html("c9d3df"))
		"rocketfac":
			facil(x, y, 26, 16, Color.html("6a7a8d"))
			draw_rect(Rect2(x - 3, y - 18, 6, 14), Color.html("dddddd"))
			draw_colored_polygon(PackedVector2Array([Vector2(x - 3, y - 18), Vector2(x + 3, y - 18), Vector2(x, y - 24)]), Color.html("e5483f"))
		"derrick":
			draw_rect(Rect2(x - 5, y + 1, 10, 5), Color.html("3a3e44"))
			var sw := sin(b.anim * 2.0) * 3.0
			draw_line(Vector2(x - 6, y + 1), Vector2(x, y - 7), Color.html("8a8f96"), 2.0)
			draw_line(Vector2(x + 6, y + 1), Vector2(x, y - 7), Color.html("8a8f96"), 2.0)
			draw_line(Vector2(x - 8, y - 7 + sw), Vector2(x + 7, y - 7 - sw), Color.html("c75d43"), 2.5)
		"mine":
			facil(x, y, 18, 10, Color.html("7a746d"))
			draw_rect(Rect2(x - 8, y - 10, 16, 3), Color.html("3a3e44"))
			draw_rect(Rect2(x - 2, y - 14, 4, 5), Color.html("8a8f96"))
		"warehouse":
			facil(x, y, 22, 14, Color.html("8d8470"))
			draw_rect(Rect2(x - 8, y - 2, 16, 8), Color.html("5b4a30"))
		"sam":
			facil(x, y, 14, 10, Color.html("5f6f8a"))
			draw_rect(Rect2(x - 1, y - 9, 2, 7), Color.html("d6cfc8"))
			draw_rect(Rect2(x - 5, y - 9, 10, 2), Color.html("d6cfc8"))
		"lsam":
			facil(x, y, 20, 12, Color.html("5f6f8a"))
			for i in range(3):
				draw_line(Vector2(x - 6 + i * 6, y - 4), Vector2(x - 3 + i * 6, y - 14), Color.html("d6cfc8"), 2.0)
		"port":
			draw_port(x, y, blue)
	if not built:
		# scaffolding and progress
		draw_rect(Rect2(x - 16, y - 16, 32, 32), Color(0.1, 0.1, 0.1, 0.5))
		draw_rect(Rect2(x - 16, y - 16, 32, 32), Color(1, 0.8, 0.2, 0.7), false, 1.5)
		draw_rect(Rect2(x - 16, y + 18, 32, 5), Color.BLACK)
		draw_rect(Rect2(x - 15, y + 19, 30 * b.prog, 3), Color.html("f0c660"))
	elif b.hp < b.maxhp:
		draw_rect(Rect2(x - 12, y + 12, 24, 4), Color.BLACK)
		draw_rect(Rect2(x - 11, y + 13, 22 * clampf(b.hp / b.maxhp, 0.0, 1.0), 2), Color.html("86d963") if b.hp / b.maxhp > 0.5 else Color.html("f0b429"))


func draw_truck(x: float, y: float, ang: float, enemy: bool, stowed: float) -> void:
	draw_set_transform(Vector2(x, y) * 1.0, ang, Vector2.ONE)
	var body := Color.html("5d6b4a") if not enemy else Color.html("7a4a42")
	draw_rect(Rect2(-8, -4, 16, 8), Color(0, 0, 0, 0.3))
	draw_rect(Rect2(-9, -4, 18, 8), body)
	draw_rect(Rect2(5, -4, 5, 8), body.lightened(0.15))
	draw_rect(Rect2(8, -3, 2, 6), Color.html("3a4a5a"))
	# launcher tube: lies flat or is raised
	if stowed > 0.5:
		draw_rect(Rect2(-8, -1.5, 13, 3), Color.html("c9c9c0"))
		draw_colored_polygon(PackedVector2Array([Vector2(-8, -1.5), Vector2(-11, 0), Vector2(-8, 1.5)]), Color.html("dd4433"))
	else:
		draw_rect(Rect2(-8, -1.5, 13, 3), Color.html("c9c9c0"))
		draw_rect(Rect2(-8, -4, 3, 1.5), Color.html("ffcc55"))
	for wx in [-6.0, 0.0, 6.0]:
		draw_rect(Rect2(wx - 1.5, -5, 3, 2), Color.BLACK)
		draw_rect(Rect2(wx - 1.5, 3, 3, 2), Color.BLACK)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func flag_cols(id: String) -> Array:
	if id == "kar":
		return [Color.html("e5483f"), Color.html("222222")]
	var n := nat_of(id)
	if n.is_empty():
		return [Color.GRAY, Color.GRAY]
	return [n.c1, n.c2]


func draw_ship(s: Dictionary) -> void:
	var fc := flag_cols(s.flag)
	draw_set_transform(Vector2(s.x, s.y), s.ang - PI / 2.0, Vector2.ONE)
	draw_rect(Rect2(-4, -9, 8, 20), Color(0, 0.08, 0.24, 0.3))
	if s.type == "wship":
		draw_rect(Rect2(-3, -12, 6, 24), Color.html("5a626b"))
		draw_colored_polygon(PackedVector2Array([Vector2(-3, -12), Vector2(3, -12), Vector2(0, -17)]), Color.html("5a626b"))
		draw_rect(Rect2(-2, -4, 4, 8), Color.html("8a929b"))
		draw_rect(Rect2(-1, -8, 2, 3), Color.html("2c3138"))
		draw_rect(Rect2(-1, 6, 2, 3), Color.html("2c3138"))
		draw_rect(Rect2(3, -12, 2, 3), fc[0])
	else:
		draw_rect(Rect2(-3, -9, 6, 18), Color.html("59616b"))
		draw_rect(Rect2(-2, -12, 4, 3), Color.html("7d8791"))
		draw_rect(Rect2(-2, 6, 4, 3), s.col)
		draw_rect(Rect2(-2, 2, 4, 3), Color.html("e9d49a"))
		draw_rect(Rect2(-2, -2, 4, 3), Color.html("c75d43"))
		draw_rect(Rect2(-1, -6, 2, 2), Color.html("dddddd"))
		draw_rect(Rect2(3, 6, 2, 3), fc[0])
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if s.type == "ship" and s.dock > 0.0:
		draw_rect(Rect2(s.x - 7, s.y - 1, 2, 2), Color(1, 1, 1, 0.8))


func draw_arrow(x: float, y: float, dir: float, ln: float, col: Color) -> void:
	var dark := Color.html("2a1608")
	draw_line(Vector2(x - 6 * dir, y), Vector2(x + ln * dir, y), dark, 6.0)
	draw_line(Vector2(x - 6 * dir, y - 9), Vector2(x - 6 * dir, y + 9), dark, 6.0)
	draw_line(Vector2(x - 6 * dir, y), Vector2(x + ln * dir, y), col, 3.0)
	draw_line(Vector2(x - 6 * dir, y - 9), Vector2(x - 6 * dir, y + 9), col, 3.0)
	draw_colored_polygon(PackedVector2Array([Vector2(x + (ln + 12) * dir, y), Vector2(x + (ln - 3) * dir, y - 10), Vector2(x + (ln - 3) * dir, y + 10)]), dark)
	draw_colored_polygon(PackedVector2Array([Vector2(x + (ln + 8) * dir, y), Vector2(x + (ln - 1) * dir, y - 7), Vector2(x + (ln - 1) * dir, y + 7)]), col)


func draw_fx() -> void:
	# contrails
	for o in trail:
		var a: float = o.l / o.m
		var w: float = o.w
		draw_rect(Rect2(o.x - w / 2.0, o.y - w / 2.0, w, w), Color(0.95, 0.96, 0.98, a * 0.6))
	# ballistic and cruise missiles
	for m in msl:
		if m.t < 0.0 and not m.done:
			continue
		var f := clampf(m.t / m.dur, 0.0, 1.0)
		var al := clampf(m.fade / 3.0, 0.0, 1.0) if m.done else 1.0
		var steps := 30
		var prev := msl_pos(m, maxf(0.0, f - 0.35))
		for i in range(steps):
			var u := maxf(0.0, f - 0.35) + (minf(f, 1.0) - maxf(0.0, f - 0.35)) * (i + 1) / steps
			var cur := msl_pos(m, u)
			var tail := float(i) / steps
			var base := Color(0.78, 0.27, 0.23, al * tail) if m.side == 1 else Color(0.66, 0.44, 0.24, al * tail)
			draw_line(prev, cur, base, 3.0)
			draw_line(prev, cur, Color(1, 0.89, 0.67, al * tail * 0.75), 1.1)
			prev = cur
		if not m.done:
			var hd := msl_pos(m, f)
			var nxt := msl_pos(m, minf(1.0, f + 0.02))
			var dir := (nxt - hd).angle()
			draw_set_transform(hd, dir, Vector2.ONE)
			draw_rect(Rect2(-4, -1.3, 8, 2.6), Color.html("ececec"))
			draw_colored_polygon(PackedVector2Array([Vector2(4, -1.3), Vector2(7, 0), Vector2(4, 1.3)]), Color.html("dd4433"))
			draw_rect(Rect2(-5, -2.4, 2, 4.8), Color.html("9aa0a8"))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			draw_circle(hd - Vector2(cos(dir), sin(dir)) * 6.0, 2.5 + randf(), Color(1, 0.8, 0.3, 0.9))
			if sel != null and is_same(sel, m):
				draw_arc(hd, 12.0, 0.0, TAU, 20, Color(1, 0.54, 0.16), 2.0)
	for p in pt:
		var a := clampf(p.l / p.m, 0.0, 1.0)
		match p.k:
			"smoke":
				var sc := Color(0.8, 0.8, 0.82, a * 0.5)
				if p.get("dark", false):
					sc = Color(0.25, 0.24, 0.24, a * 0.6)
				elif p.get("dust", false):
					sc = Color(0.7, 0.62, 0.45, a * 0.5)
				draw_rect(Rect2(p.x - p.s / 2.0, p.y - p.s / 2.0, p.s, p.s), sc)
			"fire":
				var fc := Color(1, 0.86, 0.35, a) if a > 0.6 else (Color(1, 0.5, 0.15, a) if a > 0.3 else Color(0.8, 0.2, 0.1, a))
				draw_rect(Rect2(p.x - p.s / 2.0, p.y - p.s / 2.0, p.s, p.s), fc)
			"deb":
				if p.get("still", false):
					draw_rect(Rect2(p.x, p.y, 3, 2), p.c)
				else:
					draw_rect(Rect2(p.x, p.y, 2, 2), Color(p.c.r, p.c.g, p.c.b, a))
			"oil":
				draw_circle(Vector2(p.x, p.y), p.s * (1.3 - a * 0.3), Color(0.08, 0.08, 0.1, a * 0.45))
			"ring":
				draw_arc(Vector2(p.x, p.y), p.s * (1.6 - a) * 1.6, 0.0, TAU, 20, Color(1, 0.86, 0.55, a), 2.0)
			"flash":
				draw_circle(Vector2(p.x, p.y), p.s * (0.6 + 0.6 * (1.0 - a)), Color(1, 0.96, 0.8, a))
			"spark":
				draw_rect(Rect2(p.x - 1.5, p.y - 1.5, 3, 3), Color(0.7, 0.95, 1.0, a))
			"wake":
				draw_rect(Rect2(p.x - p.s / 2.0, p.y - 1, p.s * (2.0 - a), 2), Color(1, 1, 1, a * 0.5))
			"plus":
				draw_rect(Rect2(p.x - 1, p.y - p.s / 2.0, 2, p.s), Color(0.5, 1, 0.5, a))
				draw_rect(Rect2(p.x - p.s / 2.0, p.y - 1, p.s, 2), Color(0.5, 1, 0.5, a))
	# projectiles in flight
	for p in pr:
		var f := clampf(p.t / p.dur, 0.0, 1.0)
		if p.k == "gb":
			# bomb falling: shadow on the ground, bomb above it
			var h := 18.0 * (1.0 - f * f)
			draw_circle(Vector2(p.x + 1.0, p.y + 1.0), 2.4, Color(0, 0, 0, 0.35))
			draw_rect(Rect2(p.x - 1.2, p.y - h - 2.5, 2.4, 5), Color.html("3a3f44"))
			draw_rect(Rect2(p.x - 2, p.y - h - 3.5, 4, 1.4), Color.html("e5483f"))
			draw_rect(Rect2(p.x - 0.6, p.y - h - 1.0, 1.2, 1.2), Color.html("fff3b0"))
		elif p.k == "rk" or p.k == "nm" or p.k == "enm":
			var f2 := clampf(p.t / p.dur, 0.0, 1.0)
			var bx := lerpf(p.sx, p.tx, maxf(0.0, f2 - 0.2))
			var by := lerpf(p.sy, p.ty, maxf(0.0, f2 - 0.2))
			draw_line(Vector2(bx, by), Vector2(p.x, p.y), Color(1, 0.67, 0.24, 0.9), 1.6)
			draw_rect(Rect2(p.x - 1.2, p.y - 1.2, 2.4, 2.4), Color(1, 1, 0.8))
		elif p.k == "hyp":
			var bx2 := lerpf(p.sx, p.tx, maxf(0.0, f - 0.3))
			var by2 := lerpf(p.sy, p.ty, maxf(0.0, f - 0.3))
			draw_line(Vector2(bx2, by2), Vector2(p.x, p.y), Color(0.6, 0.9, 1.0, 0.8), 4.0)
			draw_line(Vector2(bx2, by2), Vector2(p.x, p.y), Color.WHITE, 1.6)
		else:
			var col := Color(1, 0.39, 0.31, 0.95)
			if p.k == "aa" or p.k == "psam":
				col = Color(0.47, 0.78, 1, 0.95)
			elif p.k == "ab":
				col = Color(1, 0.9, 0.47, 0.9)
			draw_line(Vector2(lerpf(p.sx, p.x, 0.6), lerpf(p.sy, p.y, 0.6)), Vector2(p.x, p.y), col, 2.0)
	# artillery shells
	for s in shells:
		if s.delay > 0.0:
			continue
		var f3 := clampf(s.t / s.dur, 0.0, 1.0)
		var h2 := 40.0 * 4.0 * f3 * (1.0 - f3)
		draw_circle(Vector2(s.x + 1, s.y + 1), 2.0, Color(0, 0, 0, 0.3))
		draw_rect(Rect2(s.x - 1.5, s.y - h2 - 1.5, 3, 3), Color.html("2a2a2a"))
		draw_rect(Rect2(s.x - 0.8, s.y - h2 - 3.5, 1.6, 2), Color(1, 0.8, 0.3))
		# landing marker
		draw_arc(Vector2(s.tx, s.ty), 5.0 + 4.0 * (1.0 - f3), 0.0, TAU, 12, Color(1, 0.4, 0.2, 0.5), 1.0)


func draw_marker(p: Vector2, letter: String, col: Color, hp: float, mx: float, pulse: bool, badge: int = 0) -> void:
	var s := 46.0
	var r := Rect2(p.x - s / 2.0, p.y - s / 2.0, s, s)
	draw_rect(r, Color(0.07, 0.04, 0.04, 0.86))
	draw_rect(r.grow(-2), col, false, 4.0)
	draw_string(ThemeDB.fallback_font, Vector2(p.x - s / 2.0, p.y + 10), letter, HORIZONTAL_ALIGNMENT_CENTER, s, 28, Color.html("f4ead0"))
	if hp < mx:
		draw_rect(Rect2(p.x - s / 2.0, p.y + s / 2.0 + 3, s, 8), Color.BLACK)
		var fc: Color = COL.green if hp / mx > 0.5 else (Color.html("f0b429") if hp / mx > 0.25 else COL.red)
		draw_rect(Rect2(p.x - s / 2.0 + 1, p.y + s / 2.0 + 4, (s - 2) * clampf(hp / mx, 0.0, 1.0), 6), fc)
	if badge > 0:
		draw_rect(Rect2(p.x + s / 2.0 - 12, p.y - s / 2.0 - 10, 30, 22), Color(0.07, 0.04, 0.04, 0.95))
		draw_rect(Rect2(p.x + s / 2.0 - 12, p.y - s / 2.0 - 10, 30, 22), COL.orange, false, 2.0)
		draw_string(ThemeDB.fallback_font, Vector2(p.x + s / 2.0 - 12, p.y - s / 2.0 + 7), "x%d" % badge, HORIZONTAL_ALIGNMENT_CENTER, 30, 17, COL.orange)
	if pulse:
		var al := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 160.0)
		draw_rect(r.grow(8), Color(1, 0.54, 0.16, al), false, 3.0)


func draw_plane(sp: Vector2, ang: float, k: float, key: String, side: String, shadow: bool, alt: float, bank: float, afterburn: bool) -> void:
	var tex: ImageTexture = spr[key + "_" + side]
	var stex: ImageTexture = spr[key + "_s"]
	var kk := k * (0.85 + 0.2 * alt)
	if shadow:
		var off := Vector2(2.0 + 8.0 * alt, 3.0 + 10.0 * alt) * k * 0.6
		draw_set_transform(sp + off, ang + PI / 2.0, Vector2(kk * (1.0 - 0.1 * absf(bank)), kk))
		draw_texture(stex, Vector2(-5.5, -5.5), Color(1, 1, 1, 0.3 - 0.1 * alt))
	draw_set_transform(sp, ang + PI / 2.0, Vector2(kk * (1.0 - 0.18 * absf(bank)), kk))
	draw_texture(tex, Vector2(-5.5, -5.5))
	if afterburn:
		draw_rect(Rect2(-1.0, 5.5, 2.0, 2.5 + randf() * 2.0), Color(1, 0.7, 0.2, 0.9))
		draw_rect(Rect2(-0.5, 5.5, 1.0, 1.5), Color(1, 1, 0.8, 0.9))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func draw_hud_layer() -> void:
	var f := ThemeDB.fallback_font
	var now := Time.get_ticks_msec()
	# town names
	if zoom > 1.0:
		for tw in towns:
			var sp := w2s(tw.x, tw.y + tw.r + 10.0)
			if sp.x < -100 or sp.x > vw + 100 or sp.y < -20 or sp.y > vh + 20:
				continue
			var col := Color.html("9cc2ff") if tw.side == 0 else Color.html("ffb3a8")
			var nm: String = tw.name
			if not tw.lit:
				nm += " (dark)"
			draw_string_outline(f, sp - Vector2(100, 0), nm, HORIZONTAL_ALIGNMENT_CENTER, 200, 22, 6, Color(0.03, 0.04, 0.08, 0.85))
			draw_string(f, sp - Vector2(100, 0), nm, HORIZONTAL_ALIGNMENT_CENTER, 200, 22, col)
	# enemy markers
	for o in tg:
		if not o.alive or (o.hidden and o.reveal <= 0.0):
			continue
		var p := w2s(o.x, o.y)
		if p.x < -40 or p.y < -60 or p.x > vw + 40 or p.y > vh + 40:
			continue
		var col: Color = Color.html("f0b429") if is_neutral(o) else COL.red
		var pulse: bool = sel != null and sel.k == "ac" and sel.order != null and sel.order.has("tg") and is_same(sel.order.tg, o)
		draw_marker(p + Vector2(0, -28), D.TYPES[o.type].L, col, o.hp, o.maxhp, pulse, o.assigned)
	# our buildings
	for b in bl:
		var p := w2s(b.x, b.y)
		if p.x < -40 or p.y < -60 or p.x > vw + 40 or p.y > vh + 100:
			continue
		var letter: String = D.BUILD[b.type].L
		var col: Color = COL.blue
		if b.warn > 0.0:
			col = COL.red if sin(now / 110.0) > 0.0 else Color.WHITE
			letter = "!"
		elif not b.alive:
			col = Color(0.33, 0.33, 0.33)
		elif b.prog < 1.0:
			col = Color(0.9, 0.7, 0.2)
		if zoom > 0.8 or b.type == "airfield" or b.type == "plant" or b.warn > 0.0:
			draw_marker(p + Vector2(0, -44), letter, col, b.hp if b.alive else b.maxhp, b.maxhp, false)
	# truck markers and routes
	for tr in trucks:
		var p := w2s(tr.x, tr.y)
		draw_truck_world(tr)
		if tr.fire != null and (tr.st == "move" or tr.st == "deploy"):
			var fp: Vector2 = tr.fire
			draw_dashed(p, w2s(fp.x, fp.y), Color(1, 0.4, 0.2, 0.8))
			draw_arc(w2s(fp.x, fp.y), 16.0 + 4.0 * sin(now / 150.0), 0.0, TAU, 20, Color(1, 0.4, 0.2), 3.0)
		if sel != null and is_same(sel, tr):
			draw_arc(p, TRUCK_RANGE * zoom, 0.0, TAU, 64, Color(1, 0.5, 0.2, 0.25), 2.0)
			draw_rect(Rect2(p.x - 24, p.y - 24, 48, 48), Color(1, 0.54, 0.16), false, 3.0)
		draw_rect(Rect2(p.x - 14, p.y + 16, 28, 20), Color(0.04, 0.05, 0.04, 0.8))
		draw_string(f, Vector2(p.x - 14, p.y + 32), "T%d" % tr.n, HORIZONTAL_ALIGNMENT_CENTER, 28, 16, Color.WHITE)
	# selected aircraft route
	if sel != null and sel.k == "ac" and not sel.dead:
		if sel.st == "fly" and sel.order != null and sel.order.t == "route":
			var prev := w2s(sel.x, sel.y)
			for i in range(sel.ri, sel.route.size()):
				var q: Vector2 = sel.route[i]
				var qs := w2s(q.x, q.y)
				draw_dashed(prev, qs, Color(1, 0.54, 0.16, 0.9))
				draw_circle(qs, 7.0, Color(1, 0.54, 0.16))
				draw_circle(qs, 3.0, Color.BLACK)
				prev = qs
		elif sel.order != null and sel.order.t != "rtb":
			var tx := 0.0
			var ty := 0.0
			if sel.order.t == "attack":
				tx = sel.order.tg.x
				ty = sel.order.tg.y
			elif sel.order.t == "loiter":
				tx = sel.order.x
				ty = sel.order.y
			if sel.order.t != "route":
				var a := w2s(sel.x, sel.y)
				var b := w2s(tx, ty)
				draw_dashed(a, b, Color(1, 0.54, 0.16, 0.9))
				if sel.order.t == "loiter":
					draw_arc(b, 14.0 + 5.0 * sin(now / 200.0), 0.0, TAU, 24, Color(1, 0.54, 0.16, 0.9), 3.0)
		# route being drawn
		if mode == "route" and route_pts.size() > 0:
			var prev2 := w2s(sel.x, sel.y)
			for q in route_pts:
				var qs2 := w2s(q.x, q.y)
				draw_dashed(prev2, qs2, Color(0.6, 1, 0.6, 0.9))
				draw_circle(qs2, 7.0, Color(0.6, 1, 0.6))
				draw_circle(qs2, 3.0, Color.BLACK)
				prev2 = qs2
	# fleets
	for fl in fleets:
		draw_fleet(fl)
	# uavs
	for u in uavs:
		var p := w2s(u.x, u.y)
		draw_set_transform(p, u.ang, Vector2(2.2, 2.2))
		draw_colored_polygon(PackedVector2Array([Vector2(7, 0), Vector2(-5, -5), Vector2(-3, 0), Vector2(-5, 5)]), Color(0.07, 0.07, 0.07) if not u.rec else Color(0.1, 0.25, 0.1))
		draw_polyline(PackedVector2Array([Vector2(7, 0), Vector2(-5, -5), Vector2(-3, 0), Vector2(-5, 5), Vector2(7, 0)]), Color.WHITE, 0.6)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if u.rec:
			draw_arc(w2s(u.tx, u.ty), 150.0 * zoom, 0.0, TAU, 48, Color(0.5, 1, 0.6, 0.3), 2.0)
	# enemy drones
	for e in eu:
		var p := w2s(e.x, e.y)
		draw_set_transform(p, e.ang, Vector2(2.0, 2.0))
		draw_colored_polygon(PackedVector2Array([Vector2(6, 0), Vector2(-4, -6), Vector2(-3, 0), Vector2(-4, 6)]), Color(0.4, 0.08, 0.06))
		draw_polyline(PackedVector2Array([Vector2(6, 0), Vector2(-4, -6), Vector2(-3, 0), Vector2(-4, 6), Vector2(6, 0)]), Color(1, 0.5, 0.4), 0.6)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var k := clampf(zoom * 2.0, 2.8, 4.4)
	for e in ea:
		draw_plane(w2s(e.x, e.y), e.ang, k, "ftr", "e", true, 1.0, 0.0, true)
	for a in ac:
		if a.dead:
			continue
		var sp := w2s(a.x, a.y)
		if sp.x < -60 or sp.y < -60 or sp.x > vw + 60 or sp.y > vh + 60:
			continue
		var grounded: bool = a.st == "parked" or a.st == "rearm"
		var ab: bool = a.st == "takeoff" or (a.st == "taxi" and a.tm > 1.0)
		draw_plane(sp, a.ang, k * (0.9 if grounded else 1.0), a.type, "p", not grounded, a.alt, a.bank, ab or a.st == "fly")
		var is_sel: bool = sel != null and is_same(sel, a)
		if is_sel:
			var r := 30.0 + 3.0 * sin(now / 180.0)
			draw_rect(Rect2(sp.x - r, sp.y - r, r * 2, r * 2), Color(1, 0.54, 0.16), false, 3.0)
		if zoom > 1.0 or is_sel:
			draw_rect(Rect2(sp.x - 14, sp.y + 24, 28, 22), Color(0.04, 0.05, 0.04, 0.8))
			draw_string(f, Vector2(sp.x - 14, sp.y + 41), str(a.n), HORIZONTAL_ALIGNMENT_CENTER, 28, 18, Color.WHITE)
	# placement ghost
	if mode == "place" and place_type != "":
		var ps := w2s(place_pos.x, place_pos.y)
		var okp := can_place(place_type, place_pos)
		var rr: float = float(D.BUILD[place_type].r) * zoom
		draw_circle(ps, rr, Color(0.3, 1, 0.3, 0.28) if okp else Color(1, 0.2, 0.2, 0.3))
		draw_arc(ps, rr, 0.0, TAU, 32, Color(0.5, 1, 0.5) if okp else Color(1, 0.3, 0.3), 3.0)
		var rng_r := 0.0
		if place_type == "sam":
			rng_r = 150.0
		elif place_type == "lsam":
			rng_r = 270.0
		if rng_r > 0.0:
			draw_arc(ps, rng_r * zoom, 0.0, TAU, 48, Color(0.3, 0.6, 1.0, 0.5), 2.0)
	# mode banner
	if mode != "":
		var msg := ""
		match mode:
			"uav": msg = "TAP A TARGET FOR THE UAV"
			"recon": msg = "TAP THE AREA TO SCOUT"
			"strike": msg = "TAP AN ENEMY MARKER TO STRIKE"
			"art": msg = "TAP THE TARGET FOR ARTILLERY (%d shells)" % shell_n
			"smoke": msg = "TAP NEAR THE FRONT FOR SMOKE"
			"med": msg = "TAP AN ARMY GROUP TO TREAT"
			"route": msg = "TAP POINTS FOR THE ROUTE (%d). PRESS GO." % route_pts.size()
			"hyper": msg = "TAP THE TARGET FOR THE HYPERSONIC MISSILE"
			"place": msg = "TAP A FREE SPOT FOR THE %s" % String(D.BUILD[place_type].name).to_upper()
		draw_rect(Rect2(vw / 2.0 - 320, vh * 0.3 - 26, 640, 48), Color(0.04, 0.05, 0.04, 0.85))
		draw_string(f, Vector2(vw / 2.0 - 320, vh * 0.3 + 9), msg, HORIZONTAL_ALIGNMENT_CENTER, 640, 22, COL.orange)


func draw_dashed(a: Vector2, b: Vector2, col: Color) -> void:
	var dl := a.distance_to(b)
	var n := int(dl / 22.0)
	for i in range(n):
		if i % 2 == 0:
			var p0 := a.lerp(b, float(i) / maxf(1.0, n))
			var p1 := a.lerp(b, float(i + 1) / maxf(1.0, n))
			draw_line(p0, p1, col, 4.0)


func draw_truck_world(tr: Dictionary) -> void:
	var p := w2s(tr.x, tr.y)
	draw_set_transform(p, 0.0, Vector2(zoom * 1.6, zoom * 1.6))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var s := clampf(zoom * 1.6, 1.8, 3.6)
	draw_set_transform(p, tr.ang, Vector2(s, s))
	var body := Color.html("5d6b4a")
	draw_rect(Rect2(-9, -4, 18, 8), body)
	draw_rect(Rect2(5, -4, 5, 8), body.lightened(0.2))
	draw_rect(Rect2(8, -3, 2, 6), Color.html("3a4a5a"))
	var raised: bool = tr.st == "deploy" or tr.st == "stow"
	var tube := Color.html("e4e4dc")
	if raised:
		var u: float = clampf(tr.t / 1.5, 0.0, 1.0) if tr.st == "deploy" else clampf(1.0 - tr.t / 1.5, 0.0, 1.0)
		draw_rect(Rect2(-8, -1.5 - 3.0 * u, 13, 3), tube)
		draw_colored_polygon(PackedVector2Array([Vector2(5, -1.5 - 3.0 * u), Vector2(8, -3.0 * u), Vector2(5, 1.5 - 3.0 * u)]), Color.html("dd4433"))
		draw_rect(Rect2(-12, -2, 4, 4), Color(1, 0.8, 0.4, 0.6 * u))
	else:
		draw_rect(Rect2(-8, -1.5, 13, 3), tube)
		draw_colored_polygon(PackedVector2Array([Vector2(5, -1.5), Vector2(8, 0), Vector2(5, 1.5)]), Color.html("dd4433"))
	for wx in [-6.0, 0.0, 6.0]:
		draw_rect(Rect2(wx - 1.5, -5, 3, 2), Color.BLACK)
		draw_rect(Rect2(wx - 1.5, 3, 3, 2), Color.BLACK)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func draw_fleet(fl: Dictionary) -> void:
	var p := w2s(fl.x, fl.y)
	var s := clampf(zoom * 1.5, 1.6, 3.2)
	for i in range(fl.ships):
		var off: Vector2 = Vector2(-sin(fl.ang), cos(fl.ang)) * (i - (fl.ships - 1) / 2.0) * 16.0 * s * 0.8
		draw_set_transform(p + off, fl.ang, Vector2(s, s))
		draw_rect(Rect2(-9, -3, 18, 6), Color(0, 0.1, 0.3, 0.3))
		draw_rect(Rect2(-10, -3, 20, 6), Color.html("6c7a8a"))
		draw_colored_polygon(PackedVector2Array([Vector2(10, -3), Vector2(14, 0), Vector2(10, 3)]), Color.html("6c7a8a"))
		draw_rect(Rect2(-2, -2, 6, 4), Color.html("a9b6c4"))
		draw_rect(Rect2(-7, -1, 3, 2), Color.html("2c3138"))
		draw_rect(Rect2(6, -1, 3, 2), Color.html("2c3138"))
		draw_rect(Rect2(-10, -3, 2, 6), Color.html("4d93ff"))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var is_sel: bool = sel != null and is_same(sel, fl)
	draw_rect(Rect2(p.x - 44, p.y - 40, 88, 22), Color(0.04, 0.12, 0.2, 0.85))
	draw_rect(Rect2(p.x - 44, p.y - 40, 88, 22), COL.blue if not is_sel else COL.orange, false, 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(p.x - 44, p.y - 23), "FLEET %d x%d" % [fl.n, fl.ships], HORIZONTAL_ALIGNMENT_CENTER, 88, 16, Color.WHITE)
	if is_sel and fl.order != null:
		var o: Dictionary = fl.order
		if o.t == "move":
			draw_dashed(p, w2s(o.x, o.y), Color(0.4, 0.7, 1, 0.9))
		elif o.has("tg") and o.tg.alive:
			draw_dashed(p, w2s(o.tg.x, o.tg.y), Color(1, 0.5, 0.3, 0.9))
	if is_sel:
		draw_arc(p, 480.0 * zoom, 0.0, TAU, 64, Color(1, 0.5, 0.2, 0.18), 2.0)


# ====================================================================== UI state
var afs_pos: Array = []
var feed_dirty := true
var chips_dirty := true
var pend: Array = []
var calc_t := 0.0
var sheet_sig := ""
var sel_sig := ""
var feed_sig := ""
var chips_sig := ""
var blockers: Array = []
var dyn: Array = []
var ui: CanvasLayer
var root_c: Control
var hud_pn: PanelContainer
var l_coin: Label
var l_oil: Label
var l_metal: Label
var l_score: Label
var l_time: Label
var l_pow: Label
var pb_score: ProgressBar
var btn_speed: Button
var btn_pause: Button
var feed_box: VBoxContainer
var banner_box: VBoxContainer
var pn_toast: PanelContainer
var l_toast: Label
var side_box: VBoxContainer
var bottom_box: VBoxContainer
var mode_box: HBoxContainer
var btn_go: Button
var chips_box: HBoxContainer
var chips_sc: ScrollContainer
var pn_sel: PanelContainer
var sel_box: VBoxContainer
var pn_sheet: PanelContainer
var sheet_box: VBoxContainer
var sheet_sc: ScrollContainer
var tabbar: HBoxContainer
var tab_btns := {}
var side_btns := {}
var ov: ColorRect
var ov_box: VBoxContainer
var hud_tick := 0.0

const TABS := [["map", "Map"], ["cities", "Cities"], ["air", "Aviation"], ["ad", "Defense"], ["army", "Army"], ["pol", "Politics"], ["ind", "Industry"]]
const STNAME := {"parked": "Parked", "taxi": "Taxiing", "takeoff": "Taking off", "fly": "In flight", "loiter": "Patrolling",
	"rtb": "Returning", "landing": "Landing", "rearm": "Rearming"}
const BUY_DESC := {
	"truck": "Launches ballistic missiles at far targets. Select it, then tap an enemy marker. It hides after firing.",
	"msl": "One ballistic missile for the launcher trucks.",
	"uav": "A kamikaze drone launched from a drone port.",
	"fleet": "Three warships with naval and cruise missiles. Needs a harbor on the south coast.",
	"brig": "Adds 30 strength to the weakest army group.",
	"smoke": "Two smoke screens that protect our army from enemy fire.",
	"shell": "Ten artillery shells for the front line.",
	"med": "Two field hospitals that heal an army group.",
}


# ====================================================================== ui helpers
func sbox(bg: Color, border: Color, bw: int = 3) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(4)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s


func make_theme() -> Theme:
	var th := Theme.new()
	th.default_font_size = 22
	var brass := Color.html("8b6f33")
	th.set_stylebox("normal", "Button", sbox(Color.html("3a4a2a"), brass))
	th.set_stylebox("hover", "Button", sbox(Color.html("3a4a2a"), brass))
	th.set_stylebox("pressed", "Button", sbox(Color.html("55703a"), Color.html("d1a94c")))
	th.set_stylebox("disabled", "Button", sbox(Color.html("2a3020"), Color.html("4a4630")))
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	th.set_color("font_color", "Button", COL.text)
	th.set_color("font_hover_color", "Button", COL.text)
	th.set_color("font_pressed_color", "Button", Color.WHITE)
	th.set_color("font_disabled_color", "Button", Color(0.5, 0.5, 0.45))
	th.set_font_size("font_size", "Button", 22)
	th.set_stylebox("panel", "PanelContainer", sbox(Color(0.1, 0.13, 0.09, 0.93), brass))
	th.set_color("font_color", "Label", COL.text)
	th.set_font_size("font_size", "Label", 22)
	th.set_stylebox("background", "ProgressBar", sbox(Color.html("121810"), Color.html("0a0e08"), 2))
	th.set_stylebox("fill", "ProgressBar", sbox(Color.html("3b86f0"), Color.html("3b86f0"), 0))
	th.set_constant("separation", "VBoxContainer", 6)
	th.set_constant("separation", "HBoxContainer", 6)
	return th


func mk_label(text: String, size: int = 22, color: Color = COL.text) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func mk_wrap(text: String, size: int = 20, color: Color = COL.dim) -> Label:
	var l := mk_label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(260, 0)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


func mk_button(text: String, cb: Callable, kind: String = "", h: float = 60.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, h)
	b.pressed.connect(cb)
	if kind == "g":
		b.add_theme_stylebox_override("normal", sbox(Color.html("2f6b2a"), Color.html("58b04a")))
		b.add_theme_stylebox_override("hover", sbox(Color.html("2f6b2a"), Color.html("58b04a")))
	elif kind == "r":
		b.add_theme_stylebox_override("normal", sbox(Color.html("4a2320"), Color.html("a8423a")))
		b.add_theme_stylebox_override("hover", sbox(Color.html("4a2320"), Color.html("a8423a")))
	elif kind == "o":
		b.add_theme_stylebox_override("normal", sbox(Color.html("6b4a1c"), Color.html("e0a040")))
		b.add_theme_stylebox_override("hover", sbox(Color.html("6b4a1c"), Color.html("e0a040")))
	return b


func mk_panel(child: Control) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_child(child)
	return p


func ignore_mouse(c: Control) -> void:
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE


func add_dyn(c: Control, f: Callable) -> void:
	dyn.append([c, f])


func update_dyn() -> void:
	var keep: Array = []
	for d in dyn:
		if not is_instance_valid(d[0]):
			continue
		var c: Control = d[0]
		keep.append(d)
		var v: Variant = d[1].call()
		if c is ProgressBar:
			c.value = float(v)
		elif c is Label:
			c.text = String(v)
	dyn = keep


# ====================================================================== build ui
func build_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)
	root_c = Control.new()
	root_c.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_c.theme = make_theme()
	ignore_mouse(root_c)
	ui.add_child(root_c)

	# ---- top HUD
	hud_pn = PanelContainer.new()
	hud_pn.set_anchors_preset(Control.PRESET_TOP_WIDE)
	hud_pn.add_theme_stylebox_override("panel", sbox(Color(0.07, 0.1, 0.06, 0.92), Color.html("8b6f33"), 2))
	root_c.add_child(hud_pn)
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 2)
	hud_pn.add_child(hv)
	var r1 := HBoxContainer.new()
	hv.add_child(r1)
	l_coin = mk_label("0", 26, COL.gold)
	l_oil = mk_label("0", 26, Color.html("c9c9d6"))
	l_metal = mk_label("0", 26, Color.html("9fc0e0"))
	for l in [l_coin, l_oil, l_metal]:
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r1.add_child(l)
	l_time = mk_label("0:00", 24, COL.dim)
	r1.add_child(l_time)
	btn_pause = mk_button("II", _on_pause, "", 44)
	btn_pause.custom_minimum_size = Vector2(56, 44)
	r1.add_child(btn_pause)
	btn_speed = mk_button("x1", _on_speed, "", 44)
	btn_speed.custom_minimum_size = Vector2(64, 44)
	r1.add_child(btn_speed)
	var r2 := HBoxContainer.new()
	hv.add_child(r2)
	l_score = mk_label("Score 0 / 15000", 20, COL.orange)
	r2.add_child(l_score)
	pb_score = ProgressBar.new()
	pb_score.max_value = D.GOAL
	pb_score.show_percentage = false
	pb_score.custom_minimum_size = Vector2(0, 14)
	pb_score.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pb_score.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pb_score.add_theme_stylebox_override("fill", sbox(COL.orange, COL.orange, 0))
	r2.add_child(pb_score)
	l_pow = mk_label("Power", 20, Color.html("ffe08a"))
	r2.add_child(l_pow)

	# ---- feed, banners, toast
	feed_box = VBoxContainer.new()
	feed_box.position = Vector2(10, 300)
	feed_box.custom_minimum_size = Vector2(430, 0)
	ignore_mouse(feed_box)
	root_c.add_child(feed_box)
	banner_box = VBoxContainer.new()
	banner_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	banner_box.position = Vector2(0, 330)
	banner_box.custom_minimum_size = Vector2(560, 0)
	banner_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	ignore_mouse(banner_box)
	root_c.add_child(banner_box)
	pn_toast = PanelContainer.new()
	pn_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	pn_toast.position = Vector2(0, 88)
	pn_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	pn_toast.visible = false
	ignore_mouse(pn_toast)
	root_c.add_child(pn_toast)
	l_toast = mk_label("", 21, Color.WHITE)
	l_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l_toast.custom_minimum_size = Vector2(520, 0)
	l_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ignore_mouse(l_toast)
	pn_toast.add_child(l_toast)

	# ---- right side quick buttons
	side_box = VBoxContainer.new()
	side_box.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	side_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	side_box.grow_vertical = Control.GROW_DIRECTION_BOTH
	side_box.position = Vector2(-6, 0)
	root_c.add_child(side_box)
	var sdefs := [["hq", "HQ Shop"], ["view", "Combat"], ["ind", "Industry"], ["art", "Artillery"], ["smoke", "Smoke"], ["med", "Hospital"], ["help", "? Help"]]
	for sd in sdefs:
		var b := mk_button(sd[1], _on_side.bind(sd[0]), "", 86)
		b.custom_minimum_size = Vector2(98, 86)
		b.add_theme_font_size_override("font_size", 15)
		set_icon(b, sd[0], true, 34)
		side_box.add_child(b)
		side_btns[sd[0]] = b

	# ---- bottom stack
	bottom_box = VBoxContainer.new()
	bottom_box.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom_box.add_theme_constant_override("separation", 4)
	root_c.add_child(bottom_box)
	mode_box = HBoxContainer.new()
	mode_box.alignment = BoxContainer.ALIGNMENT_CENTER
	mode_box.add_child(mk_button("CANCEL", _on_cancel, "r", 56))
	btn_go = mk_button("GO", _on_go, "g", 56)
	mode_box.add_child(btn_go)
	for c in mode_box.get_children():
		c.custom_minimum_size = Vector2(170, 56)
	mode_box.visible = false
	bottom_box.add_child(mode_box)
	chips_sc = ScrollContainer.new()
	chips_sc.custom_minimum_size = Vector2(0, 64)
	chips_sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	chips_box = HBoxContainer.new()
	chips_sc.add_child(chips_box)
	bottom_box.add_child(chips_sc)
	pn_sel = PanelContainer.new()
	pn_sel.visible = false
	sel_box = VBoxContainer.new()
	pn_sel.add_child(sel_box)
	bottom_box.add_child(pn_sel)
	pn_sheet = PanelContainer.new()
	pn_sheet.visible = false
	sheet_sc = ScrollContainer.new()
	sheet_sc.custom_minimum_size = Vector2(0, 640)
	sheet_sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sheet_box = VBoxContainer.new()
	sheet_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sheet_sc.add_child(sheet_box)
	pn_sheet.add_child(sheet_sc)
	bottom_box.add_child(pn_sheet)
	tabbar = HBoxContainer.new()
	tabbar.add_theme_constant_override("separation", 2)
	for td in TABS:
		var tb := mk_button(td[1], _on_tab.bind(td[0]), "", 84)
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tb.add_theme_font_size_override("font_size", 15)
		set_icon(tb, td[0], true, 32)
		tb.add_theme_constant_override("h_separation", 0)
		tb.add_theme_stylebox_override("normal", sbox(Color.html("3a4a2a"), Color.html("8b6f33"), 2))
		tb.get_theme_stylebox("normal").content_margin_left = 2
		tb.get_theme_stylebox("normal").content_margin_right = 2
		tb.clip_text = true
		tabbar.add_child(tb)
		tab_btns[td[0]] = tb
	bottom_box.add_child(tabbar)

	# ---- overlay
	ov = ColorRect.new()
	ov.color = Color(0.03, 0.05, 0.03, 0.94)
	ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_c.add_child(ov)
	var sc := ScrollContainer.new()
	sc.set_anchors_preset(Control.PRESET_FULL_RECT)
	sc.offset_left = 40
	sc.offset_right = -40
	sc.offset_top = 60
	sc.offset_bottom = -60
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ov.add_child(sc)
	ov_box = VBoxContainer.new()
	ov_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ov_box.add_theme_constant_override("separation", 14)
	sc.add_child(ov_box)
	build_tut()
	blockers = [hud_pn, side_box, bottom_box]


func _on_pause() -> void:
	speed = 1 if speed == 0 else 0
	update_speed_buttons()


func _on_speed() -> void:
	speed = 2 if speed <= 1 else (3 if speed == 2 else 1)
	update_speed_buttons()


func update_speed_buttons() -> void:
	if btn_speed == null:
		return
	btn_speed.text = "x%d" % [1 if speed <= 1 else (2 if speed == 2 else 4)]
	btn_pause.text = ">" if speed == 0 else "II"


func _on_side(id: String) -> void:
	match id:
		"hq":
			set_tab("hq")
		"view":
			combat_view = not combat_view
			toast("Combat view: " + ("ON (air defense ranges)" if combat_view else "off"))
		"ind":
			set_tab("ind")
		"art":
			set_tab("map")
			if shell_n <= 0:
				toast("No artillery shells. Buy them at HQ.")
			else:
				mode = "art"
		"smoke":
			set_tab("map")
			if smoke_n <= 0:
				toast("No smoke canisters. Buy them at HQ.")
			else:
				mode = "smoke"
		"help":
			set_tab("help" if tab != "help" else "map")
		"med":
			set_tab("map")
			if med_n <= 0:
				toast("No field hospitals. Buy them at HQ.")
			else:
				mode = "med"


func _on_cancel() -> void:
	mode = ""
	place_type = ""
	route_pts.clear()


func _on_go() -> void:
	if mode == "route":
		commit_route()


func _on_tab(name: String) -> void:
	set_tab(name if tab != name or name == "map" else "map")


func set_tab(name: String) -> void:
	tab = name
	if mode != "" and mode != "place" and name != "map":
		mode = ""
	if mode == "place" and name != "map":
		mode = ""
		place_type = ""
	pn_sheet.visible = name != "map"
	for k in tab_btns:
		var b: Button = tab_btns[k]
		b.modulate = Color(1.0, 0.85, 0.5) if k == name else Color.WHITE
	sheet_sig = ""
	sel_sig = ""
	if name != "map":
		sheet_sc.scroll_vertical = 0
		render_sheet()


func refresh_panels() -> void:
	sel_sig = ""


# ====================================================================== sheet content
func aff_sig() -> String:
	var s := ""
	for k in D.BUY:
		s += "1" if can_pay(price(k)) else "0"
	for k in D.BUILD:
		s += "1" if can_pay(price(k)) else "0"
	return s


func make_sig() -> String:
	var tl := ""
	for tw in towns:
		tl += str(tw.side) + ("L" if tw.lit else "d")
	var gm := ""
	for g in groups:
		gm += g.mode[0] + ("1" if g.alive else "0")
	return "%s|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%s|%s|%s|%d" % [tab, ac.size(), trucks.size(), fleets.size(), mis, uav_stock,
		bl.size(), cases.size(), offers.size(), shell_n, smoke_n, med_n, aff_sig(), tl, gm, 1 if speed == 0 else 0]


func render_sheet() -> void:
	if tab == "map":
		return
	var sg := make_sig()
	if sg == sheet_sig:
		return
	sheet_sig = sg
	var keep := sheet_sc.scroll_vertical
	for c in sheet_box.get_children():
		sheet_box.remove_child(c)
		c.queue_free()
	dyn.clear()
	match tab:
		"cities":
			sheet_cities()
		"air":
			sheet_air()
		"ad":
			sheet_ad()
		"army":
			sheet_army()
		"pol":
			sheet_pol()
		"ind":
			sheet_ind()
		"hq":
			sheet_hq()
		"help":
			sheet_help()
	sheet_sc.scroll_vertical = keep
	update_dyn()


func sheet_title(s: String) -> void:
	sheet_box.add_child(mk_label(s, 28, COL.orange))


func sheet_section(s: String) -> void:
	sheet_box.add_child(mk_label(s.to_upper(), 18, COL.dim))


func item_card(title: String, price_text: String, desc: String, buttons: Array, icon_key: String = "") -> void:
	var v := VBoxContainer.new()
	var hr := HBoxContainer.new()
	var tl := mk_label(title, 23, COL.text)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hr.add_child(tl)
	if price_text != "":
		hr.add_child(mk_label(price_text, 20, COL.gold))
	v.add_child(hr)
	if desc != "":
		v.add_child(mk_wrap(desc, 18))
	if buttons.size() > 0:
		var br := HBoxContainer.new()
		for bd in buttons:
			var b := mk_button(bd[0], bd[1], bd[2] if bd.size() > 2 else "", 54)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if bd.size() > 3 and not bd[3]:
				b.disabled = true
			br.add_child(b)
		v.add_child(br)
	if icon_key != "":
		var row := HBoxContainer.new()
		var ir_ := mk_icon_rect(icon_key, 72.0)
		row.add_child(ir_)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(v)
		sheet_box.add_child(mk_panel(row))
	else:
		sheet_box.add_child(mk_panel(v))


func buy_card(k: String) -> void:
	var p := price(k)
	var d: Dictionary = D.BUY[k]
	var desc: String = BUY_DESC.get(k, "")
	if D.ACTYPES.has(k):
		desc = String(D.ACTYPES[k].desc)
	item_card(d.name, money(p), desc, [["BUY", _on_buy.bind(k), "g", can_pay(p)]], k)


func build_card(k: String) -> void:
	var p := price(k)
	var d: Dictionary = D.BUILD[k]
	item_card(d.name, money(p), String(d.desc) + "  (%d s)" % int(d.t), [["BUILD", _on_place.bind(k), "g", can_pay(p)]], k)


func _on_buy(k: String) -> void:
	if started and over == "":
		buy(k)
		sheet_sig = ""
		render_sheet()


func _on_place(k: String) -> void:
	if not started or over != "":
		return
	var p := price(k)
	if not can_pay(p):
		toast("Not enough resources")
		return
	mode = "place"
	place_type = k
	place_pos = s2w(Vector2(vw / 2.0, vh * 0.42))
	set_tab("map")
	toast("Tap a free spot on your land to build")


func sheet_cities() -> void:
	sheet_title("Cities and power")
	var l := mk_label("", 21, Color.html("ffe08a"))
	sheet_box.add_child(l)
	add_dyn(l, func(): return "Power: %.1f produced, %.1f needed. Dark cities: %d. Income %.2f/s" % [supply, demand, dark_n, income])
	var lst: Array = towns.duplicate()
	lst.sort_custom(func(a, b): return a.side < b.side)
	for tw in lst:
		var v := HBoxContainer.new()
		var col: Color = Color.html("9cc2ff") if tw.side == 0 else Color.html("ffb3a8")
		var nm: String = tw.name + ("  (capital)" if tw.cap else "")
		var t1 := mk_label(nm, 21, col)
		t1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(t1)
		var st := "Ours" if tw.side == 0 else "Enemy"
		if tw.side == 0:
			st += "  lights on" if tw.lit else "  DARK"
		v.add_child(mk_label("%s  pop %d" % [st, tw.pop], 18, COL.dim))
		sheet_box.add_child(mk_panel(v))


func sheet_air() -> void:
	sheet_title("Aviation")
	var g := GridContainer.new()
	g.columns = 3
	g.add_theme_constant_override("h_separation", 6)
	g.add_theme_constant_override("v_separation", 6)
	var defs := [
		["pause", "Pause" if speed != 0 else "Resume", ""],
		["uav", "Launch UAV\n(%d)" % uav_stock, ""],
		["route", "Route", ""],
		["recon", "Recon\n20", ""],
		["strike", "Strike", "o"],
		["uavfac", "UAV factory\n%s" % money(price("uavfac")), ""],
		["speed", "Speed", ""],
		["droneport", "Drone port\n%s" % money(price("droneport")), ""],
		["rocketfac", "Rocket fac.\n%s" % money(price("rocketfac")), ""],
		["truck", "Missile truck\n%s" % money(price("truck")), ""],
		["airfield", "Airfield\n%s" % money(price("airfield")), ""],
		["hq", "Buy aircraft", "g"],
	]
	for d in defs:
		var b := mk_button(d[1], _on_air.bind(d[0]), d[2], 100)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 16)
		set_icon(b, "buy" if d[0] == "hq" else ("pause" if d[0] == "pause" else d[0]), true, 40)
		g.add_child(b)
	sheet_box.add_child(g)
	sheet_section("Your aircraft")
	if ac.is_empty():
		sheet_box.add_child(mk_wrap("No aircraft. Buy one at HQ.", 20))
	for a in ac:
		var hr := HBoxContainer.new()
		hr.add_child(mk_icon_rect(a.type, 44.0))
		var tl := mk_label("", 20, COL.text)
		tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hr.add_child(tl)
		var aa: Dictionary = a
		add_dyn(tl, func(): return "No.%d %s Lv%d  %s  armor %d/%d  fuel %d%%" % [aa.n, D.ACTYPES[aa.type].short, aa.lvl, STNAME.get(aa.st, aa.st), ceili(aa.hp), aa.maxhp, int(aa.fuel)])
		var sb := mk_button("Select", _on_pick_ac.bind(a.id), "", 46)
		sb.custom_minimum_size = Vector2(110, 46)
		hr.add_child(sb)
		sheet_box.add_child(mk_panel(hr))
	sheet_section("Stock")
	sheet_box.add_child(mk_wrap("Ballistic missiles %d   UAVs %d/%d   Trucks %d/5   Fleets %d/3" % [mis, uav_stock, uav_cap(), trucks.size(), fleets.size()], 20, COL.text))


func _on_pick_ac(id: int) -> void:
	for a in ac:
		if a.id == id:
			set_tab("map")
			select(a)
			var sp := Vector2(a.x, a.y)
			cam = sp - Vector2(vw, vh) / zoom * 0.5
			clamp_cam()
			return


func _on_air(id: String) -> void:
	if not started or over != "":
		return
	match id:
		"pause":
			_on_pause()
			sheet_sig = ""
			render_sheet()
		"speed":
			_on_speed()
		"uav":
			if uav_stock <= 0:
				toast("No UAVs in stock. Buy one at HQ or build a UAV factory.")
				return
			if nearest_dp(0.0, 0.0) == null:
				toast("Build a drone port first")
				return
			set_tab("map")
			mode = "uav"
		"recon":
			if nearest_dp(0.0, 0.0) == null:
				toast("Build a drone port first")
				return
			set_tab("map")
			mode = "recon"
		"strike":
			set_tab("map")
			mode = "strike"
		"route":
			if sel == null or sel.k != "ac":
				toast("Select an aircraft first (tap it on the map)")
				set_tab("map")
				return
			if sel.type == "ftr" or true:
				set_tab("map")
				route_pts.clear()
				mode = "route"
		"uavfac", "droneport", "rocketfac", "airfield":
			_on_place(id)
		"truck":
			_on_buy("truck")
		"hq":
			set_tab("hq")


func sheet_ad() -> void:
	sheet_title("Air defense")
	var ns := 0
	var nl := 0
	for b in bl:
		if b.alive and b.prog >= 1.0:
			if b.type == "sam":
				ns += 1
			elif b.type == "lsam":
				nl += 1
	sheet_box.add_child(mk_wrap("Shield SAM: %d   Long range SAM: %d   Ballistic missiles in stock: %d" % [ns, nl, mis], 20, COL.text))
	sheet_box.add_child(mk_wrap("Shield SAMs stop drones and aircraft. Long range SAMs also shoot ballistic and cruise missiles. Use Combat view to see ranges.", 18))
	build_card("sam")
	build_card("lsam")
	item_card("Combat view", "", "Show or hide the air defense range circles on the map.", [["TOGGLE", _on_side.bind("view"), "o"]], "view")


func sheet_army() -> void:
	sheet_title("Army")
	sheet_box.add_child(mk_wrap("Tap a group on the map or use these buttons. Attack groups push the front, defend groups hold it.", 18))
	for g in groups:
		var gg: Dictionary = g
		var v := VBoxContainer.new()
		var hr := HBoxContainer.new()
		var tl := mk_label("Group %d" % g.n, 22, COL.text)
		tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hr.add_child(tl)
		var st := mk_label("", 20, COL.dim)
		hr.add_child(st)
		add_dyn(st, func(): return ("ATTACK" if gg.mode == "attack" else "DEFEND") + ("  fighting" if gg.fight > 0.0 else "") + ("" if gg.alive else "  DESTROYED"))
		v.add_child(hr)
		var pb := ProgressBar.new()
		pb.max_value = 100.0
		pb.show_percentage = false
		pb.custom_minimum_size = Vector2(0, 14)
		add_dyn(pb, func(): return gg.str)
		v.add_child(pb)
		var btn := mk_button("Switch to %s" % ("DEFEND" if g.mode == "attack" else "ATTACK"), _on_group.bind(g.n), "", 50)
		v.add_child(btn)
		sheet_box.add_child(mk_panel(v))
	sheet_section("Support (tap to use on the map)")
	item_card("Artillery", "%d shells" % shell_n, "Barrage on a point near the front.", [["USE", _on_side.bind("art"), "o"], ["+10 shells", _on_buy.bind("shell"), "", can_pay(price("shell"))]], "shell")
	item_card("Smoke screen", "%d" % smoke_n, "Protects our group from fire for 45 seconds.", [["USE", _on_side.bind("smoke"), "o"], ["+2 smoke", _on_buy.bind("smoke"), "", can_pay(price("smoke"))]], "smoke")
	item_card("Field hospital", "%d" % med_n, "Heals an army group.", [["USE", _on_side.bind("med"), "o"], ["+2 hospitals", _on_buy.bind("med"), "", can_pay(price("med"))]], "med")
	buy_card("brig")


func _on_group(n: int) -> void:
	for g in groups:
		if g.n == n:
			g.mode = "defend" if g.mode == "attack" else "attack"
	sheet_sig = ""
	render_sheet()


func sheet_pol() -> void:
	sheet_title("Politics")
	if cases.is_empty() and offers.is_empty():
		sheet_box.add_child(mk_wrap("No diplomatic cases. Do not sink neutral ships (yellow flag).", 20))
	for i in range(cases.size()):
		build_case_card(i)
	for i in range(offers.size()):
		build_offer_card(i)
	sheet_section("Nations")
	for n in nat:
		var nn: Dictionary = n
		var hr := HBoxContainer.new()
		var tl := mk_label(String(n.name), 21, n.c1)
		tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hr.add_child(tl)
		var st := mk_label("", 19, COL.dim)
		add_dyn(st, func(): return "AT WAR" if nn.war else ("mood %d  incidents %d" % [int(nn.mood), nn.inc]))
		hr.add_child(st)
		sheet_box.add_child(mk_panel(hr))


func build_case_card(i: int) -> void:
	var c: Dictionary = cases[i]
	var v := VBoxContainer.new()
	var hr := HBoxContainer.new()
	var tl := mk_label("%s: %s" % [D.STAGES[c.stage], c.n.name], 23, c.n.c1)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hr.add_child(tl)
	var tm := mk_label("", 22, Color.html("ffd27a"))
	hr.add_child(tm)
	add_dyn(tm, func(): return tstr(cases[i].t) if i < cases.size() else "")
	v.add_child(hr)
	v.add_child(mk_wrap("Stop sinking our ships. Incidents: %d" % c.n.inc, 19))
	var tb := ProgressBar.new()
	tb.max_value = 100.0
	tb.custom_minimum_size = Vector2(0, 12)
	tb.show_percentage = false
	tb.add_theme_stylebox_override("fill", sbox(Color.html("f0b429"), Color.html("f0b429"), 0))
	add_dyn(tb, func(): return 100.0 * cases[i].t / cases[i].tm if i < cases.size() else 0.0)
	v.add_child(tb)
	var br := HBoxContainer.new()
	for b in [["Stop", "stop", "g", true], ["Pay 120", "pay", "", coins >= 120.0], ["Refuse", "refuse", "r", true]]:
		var btn := mk_button(b[0], _on_case.bind(i, b[1]), b[2], 54)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.disabled = not b[3]
		br.add_child(btn)
	v.add_child(br)
	var p := mk_panel(v)
	p.add_theme_stylebox_override("panel", sbox(Color(0.1, 0.07, 0.04, 0.95), Color.html("c0392b") if c.stage >= 2 else Color.html("8a5a22"), 3))
	sheet_box.add_child(p)


func build_offer_card(i: int) -> void:
	var o: Dictionary = offers[i]
	var v := VBoxContainer.new()
	var hr := HBoxContainer.new()
	var tl := mk_label("%s: %s" % ["Trade request" if o.kind == "sell" else "Trade treaty", o.n.name], 23, o.n.c1)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hr.add_child(tl)
	var tm := mk_label("", 22, Color.html("ffd27a"))
	hr.add_child(tm)
	add_dyn(tm, func(): return tstr(offers[i].t) if i < offers.size() else "")
	v.add_child(hr)
	var txt := "Buys %s x%d for %d coins" % [o.res, o.q, o.coins] if o.kind == "sell" else "Purchases cost 10% less for 2:30"
	v.add_child(mk_wrap(txt, 19))
	var br := HBoxContainer.new()
	var b1 := mk_button("Accept", _on_offer.bind(i, "ok"), "g", 54)
	var b2 := mk_button("Decline", _on_offer.bind(i, "no"), "r", 54)
	b1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	br.add_child(b1)
	br.add_child(b2)
	v.add_child(br)
	var p := mk_panel(v)
	p.add_theme_stylebox_override("panel", sbox(Color(0.07, 0.09, 0.06, 0.95), Color.html("8a5a22"), 3))
	sheet_box.add_child(p)


func _on_case(i: int, act: String) -> void:
	case_act(i, act)
	sheet_sig = ""
	render_sheet()


func _on_offer(i: int, act: String) -> void:
	offer_act(i, act)
	sheet_sig = ""
	render_sheet()


func sheet_ind() -> void:
	sheet_title("Industry")
	var l := mk_label("", 20, COL.text)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(300, 0)
	sheet_box.add_child(l)
	add_dyn(l, func(): return "Oil +%.2f/s   Metal +%.2f/s   Storage limit %d\nPower %.1f / %.1f   Income %.2f/s" % [oil_rate, metal_rate, int(stock_cap), supply, demand, income])
	for k in ["derrick", "mine", "warehouse", "plant", "solar", "port"]:
		build_card(k)
	buy_card("fleet")


func sheet_hq() -> void:
	sheet_title("HQ shop")
	sheet_section("Aircraft")
	for k in ["atk", "ftr", "bmb"]:
		buy_card(k)
	sheet_section("Missiles and drones")
	for k in ["truck", "msl", "uav"]:
		buy_card(k)
	sheet_section("Navy")
	buy_card("fleet")
	sheet_section("Army")
	for k in ["brig", "shell", "smoke", "med"]:
		buy_card(k)


# ====================================================================== selection panel, chips, feed
func ac_info(a: Dictionary) -> String:
	return "No.%d %s Lv%d  %s\nArmor %d/%d   Fuel %d%%\nBombs %d  Rockets %d  Air-air %d  Cruise %d%s" % [
		a.n, D.ACTYPES[a.type].name, a.lvl, STNAME.get(a.st, a.st), ceili(a.hp), a.maxhp, int(a.fuel),
		a.gb, a.rk, a.aa, a.cm, "  Hypersonic 1" if a.hyper > 0 else ""]


func build_sel() -> void:
	for c in sel_box.get_children():
		sel_box.remove_child(c)
		c.queue_free()
	if sel == null or tab != "map":
		pn_sel.visible = false
		return
	pn_sel.visible = true
	var s = sel
	var info := mk_label("", 19, COL.text)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size = Vector2(300, 0)
	sel_box.add_child(info)
	var br := HBoxContainer.new()
	var close := mk_button("X", func(): select(null), "", 50)
	close.custom_minimum_size = Vector2(56, 50)
	if s.k == "ac":
		var a: Dictionary = s
		add_dyn(info, func(): return ac_info(a))
		var b1 := mk_button("LAND", func(): give_order(a, {"t": "rtb"}), "", 50)
		br.add_child(b1)
		if a.type != "ftr":
			br.add_child(mk_button("STRIKE", func(): mode = "strike", "o", 50))
		br.add_child(mk_button("ROUTE", func(): route_pts.clear(); mode = "route", "", 50))
		var uc := upgrade_cost(a)
		if uc > 0:
			var ub := mk_button("UPGRADE %d" % uc, func(): upgrade_aircraft(a), "g", 50)
			ub.disabled = coins < uc
			br.add_child(ub)
		if a.type == "ftr":
			if a.hyper > 0:
				br.add_child(mk_button("HYPERSONIC", func(): mode = "hyper", "o", 50))
			else:
				var hb := mk_button("HYPER " + money(D.HYPER_COST), func(): buy_hyper(a), "g", 50)
				hb.disabled = not can_pay(D.HYPER_COST)
				br.add_child(hb)
	elif s.k == "truck":
		var tr: Dictionary = s
		add_dyn(info, func(): return "Missile truck T%d  %s\nArmor %d/%d   Missiles in stock: %d\nTap the enemy side to fire (range %d). Tap your side to move." % [tr.n, String(tr.st).to_upper(), ceili(tr.hp), int(tr.maxhp), mis, int(TRUCK_RANGE)])
	elif s.k == "fleet":
		var f: Dictionary = s
		add_dyn(info, func(): return "Fleet %d: %d ships   naval missiles %d\nTap the sea to move. Tap an enemy ship to attack, or a coastal target for a cruise strike." % [f.n, f.ships, f.mis])
	elif s.k == "msl" or s.has("kind"):
		var m: Dictionary = s
		add_dyn(info, func(): return "%s missile   Altitude %.1f km   Speed Mach %.1f" % ["Ballistic" if m.kind == "bal" else "Cruise", msl_alt_km(m), msl_mach(m)])
	br.add_child(close)
	for c in br.get_children():
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sel_box.add_child(br)
	update_dyn()


func build_chips() -> void:
	for c in chips_box.get_children():
		chips_box.remove_child(c)
		c.queue_free()
	for a in ac:
		var aid: int = a.id
		var letter: String = {"atk": "A", "ftr": "F", "bmb": "B"}[a.type]
		var b := mk_button("%s%d" % [letter, a.n], _on_pick_ac.bind(aid), "", 54)
		b.custom_minimum_size = Vector2(104, 54)
		set_icon(b, a.type, false, 30)
		if sel != null and is_same(sel, a):
			b.modulate = Color(1.0, 0.8, 0.4)
		elif a.st == "parked" or a.st == "rearm":
			b.modulate = Color(0.7, 0.8, 0.7)
		chips_box.add_child(b)
	for tr in trucks:
		var tt: Dictionary = tr
		var b2 := mk_button("T%d" % tr.n, func(): select(tt), "", 54)
		b2.custom_minimum_size = Vector2(104, 54)
		set_icon(b2, "truck", false, 30)
		if sel != null and is_same(sel, tr):
			b2.modulate = Color(1.0, 0.8, 0.4)
		chips_box.add_child(b2)
	for fl in fleets:
		var ff: Dictionary = fl
		var b3 := mk_button("S%d" % fl.n, func(): select(ff), "", 54)
		b3.custom_minimum_size = Vector2(104, 54)
		set_icon(b3, "fleet", false, 30)
		if sel != null and is_same(sel, fl):
			b3.modulate = Color(1.0, 0.8, 0.4)
		chips_box.add_child(b3)


func refresh_feed() -> void:
	for c in feed_box.get_children():
		feed_box.remove_child(c)
		c.queue_free()
	var n := 0
	for f in feed:
		if f.life <= 0.0:
			continue
		var col: Color = COL.text
		if f.k == "good":
			col = Color.html("9de37a")
		elif f.k == "bad":
			col = Color.html("ff8a7a")
		var l := mk_label(f.m, 17, col)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(420, 0)
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		l.add_theme_constant_override("outline_size", 6)
		l.modulate.a = clampf(f.life / 2.0, 0.0, 1.0)
		ignore_mouse(l)
		feed_box.add_child(l)
		n += 1
		if n >= 4:
			break
	for c in banner_box.get_children():
		banner_box.remove_child(c)
		c.queue_free()
	for b in banners:
		if b.life <= 0.0:
			continue
		var col2 := Color.html("f0b429")
		var bg := Color(0.12, 0.09, 0.03, 0.92)
		if b.k == "war" or b.k == "lost":
			col2 = Color.html("ff5a4d")
			bg = Color(0.16, 0.05, 0.04, 0.92)
		elif b.k == "city" or b.k == "good":
			col2 = Color.html("86d963")
			bg = Color(0.05, 0.13, 0.05, 0.92)
		var v := VBoxContainer.new()
		var t1 := mk_label(b.m, 30, col2)
		t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(t1)
		if b.s != "":
			var t2 := mk_label(b.s, 18, COL.text)
			t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			v.add_child(t2)
		var pn := mk_panel(v)
		pn.add_theme_stylebox_override("panel", sbox(bg, col2, 3))
		ignore_mouse(pn)
		banner_box.add_child(pn)


func update_hud() -> void:
	l_coin.text = "$ %d" % int(coins)
	l_oil.text = "Oil %d" % int(oil)
	l_metal.text = "Metal %d" % int(metal)
	l_time.text = ("PEACE " + tstr(grace)) if grace > 0.0 else tstr(t)
	l_time.add_theme_color_override("font_color", Color.html("86d963") if grace > 0.0 else COL.dim)
	l_score.text = "Score %d / %d" % [int(score), int(D.GOAL)]
	pb_score.value = minf(score, D.GOAL)
	l_pow.text = "Power %.1f/%.1f" % [supply, demand]
	l_pow.add_theme_color_override("font_color", Color.html("ff6a5a") if demand > supply + 0.01 else Color.html("ffe08a"))
	for k in ["art", "smoke", "med"]:
		var b: Button = side_btns[k]
		var cnt := shell_n if k == "art" else (smoke_n if k == "smoke" else med_n)
		b.text = ("Artillery\n%d" if k == "art" else ("Smoke\n%d" if k == "smoke" else "Hospital\n%d")) % cnt
	(side_btns["view"] as Button).modulate = Color(1, 0.85, 0.5) if combat_view else Color.WHITE
	mode_box.visible = mode != ""
	btn_go.visible = mode == "route"


# ====================================================================== frame loop
func _process(delta: float) -> void:
	if terr_tex == null:
		return
	if started and over == "":
		var mult: float = [0.0, 1.0, 2.0, 4.0][clampi(speed, 0, 3)]
		var dt := minf(delta, 0.1) * mult
		var n := maxi(1, ceili(dt / 0.04))
		for i in range(n):
			step(dt / n)
	if toast_t > 0.0:
		toast_t -= delta
		if toast_t <= 0.0:
			pn_toast.visible = false
	for f in feed:
		f.life -= delta
	for b in banners:
		b.life -= delta
	hud_tick -= delta
	if hud_tick <= 0.0:
		hud_tick = 0.2
		update_hud()
		upd_tut()
		var fs := ""
		for f in feed:
			if f.life > 0.0:
				fs += f.m
		for b in banners:
			if b.life > 0.0:
				fs += b.m
		if fs != feed_sig or feed_dirty:
			feed_sig = fs
			feed_dirty = false
			refresh_feed()
		if sel != null:
			var gone: bool = bool(sel.get("dead", false)) or bool(sel.get("done", false))
			if gone:
				select(null)
		var cs := "%d|%s" % [-1 if sel == null else int(sel.get("id", -2)), ""]
		for a in ac:
			cs += "%d%s," % [a.id, a.st if (a.st == "parked" or a.st == "rearm") else "x"]
		cs += str(trucks.size()) + str(fleets.size())
		if cs != chips_sig or chips_dirty:
			chips_sig = cs
			chips_dirty = false
			build_chips()
		var ss := "%d|%s|%s|%d" % [-1 if sel == null else int(sel.get("id", -2)), tab, str(sel.get("st", "")) if sel != null else "", int(coins / 20.0)]
		if sel != null and sel.k == "ac":
			ss += "%d%d" % [sel.lvl, sel.hyper]
		if ss != sel_sig:
			sel_sig = ss
			build_sel()
		render_sheet()
		update_dyn()
	update_cam_keys(delta)
	queue_redraw()


func update_cam_keys(delta: float) -> void:
	if use_touch or not started:
		return
	var v := Vector2.ZERO
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
		v.x -= 1
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		v.x += 1
	if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W):
		v.y -= 1
	if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
		v.y += 1
	if v != Vector2.ZERO:
		cam += v * 400.0 * delta / zoom
		clamp_cam()


# ====================================================================== start and end screens
func show_overlay() -> void:
	for c in ov_box.get_children():
		ov_box.remove_child(c)
		c.queue_free()
	ov.visible = true
	if not started:
		var tt := mk_label(D.INTRO_TITLE, 52, COL.orange)
		tt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ov_box.add_child(tt)
		ov_box.add_child(mk_wrap(D.INTRO_SUB, 22, COL.dim))
		for line in D.INTRO:
			ov_box.add_child(mk_wrap("> " + String(line), 21, COL.text))
		var go := mk_button("START MISSION", _on_start, "g", 90)
		go.add_theme_font_size_override("font_size", 32)
		ov_box.add_child(go)
	else:
		var lose := over == "lose"
		var head := "Defeat" if lose else "Victory"
		ov_box.add_child(mk_label(head, 52, COL.red if lose else COL.orange))
		var sub := "Azuria City has fallen."
		if over == "win":
			sub = "Karmin City has fallen."
		elif over == "score":
			sub = "You reached %d points: Azuria is the world leader." % int(D.GOAL)
		ov_box.add_child(mk_wrap(sub, 24, COL.dim))
		ov_box.add_child(mk_label("Time: %s\nScore: %d\nTargets destroyed: %d\nAircraft lost: %d\nCities captured: %d" % [tstr(t), int(score), kills, lost, cities_taken], 24))
		ov_box.add_child(standings())
		var again := mk_button("PLAY AGAIN", _on_again, "g", 90)
		ov_box.add_child(again)


func _on_start() -> void:
	started = true
	ov.visible = false
	update_speed_buttons()
	toast("Tap an aircraft, then tap an enemy marker")


func _on_again() -> void:
	started = true
	new_game()
	ov.visible = false
	sheet_sig = ""
	sel_sig = ""
	chips_dirty = true
	feed_dirty = true
	update_speed_buttons()
	update_hud()


func standings() -> Control:
	var covered := 0.0
	for i in range(NB):
		covered += F[i]
	var lo := pcap.x + 30.0
	var hi := ecap.x - 30.0
	var prog := clampf((covered / NB - lo) / (hi - lo), 0.0, 1.0)
	var rows: Array = []
	rows.append({"n": "Azuria (you)", "t": int(score), "me": true})
	rows.append({"n": "Karmin", "t": 3500 + int((1.0 - prog) * 6500.0), "me": false})
	for n in nat:
		rows.append({"n": n.name, "t": 2200 + int(n.mood * 18.0) + (900 if n.war else 0), "me": false})
	rows.sort_custom(func(a, b): return a.t > b.t)
	var g := GridContainer.new()
	g.columns = 3
	g.add_theme_constant_override("h_separation", 24)
	for h in ["#", "Country", "Score"]:
		g.add_child(mk_label(h, 20, COL.dim))
	var i := 1
	for r in rows:
		var col: Color = COL.orange if r.me else COL.text
		g.add_child(mk_label(str(i), 22, col))
		g.add_child(mk_label(r.n, 22, col))
		g.add_child(mk_label(str(r.t), 22, col))
		i += 1
	return g


# ====================================================================== pixel icons for menus
var icon_cache := {}


func ir(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			if xx >= 0 and yy >= 0 and xx < 24 and yy < 24:
				img.set_pixel(xx, yy, c)


func ic_line(img: Image, x0: int, y0: int, x1: int, y1: int, c: Color) -> void:
	var n := maxi(absi(x1 - x0), absi(y1 - y0))
	for i in range(n + 1):
		var u := float(i) / maxf(1.0, n)
		ir(img, int(round(lerpf(x0, x1, u))), int(round(lerpf(y0, y1, u))), 1, 1, c)


func ic_disc(img: Image, cx: int, cy: int, r: int, c: Color) -> void:
	for yy in range(cy - r, cy + r + 1):
		for xx in range(cx - r, cx + r + 1):
			if (xx - cx) * (xx - cx) + (yy - cy) * (yy - cy) <= r * r + 1:
				ir(img, xx, yy, 1, 1, c)


func ic_plane(img: Image, shape: Array, pal: Dictionary) -> void:
	for y in range(shape.size()):
		var row: String = shape[y]
		for x in range(row.length()):
			var ch := row[x]
			if ch != ".":
				ir(img, 1 + x * 2, 1 + y * 2, 2, 2, Color.html(pal[ch]))


func icon(key: String) -> ImageTexture:
	if icon_cache.has(key):
		return icon_cache[key]
	var img := Image.create(24, 24, false, Image.FORMAT_RGBA8)
	var gold := Color.html("f0c660")
	var steel := Color.html("aab5c2")
	var dark := Color.html("2c3440")
	var red := Color.html("e5483f")
	var blue := Color.html("4d93ff")
	var green := Color.html("86d963")
	var white := Color.html("efe6c8")
	var brown := Color.html("8d6a3c")
	var orange := Color.html("ff8a2a")
	match key:
		"atk":
			ic_plane(img, D.PLANE_ATK, D.PAL_PLAYER)
		"ftr":
			ic_plane(img, D.PLANE_FTR, D.PAL_PLAYER)
		"bmb":
			ic_plane(img, D.PLANE_BMB, D.PAL_PLAYER)
		"truck":
			ir(img, 2, 12, 15, 6, Color.html("5d6b4a"))
			ir(img, 17, 13, 5, 5, Color.html("7d8f66"))
			ir(img, 19, 14, 2, 2, blue)
			ir(img, 3, 9, 12, 3, white)
			ir(img, 1, 9, 2, 3, red)
			ir(img, 4, 18, 4, 3, Color.BLACK)
			ir(img, 11, 18, 4, 3, Color.BLACK)
			ir(img, 18, 18, 4, 3, Color.BLACK)
		"msl":
			ic_line(img, 5, 19, 17, 7, white)
			ic_line(img, 6, 19, 18, 7, white)
			ic_line(img, 5, 18, 17, 6, steel)
			ic_disc(img, 19, 5, 2, red)
			ic_disc(img, 3, 21, 2, orange)
			ic_disc(img, 2, 22, 1, gold)
		"uav":
			ir(img, 10, 4, 4, 15, Color.html("3a3f44"))
			ir(img, 2, 12, 20, 3, Color.html("4a5057"))
			ir(img, 6, 17, 12, 2, Color.html("4a5057"))
			ir(img, 11, 2, 2, 3, red)
			ir(img, 11, 19, 2, 3, orange)
		"fleet":
			ir(img, 2, 14, 20, 5, Color.html("6c7a8a"))
			ir(img, 1, 14, 2, 3, Color.html("6c7a8a"))
			ir(img, 8, 9, 8, 5, Color.html("a9b6c4"))
			ir(img, 10, 5, 2, 4, steel)
			ir(img, 18, 11, 3, 3, dark)
			ir(img, 0, 20, 24, 3, blue)
			ir(img, 3, 21, 4, 1, white)
		"brig":
			ic_disc(img, 12, 6, 3, Color.html("c9a37a"))
			ir(img, 8, 9, 8, 8, Color.html("5d6b4a"))
			ir(img, 8, 17, 3, 5, dark)
			ir(img, 13, 17, 3, 5, dark)
			ir(img, 18, 8, 2, 12, brown)
			ir(img, 17, 6, 4, 3, steel)
			ir(img, 6, 3, 12, 2, Color.html("3a4a2a"))
		"smoke":
			ic_disc(img, 8, 15, 5, Color.html("c9ced4"))
			ic_disc(img, 15, 13, 6, Color.html("dde1e6"))
			ic_disc(img, 12, 8, 4, Color.html("eef0f2"))
			ir(img, 3, 20, 18, 2, steel)
		"shell":
			ir(img, 9, 8, 6, 12, gold)
			ir(img, 10, 4, 4, 4, Color.html("c75d43"))
			ir(img, 11, 2, 2, 2, Color.html("c75d43"))
			ir(img, 8, 19, 8, 3, brown)
			ir(img, 9, 12, 6, 1, brown)
		"med":
			ir(img, 3, 3, 18, 18, white)
			ir(img, 10, 6, 4, 12, red)
			ir(img, 6, 10, 12, 4, red)
		"airfield":
			ir(img, 1, 11, 22, 6, Color.html("4f545a"))
			for i in range(3):
				ir(img, 3 + i * 7, 13, 4, 1, white)
			ir(img, 2, 4, 6, 4, Color.html("59708f"))
			ir(img, 10, 4, 6, 4, Color.html("59708f"))
			ir(img, 19, 3, 2, 8, dark)
			ir(img, 17, 2, 6, 3, steel)
		"droneport":
			ir(img, 3, 12, 18, 8, Color.html("59708f"))
			ir(img, 9, 8, 6, 4, steel)
			ir(img, 11, 3, 2, 5, steel)
			ir(img, 8, 15, 8, 5, dark)
		"uavfac":
			ir(img, 2, 10, 20, 11, Color.html("6a7a8d"))
			ir(img, 4, 5, 5, 5, dark)
			ir(img, 14, 14, 6, 3, steel)
			ir(img, 5, 14, 5, 7, dark)
		"rocketfac":
			ir(img, 2, 14, 20, 8, Color.html("6a7a8d"))
			ir(img, 10, 3, 4, 12, white)
			ir(img, 11, 1, 2, 2, red)
			ir(img, 9, 12, 6, 3, red)
		"plant":
			ir(img, 2, 15, 20, 7, Color.html("6e7f99"))
			ic_line(img, 4, 14, 6, 4, Color.html("c8c4bc"))
			ic_line(img, 11, 14, 9, 4, Color.html("c8c4bc"))
			ir(img, 5, 5, 6, 10, Color.html("c8c4bc"))
			ir(img, 12, 5, 6, 10, Color.html("c8c4bc"))
			ir(img, 6, 1, 3, 3, Color.html("e8e8ea"))
		"solar":
			for i in range(3):
				for j in range(2):
					ir(img, 2 + i * 7, 5 + j * 8, 6, 6, Color.html("1f3a6b"))
					ir(img, 2 + i * 7, 5 + j * 8, 6, 1, Color.html("6a8fd0"))
			ic_disc(img, 20, 3, 2, gold)
		"derrick":
			ic_line(img, 6, 21, 12, 5, steel)
			ic_line(img, 18, 21, 12, 5, steel)
			ir(img, 10, 2, 4, 3, steel)
			ir(img, 3, 20, 18, 3, dark)
			ir(img, 11, 12, 2, 8, Color.html("c75d43"))
			ic_disc(img, 12, 20, 2, Color.BLACK)
		"mine":
			ir(img, 2, 12, 20, 10, Color.html("7a746d"))
			ir(img, 6, 15, 12, 7, dark)
			ir(img, 3, 8, 18, 4, Color.html("5a544e"))
			ic_line(img, 8, 2, 16, 8, Color.html("c9ced4"))
			ic_line(img, 16, 2, 8, 8, Color.html("c9ced4"))
		"warehouse":
			ir(img, 2, 8, 20, 13, Color.html("8d8470"))
			ir(img, 2, 6, 20, 3, Color.html("6d6454"))
			ir(img, 7, 12, 10, 9, Color.html("5b4a30"))
			ir(img, 8, 14, 8, 1, brown)
			ir(img, 8, 17, 8, 1, brown)
		"sam":
			ir(img, 3, 17, 18, 5, Color.html("5f6f8a"))
			ic_line(img, 6, 17, 4, 5, white)
			ic_line(img, 12, 17, 12, 3, white)
			ic_line(img, 18, 17, 20, 5, white)
			ic_disc(img, 4, 5, 2, red)
			ic_disc(img, 12, 3, 2, red)
			ic_disc(img, 20, 5, 2, red)
		"lsam":
			ir(img, 2, 18, 20, 4, Color.html("5f6f8a"))
			for i in range(4):
				ic_line(img, 4 + i * 5, 18, 8 + i * 4, 3, white)
				ir(img, 8 + i * 4 - 1, 2, 3, 3, red)
		"port":
			ir(img, 0, 18, 24, 5, blue)
			ir(img, 2, 12, 14, 6, Color.html("7b6a52"))
			ir(img, 16, 14, 6, 4, brown)
			ir(img, 5, 3, 2, 9, dark)
			ir(img, 5, 3, 9, 2, dark)
			ir(img, 12, 5, 2, 5, steel)
		# ---- tabs and actions
		"map":
			ir(img, 2, 4, 20, 16, Color.html("5a8f4a"))
			ir(img, 14, 4, 8, 16, Color.html("a8503e"))
			ic_line(img, 13, 4, 13, 20, Color.BLACK)
			ir(img, 4, 8, 6, 4, blue)
		"cities":
			ir(img, 2, 12, 6, 10, Color.html("7a9bd0"))
			ir(img, 9, 5, 7, 17, Color.html("8a8f96"))
			ir(img, 17, 10, 6, 12, Color.html("7a9bd0"))
			for yy in range(7, 20, 4):
				ir(img, 11, yy, 2, 2, gold)
				ir(img, 3, yy + 4 if yy < 15 else 20, 2, 2, gold)
		"air":
			ic_plane(img, D.PLANE_ATK, D.PAL_PLAYER)
		"ad":
			ir(img, 6, 3, 12, 11, Color.html("3b6fd0"))
			ir(img, 8, 14, 8, 3, Color.html("3b6fd0"))
			ir(img, 10, 17, 4, 3, Color.html("3b6fd0"))
			ir(img, 8, 5, 8, 8, Color.html("6aa0f0"))
			ir(img, 11, 6, 2, 6, white)
		"army":
			ic_disc(img, 8, 7, 3, Color.html("c9a37a"))
			ir(img, 5, 10, 6, 9, Color.html("5d6b4a"))
			ic_disc(img, 17, 8, 3, Color.html("c9a37a"))
			ir(img, 14, 11, 6, 9, Color.html("5d6b4a"))
			ir(img, 4, 4, 8, 2, Color.html("3a4a2a"))
			ir(img, 13, 5, 8, 2, Color.html("3a4a2a"))
		"pol":
			ic_disc(img, 12, 12, 9, blue)
			ic_disc(img, 12, 12, 7, Color.html("2f6b3f"))
			ir(img, 4, 11, 16, 2, blue)
			ir(img, 11, 3, 2, 18, blue)
			ir(img, 6, 6, 4, 3, Color.html("5aa04a"))
			ir(img, 14, 14, 4, 4, Color.html("5aa04a"))
		"ind":
			ir(img, 2, 12, 20, 10, Color.html("6a7a8d"))
			ir(img, 4, 4, 4, 9, Color.html("8a8f96"))
			ir(img, 10, 7, 4, 6, Color.html("8a8f96"))
			ir(img, 16, 9, 4, 4, Color.html("8a8f96"))
			ic_disc(img, 5, 3, 2, Color.html("d6d8da"))
			ir(img, 5, 15, 3, 3, gold)
			ir(img, 11, 15, 3, 3, gold)
			ir(img, 17, 15, 3, 3, gold)
		"hq":
			ir(img, 3, 9, 18, 12, Color.html("c75d43"))
			ir(img, 1, 6, 22, 4, Color.html("8a3a2a"))
			ir(img, 5, 12, 4, 5, white)
			ir(img, 15, 12, 4, 5, white)
			ir(img, 10, 14, 4, 7, brown)
			ic_disc(img, 12, 3, 2, gold)
		"view":
			ic_disc(img, 12, 12, 9, white)
			ic_disc(img, 12, 12, 6, blue)
			ic_disc(img, 12, 12, 3, Color.BLACK)
			ic_disc(img, 10, 10, 1, white)
		"art":
			ir(img, 2, 13, 14, 5, Color.html("4a5057"))
			ic_line(img, 6, 14, 20, 5, Color.html("6a7078"))
			ic_line(img, 6, 15, 20, 6, Color.html("6a7078"))
			ic_disc(img, 6, 20, 3, Color.BLACK)
			ic_disc(img, 21, 3, 2, orange)
		"help":
			ic_disc(img, 12, 12, 10, blue)
			ir(img, 9, 6, 6, 3, white)
			ir(img, 13, 8, 3, 4, white)
			ir(img, 11, 11, 3, 3, white)
			ir(img, 11, 16, 3, 3, white)
		"pause":
			ir(img, 6, 4, 4, 16, white)
			ir(img, 14, 4, 4, 16, white)
		"route":
			ic_line(img, 3, 20, 9, 8, orange)
			ic_line(img, 9, 8, 15, 16, orange)
			ic_line(img, 15, 16, 21, 4, orange)
			ic_disc(img, 3, 20, 2, green)
			ic_disc(img, 9, 8, 2, white)
			ic_disc(img, 15, 16, 2, white)
			ic_disc(img, 21, 4, 2, red)
		"recon":
			ic_disc(img, 12, 12, 9, green)
			ic_disc(img, 12, 12, 7, Color.html("0d130f"))
			ic_disc(img, 12, 12, 4, Color.html("2f6b2a"))
			ic_line(img, 12, 12, 19, 6, green)
			ic_disc(img, 15, 15, 1, red)
		"strike":
			ic_disc(img, 12, 12, 9, red)
			ic_disc(img, 12, 12, 7, Color.html("1a0a0a"))
			ic_disc(img, 12, 12, 4, red)
			ic_disc(img, 12, 12, 1, white)
			ir(img, 11, 0, 2, 5, red)
			ir(img, 11, 19, 2, 5, red)
			ir(img, 0, 11, 5, 2, red)
			ir(img, 19, 11, 5, 2, red)
		"speed":
			ic_line(img, 3, 5, 10, 12, white)
			ic_line(img, 3, 19, 10, 12, white)
			ic_line(img, 3, 4, 10, 11, white)
			ic_line(img, 3, 20, 10, 13, white)
			ic_line(img, 12, 5, 19, 12, gold)
			ic_line(img, 12, 19, 19, 12, gold)
			ic_line(img, 12, 4, 19, 11, gold)
			ic_line(img, 12, 20, 19, 13, gold)
		"buy":
			ic_plane(img, D.PLANE_FTR, D.PAL_PLAYER)
			ir(img, 16, 0, 8, 8, gold)
			ir(img, 19, 1, 2, 6, Color.BLACK)
		_:
			ic_disc(img, 12, 12, 8, gold)
	var big := Image.create(48, 48, false, Image.FORMAT_RGBA8)
	for y in range(48):
		for x in range(48):
			big.set_pixel(x, y, img.get_pixel(x / 2, y / 2))
	var tex := ImageTexture.create_from_image(big)
	icon_cache[key] = tex
	return tex


func set_icon(b: Button, key: String, top: bool = true, size: int = 36) -> void:
	var tex := icon(key)
	var im := tex.get_image()
	im.resize(size, size, Image.INTERPOLATE_NEAREST)
	b.icon = ImageTexture.create_from_image(im)
	if top:
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.expand_icon = false


func mk_icon_rect(key: String, size: float = 56.0) -> TextureRect:
	var r := TextureRect.new()
	r.texture = icon(key)
	r.custom_minimum_size = Vector2(size, size)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return r


# ====================================================================== peace time, missions, help
var grace := 240.0
var bl0 := 0
var tut_i := 0
var tut_flag := {}
var pn_tut: PanelContainer
var l_tut_h: Label
var l_tut_t: Label

const MISSIONS := [
	["Select a jet", "Tap one of the aircraft buttons at the bottom (A1, A2, A3) or tap a plane on the map.", "sel"],
	["Bomb a target", "With an aircraft selected, tap a red enemy marker on the map (I, S, D...). The jet takes off, bombs it and flies home.", "atk"],
	["Buy a missile truck", "Open HQ Shop (right side) and buy a Missile launcher truck. Missiles are fired from trucks, not from planes.", "truck"],
	["Fire a ballistic missile", "Tap the truck button (T1 or T2), then tap a far enemy marker. The truck drives, fires and hides.", "bal"],
	["Build something", "Open the Industry tab, press BUILD on a Power plant or Oil derrick, then tap a free spot on your side (blue).", "build"],
	["Launch a drone", "Open Aviation, press Recon, then tap the enemy side. Drones show hidden enemy trucks (red M).", "uav"],
	["Destroy 5 enemy targets", "Keep striking. Capture cities by pushing the front line with the Army tab and artillery.", "kills5"],
	["Free play", "Reach 15000 score or take Karmin City. Open the ? Help button any time.", ""],
]

const HELP_TEXT := [
	["GOAL", "Beat Karmin (red). Reach 15000 score, or push the front line until Karmin City falls. If the front reaches Azuria City you lose."],
	["FIRST 4 MINUTES", "Karmin does not attack yet (PEACE timer at the top). Use this time to follow the Mission box and build up."],
	["MOVE THE MAP", "Drag with one finger. Pinch with two fingers to zoom. Tap a unit to select it."],
	["PLANES", "Tap a plane, then tap an enemy marker to bomb it. Tap the ground to patrol there. Tap your airfield to land. Attackers and bombers bomb, fighters shoot planes and drones. Buy more at HQ Shop."],
	["MISSILE TRUCKS", "Buy a truck and missiles at HQ Shop. Tap the truck, then tap a far enemy marker. After firing it hides. Enemy trucks are hidden: send a Recon drone."],
	["BUILD", "Open Industry or Aviation, press BUILD, then tap a free place on your side. Derrick gives oil, mine gives metal, plants give power."],
	["POWER", "Cities need electricity. If power is too low, cities go dark and pay less. Build power plants or solar."],
	["ARMY", "The Army tab has 4 groups. ATTACK pushes the front, DEFEND holds it. Use artillery, smoke and hospital buttons on the right side."],
	["AIR DEFENSE", "Build Shield SAMs and Long range SAMs near your cities and airfields. Combat view shows their range."],
	["SHIPS AND POLITICS", "Yellow flag ships belong to neutral countries. Sinking them makes a diplomatic case in Politics. Accept trade offers to earn coins."],
]


func build_tut() -> void:
	pn_tut = PanelContainer.new()
	pn_tut.position = Vector2(10, 128)
	pn_tut.custom_minimum_size = Vector2(450, 0)
	pn_tut.add_theme_stylebox_override("panel", sbox(Color(0.1, 0.07, 0.02, 0.92), Color.html("e0a040"), 2))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	l_tut_h = mk_label("", 19, COL.orange)
	l_tut_t = mk_wrap("", 17, COL.text)
	l_tut_t.custom_minimum_size = Vector2(420, 0)
	v.add_child(l_tut_h)
	v.add_child(l_tut_t)
	pn_tut.add_child(v)
	ignore_mouse(pn_tut)
	ignore_mouse(v)
	ignore_mouse(l_tut_h)
	ignore_mouse(l_tut_t)
	root_c.add_child(pn_tut)


func reset_tut() -> void:
	tut_i = 0
	tut_flag = {}
	grace = 240.0
	bl0 = bl.size()


func upd_tut() -> void:
	if pn_tut == null:
		return
	if not tut_flag.get("sel", false) and sel != null and sel.k == "ac":
		tut_flag["sel"] = true
	for a in ac:
		if a.order != null and a.order.t == "attack":
			tut_flag["atk"] = true
	if trucks.size() >= 2:
		tut_flag["truck"] = true
	for m in msl:
		if m.side == 0 and m.kind == "bal":
			tut_flag["bal"] = true
	if bl.size() > bl0:
		tut_flag["build"] = true
	if uavs.size() > 0:
		tut_flag["uav"] = true
	if kills >= 5:
		tut_flag["kills5"] = true
	while tut_i < MISSIONS.size() - 1 and tut_flag.get(MISSIONS[tut_i][2], false):
		tut_i += 1
		toast("Mission done. Next: " + String(MISSIONS[tut_i][0]))
	var m: Array = MISSIONS[tut_i]
	l_tut_h.text = "MISSION %d/%d: %s" % [tut_i + 1, MISSIONS.size(), m[0]]
	l_tut_t.text = m[1]
	pn_tut.visible = started and over == "" and tab == "map"
	feed_box.position = Vector2(10, 128 + (pn_tut.size.y + 8.0 if pn_tut.visible else 0.0))


func sheet_help() -> void:
	sheet_title("How to play")
	for h in HELP_TEXT:
		var v := VBoxContainer.new()
		v.add_child(mk_label(h[0], 19, COL.orange))
		v.add_child(mk_wrap(h[1], 19, COL.text))
		sheet_box.add_child(mk_panel(v))
