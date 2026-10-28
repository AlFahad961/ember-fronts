extends Node2D
## Ember Front: pixel-art air-strike war game for phones (Godot 4).
## Everything is drawn in code, so the project only needs this script,
## Main.tscn and assets_data.gd.

const D = preload("res://assets_data.gd")

const TS := 6
const GW := 192
const GH := 256
const W := 1152.0
const H := 1536.0
const NB := 32
const BH := 48.0
const SAM_R := 88.0
const AC_SP := 72.0
const TURN := 2.0
const BURN := 1.1
const GB_DMG := 2.5
const RK_DMG := 0.4

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
var af_p: Array = []
var af_e: Dictionary = {}
var pcap := Vector2(W * 0.12, H * 0.5)
var ecap := Vector2(W * 0.88, H * 0.5)
var pp_pos: Array = []
var ppx_pos: Array = []
var ep_pos: Array = []
var dep_pos: Array = []
var ports_pos: Array = []
var spr_p: ImageTexture
var spr_e: ImageTexture
var spr_sh: ImageTexture

# ---------------------------------------------------------------- game state
var t := 0.0
var coins := 250.0
var speed := 1
var started := false
var over := ""
var idc := 0
var acn := 0
var ac: Array = []
var tg: Array = []
var pr: Array = []
var pt: Array = []
var msl: Array = []
var ea: Array = []
var fires: Array = []
var trail: Array = []
var uavs: Array = []
var loglist: Array = []
var unread := 0
var sel = null
var mode := ""
var mis := 3
var mt := 0.0
var ev_t := 70.0
var res_t := 12.0
var sam_t := 60.0
var ea_t := 40.0
var kills := 0
var lost := 0
var pplants: Array = []
var ppow := 1.0
var epow := 1.0
var oil := 40.0
var metal := 60.0
var p_ad := 0
var brig := 0
var tab := "map"
var nat: Array = []
var cases: Array = []
var offers: Array = []
var disc := 1.0
var disc_t := 0.0
var estock := 2.0
var ship_t := 10.0
var off_t := 60.0
var earned := 0.0
var war_pen := 0.0
var income := 0.0
var F := PackedFloat32Array()
var SUP := PackedFloat32Array()
var NET := PackedFloat32Array()

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

# ---------------------------------------------------------------- ui refs
var ui_root: Control
var l_coin: Label
var l_inc: Label
var l_clock: Label
var l_oil: Label
var l_met: Label
var l_pow: Label
var pn_pow: PanelContainer
var btn_inbound: Button
var bar_front: ProgressBar
var l_front: Label
var pn_toast: PanelContainer
var l_toast: Label
var pn_log: PanelContainer
var log_box: VBoxContainer
var chips_box: HBoxContainer
var chip_btns: Dictionary = {}
var pn_sel: PanelContainer
var l_sname: Label
var l_sstat: Label
var l_sstats: Label
var bar_fuel: ProgressBar
var l_armor: Label
var btn_rtb: Button
var pn_hint: PanelContainer
var sheet_scroll: ScrollContainer
var sheet_box: VBoxContainer
var sheet_sig := ""
var tab_btns := {}
var speed_btns := {}
var ov: Control
var ov_box: VBoxContainer
var blockers: Array = []
var dyn_case: Array = []
var dyn_offer: Array = []
var dyn_es: Array = []
var dyn_fb: Array = []

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
	for k in ["ink", "panel", "brass", "text", "dim", "orange", "blue", "red", "green"]:
		pass
	COL = {
		"ink": Color.html("0d130f"), "text": Color.html("efe6c8"), "dim": Color.html("a9a283"),
		"orange": Color.html("ff8a2a"), "blue": Color.html("4d93ff"), "red": Color.html("ff5a4d"),
		"green": Color.html("86d963"), "brass": Color.html("8b6f33"),
	}
	setup_noise()
	gen_world()
	render_terrain()
	make_sprites()
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
	rng.seed = 20261028
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
	return float((h ^ (h >> 16)) & 0xffff) / 65535.0


func coast_g(gy: float) -> float:
	return GW * 0.945 + (fb(n_coast, 3.0, gy / 14.0) - 0.5) * 9.0


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
			T[gy * GW + gx] = tt
	make_river(GW * 0.66, int(GH * 0.22), 1.0)
	make_river(GW * 0.2, 0, 2.0)
	make_river(GW * 0.86, int(GH * 0.4), 3.0)
	placed.append({"x": pcap.x, "y": pcap.y, "r": 62.0})
	placed.append({"x": ecap.x, "y": ecap.y, "r": 62.0})
	mk_town(pcap.x, pcap.y, 58.0, "AZURIA CITY", true)
	mk_town(ecap.x, ecap.y, 58.0, "KARMIN CITY", true)
	for i in range(6):
		var p := spot(W * 0.06, W * 0.4, H * 0.04, H * 0.96, 34.0)
		mk_town(p.x, p.y, rng.randf_range(24.0, 38.0), D.PLAYER_TOWNS[i], false)
	for i in range(6):
		var p := spot(W * 0.6, W * 0.9, H * 0.06, H * 0.94, 34.0)
		mk_town(p.x, p.y, rng.randf_range(24.0, 38.0), D.ENEMY_TOWNS[i], false)
	af_p = [
		{"x": W * 0.23, "y": H * 0.27, "ang": 0.0, "own": 0, "name": "Airfield North", "slots": []},
		{"x": W * 0.2, "y": H * 0.74, "ang": 0.0, "own": 0, "name": "Airfield South", "slots": []},
	]
	af_e = {"x": W * 0.84, "y": H * 0.19, "ang": PI, "own": 1, "name": "Enemy airfield", "slots": []}
	for a in [af_p[0], af_p[1], af_e]:
		placed.append({"x": a.x, "y": a.y, "r": 46.0})
		carve(a.x, a.y, 50.0)
	pp_pos = [spot(W * 0.1, W * 0.36, H * 0.12, H * 0.9, 20.0), spot(W * 0.1, W * 0.36, H * 0.12, H * 0.9, 20.0)]
	ppx_pos = [spot(W * 0.08, W * 0.36, H * 0.1, H * 0.92, 20.0), spot(W * 0.08, W * 0.36, H * 0.1, H * 0.92, 20.0)]
	ep_pos = [spot(W * 0.65, W * 0.88, H * 0.12, H * 0.9, 20.0), spot(W * 0.65, W * 0.88, H * 0.12, H * 0.9, 20.0)]
	for i in range(3):
		dep_pos.append(spot(W * 0.66, W * 0.88, H * 0.08, H * 0.94, 16.0))
	for arr in [pp_pos, ppx_pos, ep_pos, dep_pos]:
		for p in arr:
			carve(p.x, p.y, 16.0)
	for f in [0.3, 0.68]:
		var gy := int(f * GH)
		ports_pos.append(Vector2(coast_g(gy) * TS - 14.0, gy * TS))
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
	var facs: Array = [af_p[0], af_p[1], af_e]
	facs.append_array(pp_pos)
	facs.append_array(ppx_pos)
	facs.append_array(ep_pos)
	facs.append_array(dep_pos)
	facs.append_array(ports_pos)
	for f in facs:
		var best: Dictionary = towns[0]
		for tw in towns:
			if Vector2(tw.x, tw.y).distance_to(Vector2(f.x, f.y)) < Vector2(best.x, best.y).distance_to(Vector2(f.x, f.y)):
				best = tw
		roads.append([Vector2(f.x, f.y), Vector2(best.x, best.y)])


func make_river(gx0: float, gy0: int, k: float) -> void:
	var gx := gx0
	for gy in range(gy0, GH):
		gx += (fb(n_river, gy / 12.0, k) - 0.5) * 2.4
		var x := int(round(gx))
		for w in range(2):
			var i := gy * GW + clampi(x + w, 0, GW - 1)
			if T[i] != 0 and T[i] < 5:
				T[i] = 1


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
			if Vector2(cx, cy).length() < r and rng.randf() < (0.88 if cap else 0.7):
				b.append([round(x + cx + rng.randf_range(-1.5, 1.5)), round(y + cy + rng.randf_range(-1.5, 1.5)),
					4.0 + rng.randi_range(0, 1), 3.0 + rng.randi_range(0, 1), rng.randf()])
	towns.append({"x": x, "y": y, "r": r, "name": nm, "cap": cap, "b": b, "side": 0})


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
					img.fill_rect(Rect2i(gx * TS, gy * TS, TS, 2), Color(1, 1, 1, 0.5) if false else c.lightened(0.25))
				if gx < GW - 1 and T[gy * GW + gx + 1] < 5:
					img.fill_rect(Rect2i(gx * TS + TS - 2, gy * TS, 2, TS), c.darkened(0.2))
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
					if pass_i == 0:
						img.fill_rect(Rect2i(int(q.x) - 1, int(q.y) - 1, 3, 3), road_dark)
					else:
						img.fill_rect(Rect2i(int(q.x), int(q.y), 1, 1), road_lite)
	terr_tex = ImageTexture.create_from_image(img)


func plane_tex(pal: Dictionary, black: bool) -> ImageTexture:
	var img := Image.create(11, 11, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in range(D.PLANE.size()):
		var row: String = D.PLANE[y]
		for x in range(row.length()):
			var ch := row[x]
			if ch != ".":
				img.set_pixel(x, y, Color(0, 0, 0, 1) if black else Color.html(pal[ch]))
	return ImageTexture.create_from_image(img)


func make_sprites() -> void:
	spr_p = plane_tex(D.PAL_PLAYER, false)
	spr_e = plane_tex(D.PAL_ENEMY, false)
	spr_sh = plane_tex(D.PAL_PLAYER, true)


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
	var o := {"id": idc, "type": type, "x": x, "y": y, "hp": d.hp, "maxhp": d.hp, "alive": true, "cool": randf_range(0.0, 3.0)}
	o.merge(extra, true)
	tg.append(o)
	return o


func new_game() -> void:
	t = 0.0
	coins = 250.0
	speed = 1
	over = ""
	idc = 0
	acn = 0
	for arr in [ac, tg, pr, pt, msl, ea, fires, trail, uavs, loglist, cases, offers, pplants]:
		arr.clear()
	unread = 0
	sel = null
	mode = ""
	mis = 3
	mt = 0.0
	ev_t = 70.0
	res_t = 12.0
	sam_t = 60.0
	ea_t = 40.0
	kills = 0
	lost = 0
	ppow = 1.0
	epow = 1.0
	oil = 40.0
	metal = 60.0
	p_ad = 0
	brig = 0
	disc = 1.0
	disc_t = 0.0
	estock = 2.0
	ship_t = 10.0
	off_t = 60.0
	earned = 0.0
	war_pen = 0.0
	income = 0.0
	tab = "map"
	for i in range(NB):
		F[i] = W * 0.5 + (fb(n_front, i / 5.0, 3.0) - 0.5) * 150.0
		SUP[i] = 0.0
		NET[i] = 0.0
	for j in range(12):
		var y := (j + 0.5) * H / 12.0 + randf_range(-25.0, 25.0)
		add_target("inf", F[band_of(y)] + randf_range(28.0, 70.0), y)
	for f in [0.14, 0.3, 0.5, 0.68, 0.86]:
		var y: float = H * f
		add_target("sam", F[band_of(y)] + randf_range(80.0, 170.0), y)
	for p in ep_pos:
		add_target("plant", p.x, p.y, {"rebuild": 0.0})
	for p in dep_pos:
		add_target("depot", p.x, p.y)
	add_target("afield", af_e.x, af_e.y)
	for p in ports_pos:
		add_target("port", p.x, p.y, {"rebuild": 0.0})
	nat.clear()
	for n in D.NATIONS:
		nat.append({"id": n.id, "name": n.name, "c1": Color.html(n.c1), "c2": Color.html(n.c2),
			"mood": 60.0, "inc": 0, "promise": 0.0, "war": false})
	for i in range(pp_pos.size()):
		pplants.append({"x": pp_pos[i].x, "y": pp_pos[i].y, "hp": 12.0, "maxhp": 12.0, "alive": true,
			"rebuild": 0.0, "name": "Power plant %d" % (i + 1), "warn": 0.0})
	af_p[0].slots = []
	af_p[1].slots = []
	af_e.slots = []
	for i in range(3):
		add_aircraft(af_p[0])
	for i in range(2):
		var s := spawn_ship()
		s.y = H * randf_range(0.2, 0.7)
		s.x = sea_x(s.y) + s.off
	cam = Vector2(W * 0.3, H * 0.4)
	zoom = vw / 520.0
	clamp_cam()
	build_chips()
	select(null)
	set_tab("map")
	sheet_sig = ""


func add_aircraft(af: Dictionary) -> Dictionary:
	acn += 1
	var a := {"id": acn, "n": acn, "x": 0.0, "y": 0.0, "ang": af.ang, "sp": 0.0, "hp": 3, "fuel": 100.0,
		"gb": 4, "rk": 16, "aa": 2, "st": "parked", "af": af, "slot": 0, "order": null, "ph": "app",
		"wp": Vector2.ZERO, "cool": 0.0, "tm": 0.0, "aac": 0.0, "tr": 0.0, "loit": Vector2.ZERO,
		"lx": 0.0, "ly": 0.0, "dead": false}
	slot_in(a, af)
	ac.append(a)
	return a


func slot_in(a: Dictionary, af: Dictionary) -> void:
	var s := 0
	while af.slots.has(s):
		s += 1
	af.slots.append(s)
	a.slot = s
	a.af = af
	a.x = af.x - 26.0 + (s % 5) * 13.0
	a.y = af.y + 18.0 + floorf(s / 5.0) * 11.0
	a.ang = -PI / 2.0


func slot_out(a: Dictionary) -> void:
	var i: int = a.af.slots.find(a.slot)
	if i >= 0:
		a.af.slots.remove_at(i)


# ====================================================================== messages
func toast(m: String) -> void:
	if l_toast == null:
		return
	l_toast.text = m
	pn_toast.visible = true
	toast_t = 2.8


func say(m: String, kind: String = "", show_toast: bool = true) -> void:
	loglist.push_front({"t": t, "m": m, "k": kind})
	if loglist.size() > 40:
		loglist.pop_back()
	unread += 1
	if show_toast:
		toast(m)
	refresh_log()


func tstr(s: float) -> String:
	var v := maxf(0.0, s)
	return "%d:%02d" % [int(v / 60.0), int(fmod(v, 60.0))]


# ====================================================================== combat helpers
func boom(x: float, y: float, s: float) -> void:
	pt.append({"k": "ring", "x": x, "y": y, "vx": 0.0, "vy": 0.0, "l": 0.45, "m": 0.45, "s": 10.0 * s})
	for i in range(int(8 * s)):
		pt.append({"k": "fire", "x": x, "y": y, "vx": randf_range(-40, 40) * s, "vy": randf_range(-40, 40) * s,
			"l": randf_range(0.3, 0.7), "m": 0.7, "s": randf_range(2, 4) * sqrt(s)})
	for i in range(int(4 * s)):
		pt.append({"k": "smoke", "x": x + randf_range(-5, 5), "y": y + randf_range(-5, 5), "vx": randf_range(-8, 8),
			"vy": randf_range(-14, -4), "l": randf_range(2.2, 4.0), "m": 4.0, "s": randf_range(5, 9)})


func hit_target(o: Dictionary, dmg: float) -> void:
	if not o.alive:
		return
	o.hp -= dmg
	if o.hp <= 0.0:
		kill_target(o, true)


func kill_target(o: Dictionary, by_player: bool) -> void:
	if o.type == "ship":
		o.alive = false
		ship_sunk(o)
		return
	o.alive = false
	boom(o.x, o.y, 3.0 if (o.type == "plant" or o.type == "afield") else 1.6)
	fires.append({"x": o.x, "y": o.y, "t": 40.0 if o.type == "plant" else 18.0})
	var d: Dictionary = D.TYPES[o.type]
	if by_player:
		coins += d.rew
		kills += 1
		say("%s destroyed  +%d" % [d.name, d.rew], "good")
	else:
		coins += d.rew * 0.4
		say("%s overrun by our ground forces" % d.name, "good")
	if o.type == "inf":
		for i in range(NB):
			var w := 1.0 - absf((i + 0.5) * BH - o.y) / 160.0
			if w > 0.0:
				SUP[i] += 0.5 * w
	if o.type == "plant":
		o.rebuild = 100.0
		say("Karmin power grid is failing. Cities are going dark.", "good")
	if o.type == "port":
		o.rebuild = 120.0


func damage_aircraft(a: Dictionary, dmg: int) -> void:
	a.hp -= dmg
	pt.append({"k": "smoke", "x": a.x, "y": a.y, "vx": 0.0, "vy": 0.0, "l": 2.0, "m": 2.0, "s": 5.0})
	if a.hp <= 0:
		boom(a.x, a.y, 1.4)
		a.dead = true
		lost += 1
		if sel != null and sel.id == a.id:
			select(null)
		slot_out_if_parked(a)
		build_chips()
		say("Aircraft No.%d shot down" % a.n, "bad")
	else:
		toast("Aircraft No.%d is hit!" % a.n)


func slot_out_if_parked(_a: Dictionary) -> void:
	pass


func proj(k: String, from: Dictionary, to, extra: Dictionary = {}) -> Dictionary:
	var p := {"k": k, "x": from.x, "y": from.y, "sx": from.x, "sy": from.y, "tx": to.x, "ty": to.y, "tg": to,
		"t": 0.0, "dur": 0.7, "dmg": 0.0, "hit": false, "done": false}
	p.merge(extra, true)
	pr.append(p)
	return p


func airborne(a: Dictionary) -> bool:
	return a.st == "fly" or a.st == "loiter" or a.st == "rtb" or a.st == "takeoff"


# ====================================================================== orders
func nearest_af(a: Dictionary) -> Dictionary:
	var best: Dictionary = af_p[0]
	for f in af_p:
		if Vector2(f.x - a.x, f.y - a.y).length() < Vector2(best.x - a.x, best.y - a.y).length():
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
	else:
		a.st = "rtb"
		a.af = o.af if o.has("af") else nearest_af(a)


func give_order(a: Dictionary, o: Dictionary) -> void:
	if a.st == "landing" or a.st == "rearm":
		toast("No.%d is on the ground, rearming" % a.n)
		return
	if a.st == "parked":
		if o.t == "rtb":
			return
		if a.gb + a.rk <= 0 and o.t == "attack":
			toast("Ordnance empty")
			return
		slot_out(a)
		a.st = "takeoff"
		a.tm = 0.0
		a.sp = 0.0
		a.ang = a.af.ang
		a.order = o
		return
	if o.t == "attack" and a.gb + a.rk <= 0:
		toast("No.%d is out of ordnance" % a.n)
		o = {"t": "rtb"}
	a.order = o
	engage(a)


func finish_rearm(a: Dictionary) -> void:
	var gb_need: int = 4 - a.gb
	var w1 := mini(gb_need, int(coins / 8.0))
	coins -= w1 * 8
	a.gb += w1
	var w2 := mini(2 - a.aa, int(coins / 12.0))
	coins -= w2 * 12
	a.aa += w2
	var w3 := mini(16 - a.rk, int(coins))
	coins -= w3
	a.rk += w3
	a.fuel = 100.0
	a.hp = 3
	a.st = "parked"
	a.order = null
	if a.gb < 4 or a.aa < 2 or a.rk < 16:
		toast("No.%d only partly rearmed: not enough coins" % a.n)


# ====================================================================== update
func steer(a: Dictionary, tx: float, ty: float, dt: float, tr: float = TURN) -> void:
	var d := wrapf(atan2(ty - a.y, tx - a.x) - a.ang, -PI, PI)
	var m := tr * dt
	a.ang += clampf(d, -m, m)
	a.sp = minf(AC_SP, a.sp + 60.0 * dt)
	a.x += cos(a.ang) * a.sp * dt
	a.y += sin(a.ang) * a.sp * dt


func attack_pass(a: Dictionary) -> void:
	var o: Dictionary = a.order
	var target: Dictionary = o.tg
	if a.gb > 0:
		a.gb -= 1
		proj("gb", a, target, {"dmg": GB_DMG, "dur": 0.75})
	if a.rk > 0:
		var n := mini(4, a.rk)
		a.rk -= n
		for i in range(n):
			var aim := {"x": target.x + randf_range(-9, 9), "y": target.y + randf_range(-9, 9)}
			proj("rk", a, aim, {"dmg": RK_DMG, "dur": 0.5 + i * 0.07, "tg": target})
	if a.gb + a.rk <= 0:
		a.order = {"t": "rtb"}
		a.st = "rtb"
		a.af = nearest_af(a)
		toast("No.%d is out of ordnance. Returning." % a.n)


func crash(a: Dictionary, msg: String) -> void:
	boom(a.x, a.y, 1.4)
	a.dead = true
	lost += 1
	if sel != null and sel.id == a.id:
		select(null)
	build_chips()
	say(msg, "bad")


func upd_aircraft(a: Dictionary, dt: float) -> void:
	a.cool -= dt
	a.aac -= dt
	if a.st == "parked":
		return
	if a.st == "rearm":
		a.tm -= dt
		if a.tm <= 0.0:
			finish_rearm(a)
		return
	if a.st == "landing":
		a.tm += dt
		var u := clampf(a.tm / 1.8, 0.0, 1.0)
		var tx: float = a.af.x - 26.0 + (a.slot % 5) * 13.0
		var ty: float = a.af.y + 18.0 + floorf(a.slot / 5.0) * 11.0
		a.x = lerpf(a.lx, tx, u)
		a.y = lerpf(a.ly, ty, u)
		a.sp = lerpf(AC_SP * 0.5, 0.0, u)
		if u >= 1.0:
			a.st = "rearm"
			a.tm = 6.0
			a.ang = -PI / 2.0
		return
	a.fuel -= BURN * dt
	if a.fuel <= 0.0:
		crash(a, "Aircraft No.%d ran out of fuel and crashed" % a.n)
		return
	if a.st == "takeoff":
		a.tm += dt
		a.sp = minf(AC_SP, a.sp + AC_SP / 2.0 * dt)
		a.ang = a.af.ang
		a.x += cos(a.ang) * a.sp * dt
		a.y += sin(a.ang) * a.sp * dt
		if a.tm >= 2.2:
			engage(a)
		trail_add(a, dt)
		return
	if a.st == "fly" or a.st == "loiter":
		var home := nearest_af(a)
		var need := Vector2(a.x - home.x, a.y - home.y).length() / AC_SP * BURN + 9.0
		if a.fuel < need:
			a.order = {"t": "rtb"}
			a.st = "rtb"
			a.af = home
			toast("No.%d is low on fuel. Returning." % a.n)
	if a.st == "fly":
		var o = a.order
		if o == null or o.t != "attack" or not o.tg.alive:
			var px: float = a.x
			var py: float = a.y
			if o != null and o.has("tg"):
				px = o.tg.x
				py = o.tg.y
			a.order = {"t": "loiter", "x": px, "y": py}
			a.st = "loiter"
			a.loit = Vector2(px, py)
			if o != null and o.has("tg"):
				toast("Target down. No.%d is loitering." % a.n)
		elif a.ph == "app":
			var target: Dictionary = o.tg
			steer(a, target.x, target.y, dt)
			if Vector2(a.x - target.x, a.y - target.y).length() < 20.0 and a.cool <= 0.0:
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
		if Vector2(a.x - l.x, a.y - l.y).length() > 85.0:
			steer(a, l.x, l.y, dt)
		else:
			a.ang += 1.5 * dt
			a.sp = minf(AC_SP, a.sp + 60.0 * dt)
			a.x += cos(a.ang) * a.sp * dt
			a.y += sin(a.ang) * a.sp * dt
	elif a.st == "rtb":
		var f: Dictionary = a.af
		steer(a, f.x - 10.0, f.y + 14.0, dt)
		if Vector2(a.x - f.x + 10.0, a.y - f.y - 14.0).length() < 16.0:
			slot_in(a, f)
			a.lx = a.x
			a.ly = a.y
			a.x = a.lx
			a.y = a.ly
			a.st = "landing"
			a.tm = 0.0
			a.order = null
	trail_add(a, dt)
	if a.aa > 0 and a.aac <= 0.0:
		for e in ea:
			if Vector2(e.x - a.x, e.y - a.y).length() < 80.0:
				a.aa -= 1
				a.aac = 2.5
				proj("aa", a, e, {"dur": 0.6, "hit": randf() < 0.65})
				toast("No.%d fires air-to-air missile" % a.n)
				break
	a.x = clampf(a.x, 0.0, W)
	a.y = clampf(a.y, 0.0, H)


func trail_add(a: Dictionary, dt: float) -> void:
	a.tr -= dt
	if a.tr <= 0.0:
		a.tr = 0.09
		trail.append({"x": a.x, "y": a.y, "l": 1.3})


func upd_ground(dt: float) -> void:
	for i in range(NB):
		var yc := (i + 0.5) * BH
		var s := 0.0
		for o in tg:
			if o.alive and o.type == "inf":
				s += maxf(0.0, 1.0 - absf(o.y - yc) / 90.0)
		var p := (1.3 + 0.12 * brig - war_pen) * (0.8 + 0.2 * ppow)
		var e := (0.95 + 0.6 * s) * (0.75 + 0.25 * epow) + 0.035 * estock - SUP[i]
		NET[i] = p - e
		SUP[i] = maxf(0.0, SUP[i] - 0.012 * dt)
	for i in range(NB):
		F[i] = clampf(F[i] + NET[i] * 3.5 * dt, 90.0, W - 90.0)
	var c := F.duplicate()
	for i in range(NB):
		var a: float = c[maxi(0, i - 1)]
		var b: float = c[mini(NB - 1, i + 1)]
		F[i] += ((a + b) / 2.0 - c[i]) * 0.35 * dt
	for o in tg:
		if o.alive and o.type != "ship" and o.x < front_at(o.y) + 6.0:
			kill_target(o, false)
	for tw in towns:
		tw.side = 0 if tw.x < front_at(tw.y) else 1
	var ci := band_of(ecap.y)
	var pi2 := band_of(pcap.y)
	var wf := (F[ci - 1] + F[ci] + F[ci + 1]) / 3.0
	var lf := (F[pi2 - 1] + F[pi2] + F[pi2 + 1]) / 3.0
	if wf >= ecap.x - 30.0:
		finish("win")
	elif lf <= pcap.x + 30.0:
		finish("lose")


func upd_enemy(dt: float) -> void:
	res_t -= dt
	if res_t <= 0.0:
		res_t = 16.0
		var inf_list: Array = tg.filter(func(o): return o.alive and o.type == "inf")
		if inf_list.size() < 14:
			var best := 0
			var bc := 99.0
			for j in range(12):
				var y0 := j * H / 12.0
				var y1 := y0 + H / 12.0
				var c := 0.0
				for o in inf_list:
					if o.y >= y0 and o.y < y1:
						c += 1.0
				c += randf()
				if c < bc:
					bc = c
					best = j
			var y := (best + 0.5) * H / 12.0 + randf_range(-30.0, 30.0)
			add_target("inf", front_at(y) + randf_range(30.0, 80.0), y)
	sam_t -= dt
	if sam_t <= 0.0:
		sam_t = 100.0
		var sams: Array = tg.filter(func(o): return o.alive and o.type == "sam")
		if sams.size() < 4:
			var y := randf_range(H * 0.1, H * 0.9)
			add_target("sam", front_at(y) + randf_range(90.0, 170.0), y)
			say("Enemy has set up a new air defense site", "bad", false)
	for o in tg:
		if not o.alive and (o.type == "plant" or o.type == "port") and o.rebuild > 0.0:
			o.rebuild -= dt
			if o.rebuild <= 0.0:
				o.alive = true
				o.hp = ceilf(o.maxhp / 2.0)
	var ep_n := 0
	var ep_alive := 0
	for o in tg:
		if o.type == "plant":
			ep_n += 1
			if o.alive:
				ep_alive += 1
	epow = float(ep_alive) / maxf(1.0, ep_n)
	for p in pplants:
		p.warn = maxf(0.0, p.warn - dt)
		if not p.alive:
			p.rebuild -= dt
			if p.rebuild <= 0.0:
				p.alive = true
				p.hp = 6.0
				say("%s is back online" % p.name, "good")
		else:
			p.hp = minf(p.maxhp, p.hp + 0.06 * dt)
	var pa := 0
	for p in pplants:
		if p.alive:
			pa += 1
	ppow = minf(1.0, pa / 2.0)
	# air defense sites
	for s in tg:
		if not s.alive or s.type != "sam":
			continue
		s.cool -= dt
		s.eng = false
		var target = null
		var bd := SAM_R
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
			ea.append({"id": idc, "x": afl.x, "y": afl.y, "ang": PI, "hp": 1, "life": 70.0, "cool": 1.5})
			say("Enemy interceptor scrambled", "bad", false)
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
			proj("ab", e, target, {"dur": 0.18, "hit": randf() < 0.3 * (1.0 - 0.12 * p_ad)})
		if target == null and e.life < 0.0 and Vector2(e.x - home.x, e.y - home.y).length() < 30.0:
			e.hp = 0
	ea = ea.filter(func(e): return e.hp > 0 and e.life > -30.0)
	# enemy ballistic strikes on our power plants
	ev_t -= dt
	if ev_t <= 0.0:
		ev_t = randf_range(100.0, 150.0)
		var alive_pl: Array = pplants.filter(func(p): return p.alive)
		if alive_pl.size() > 0:
			var p: Dictionary = alive_pl[randi() % alive_pl.size()]
			p.warn = 6.0
			msl.append({"enemy": true, "sx": W + 30.0, "sy": p.y - 120.0, "tx": p.x, "ty": p.y, "t": 0.0, "dur": 6.0,
				"tgt": p, "done": false, "fade": 3.0})
			say("INBOUND: ballistic missile heading for %s" % p.name, "bad")


func upd_proj(dt: float) -> void:
	for p in pr:
		p.t += dt
		var f := clampf(p.t / p.dur, 0.0, 1.0)
		if (p.k == "sam" or p.k == "aa" or p.k == "ab") and p.tg != null:
			p.tx = p.tg.x
			p.ty = p.tg.y
		p.x = lerpf(p.sx, p.tx, f)
		p.y = lerpf(p.sy, p.ty, f)
		if f >= 1.0:
			p.done = true
			if p.k == "gb" or p.k == "rk":
				boom(p.tx, p.ty, 1.2 if p.k == "gb" else 0.35)
				if p.tg != null and p.tg.alive and Vector2(p.tg.x - p.tx, p.tg.y - p.ty).length() < 60.0:
					hit_target(p.tg, p.dmg)
			elif p.k == "sam" or p.k == "ab":
				if p.hit and not p.tg.dead:
					damage_aircraft(p.tg, 1)
				else:
					pt.append({"k": "smoke", "x": p.tx, "y": p.ty, "vx": 0.0, "vy": 0.0, "l": 1.2, "m": 1.2, "s": 4.0})
			elif p.k == "aa":
				if p.hit and p.tg.hp > 0:
					p.tg.hp = 0
					boom(p.tg.x, p.tg.y, 1.2)
					coins += 30.0
					kills += 1
					say("Enemy interceptor shot down  +30", "good")
				else:
					toast("Air-to-air missile missed")
	pr = pr.filter(func(p): return not p.done)
	for m in msl:
		m.t += dt
		if m.t >= m.dur and not m.done:
			m.done = true
			m.fade = 3.0
			if m.enemy and randf() < 0.2 * p_ad:
				boom(m.tx, m.ty - 30.0, 1.4)
				say("Air defense intercepted the incoming missile", "good")
			elif m.enemy:
				var p: Dictionary = m.tgt
				boom(p.x, p.y, 3.0)
				if p.alive:
					p.hp -= 7.0
					if p.hp <= 0.0:
						p.alive = false
						p.rebuild = 70.0
						say("%s destroyed. Blackout in our cities." % p.name, "bad")
					else:
						say("%s damaged" % p.name, "bad")
			else:
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
		if m.done:
			m.fade -= dt
	msl = msl.filter(func(m): return not m.done or m.fade > 0.0)


func upd_fx(dt: float) -> void:
	for p in pt:
		p.l -= dt
		p.x += p.vx * dt
		p.y += p.vy * dt
		if p.k == "smoke":
			p.s += dt * 3.0
	pt = pt.filter(func(p): return p.l > 0.0)
	for o in trail:
		o.l -= dt
	trail = trail.filter(func(o): return o.l > 0.0)
	for f in fires:
		f.t -= dt
		if randf() < dt * 5.0:
			pt.append({"k": "smoke", "x": f.x + randf_range(-4, 4), "y": f.y, "vx": randf_range(-4, 4), "vy": -randf_range(8, 16),
				"l": 3.2, "m": 3.2, "s": 5.0})
		if randf() < dt * 4.0:
			pt.append({"k": "fire", "x": f.x + randf_range(-5, 5), "y": f.y + randf_range(-3, 3), "vx": 0.0, "vy": -12.0,
				"l": 0.5, "m": 0.5, "s": 3.0})
	fires = fires.filter(func(f): return f.t > 0.0)


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
	var covered := 0.0
	for i in range(NB):
		covered += F[i]
	var frac := 1.0 - (covered / NB - W * 0.12) / (W * 0.76)
	income = 1.8 * (0.55 + 0.45 * ppow) * (0.7 + 0.6 * clampf(1.0 - frac, 0.0, 1.0))
	coins += income * dt
	mt += dt
	if mt >= 80.0:
		mt = 0.0
		if mis < 5:
			mis += 1
			toast("Ballistic missile ready")
	oil = minf(200.0, oil + 0.22 * (0.5 + 0.5 * ppow) * dt)
	metal = minf(200.0, metal + 0.16 * (0.5 + 0.5 * ppow) * dt)
	estock = maxf(0.0, estock - 0.01 * dt)
	earned += income * dt
	upd_ground(dt)
	upd_enemy(dt)
	upd_ships(dt)
	upd_diplo(dt)
	upd_uavs(dt)
	for a in ac:
		if not a.dead:
			upd_aircraft(a, dt)
	ac = ac.filter(func(a): return not a.dead)
	upd_proj(dt)
	upd_fx(dt)


# ====================================================================== ships, shop, diplomacy
func sea_x(y: float) -> float:
	return minf(W - 6.0, coast_g(clampf(y / TS, 0.0, GH)) * TS)


func spawn_ship() -> Dictionary:
	var dir := 1.0 if randf() < 0.5 else -1.0
	var y := -10.0 if dir > 0.0 else H + 10.0
	var flag := "kar"
	if randf() >= 0.45:
		flag = nat[randi() % nat.size()].id
	var cg: Array = D.CARGO[randi() % D.CARGO.size()]
	var s := add_target("ship", 0.0, y, {"flag": flag, "dir": dir, "sp": randf_range(17.0, 22.0), "off": randf_range(16.0, 32.0),
		"cargo": cg[0], "col": Color.html(cg[1]), "want_dock": randf() < 0.75, "dock": 0.0})
	s.x = sea_x(y) + s.off
	return s


func upd_ships(dt: float) -> void:
	ship_t -= dt
	var ships: Array = tg.filter(func(o): return o.type == "ship" and o.alive)
	if ship_t <= 0.0:
		ship_t = randf_range(16.0, 26.0)
		if ships.size() < 6:
			spawn_ship()
	var ports: Array = tg.filter(func(o): return o.type == "port" and o.alive)
	for s in ships:
		if s.dock > 0.0:
			s.dock -= dt
			if s.dock <= 0.0:
				estock = minf(9.0, estock + 1.0)
			continue
		s.y += s.dir * s.sp * dt
		s.x = lerpf(s.x, sea_x(s.y) + s.off, minf(1.0, dt * 3.0))
		if s.want_dock:
			for p in ports:
				if absf(s.y - p.y) < 4.0:
					s.dock = 9.0
					s.want_dock = false
					s.x = p.x + 34.0
		if s.y < -40.0 or s.y > H + 40.0:
			s.alive = false
	tg = tg.filter(func(o): return o.type != "ship" or o.alive)


func ship_sunk(s: Dictionary) -> void:
	boom(s.x, s.y, 1.6)
	for i in range(10):
		pt.append({"k": "deb", "x": s.x + randf_range(-8, 8), "y": s.y + randf_range(-10, 10), "vx": randf_range(-2, 2),
			"vy": randf_range(-2, 2), "l": randf_range(20, 40), "m": 40.0, "s": 3.0, "c": s.col})
	pt.append({"k": "oil", "x": s.x, "y": s.y, "vx": 0.0, "vy": 0.0, "l": 40.0, "m": 40.0, "s": 14.0})
	estock = maxf(0.0, estock - 1.0)
	coins += 30.0
	kills += 1
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


func upd_uavs(dt: float) -> void:
	for u in uavs:
		u.life -= dt
		if u.tg != null and u.tg.alive:
			u.tx = u.tg.x
			u.ty = u.tg.y
		var d := wrapf(atan2(u.ty - u.y, u.tx - u.x) - u.ang, -PI, PI)
		u.ang += clampf(d, -3.0 * dt, 3.0 * dt)
		u.x += cos(u.ang) * 95.0 * dt
		u.y += sin(u.ang) * 95.0 * dt
		u.tr -= dt
		if u.tr <= 0.0:
			u.tr = 0.1
			trail.append({"x": u.x, "y": u.y, "l": 0.8})
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
	uavs = uavs.filter(func(u): return not u.dead)


func price(k: String) -> Dictionary:
	var p: Dictionary = D.PRICE[k]
	return {"c": ceili(p.c * disc), "m": ceili(p.m * disc), "o": ceili(p.o * disc)}


func can_pay(p: Dictionary) -> bool:
	return coins >= p.c and metal >= p.m and oil >= p.o


func spend(p: Dictionary) -> void:
	coins -= p.c
	metal -= p.m
	oil -= p.o


func buy(k: String) -> void:
	var p := price(k)
	if k == "ac" and ac.size() >= 8:
		toast("Hangar is full (8 aircraft)")
		return
	if k == "ad" and p_ad >= 4:
		toast("Maximum air defense reached")
		return
	if k == "plant" and pplants.size() >= 4:
		toast("Maximum power plants built")
		return
	if k == "brig" and brig >= 6:
		toast("Maximum brigades reached")
		return
	if k == "msl" and mis >= 8:
		toast("Missile depot is full")
		return
	if not can_pay(p):
		toast("Not enough coins, oil or metal")
		return
	spend(p)
	match k:
		"ac":
			var best: Dictionary = af_p[0]
			for f in af_p:
				if f.slots.size() < best.slots.size():
					best = f
			var a := add_aircraft(best)
			build_chips()
			set_tab("map")
			select(a)
			toast("New aircraft No.%d delivered" % a.n)
		"msl":
			mis += 1
			toast("Ballistic missile delivered")
		"ad":
			p_ad += 1
			toast("Air defense battery deployed")
		"plant":
			var s: Vector2 = ppx_pos[pplants.size() - 2]
			pplants.append({"x": s.x, "y": s.y, "hp": 12.0, "maxhp": 12.0, "alive": true, "rebuild": 0.0,
				"name": "Power plant %d" % (pplants.size() + 1), "warn": 0.0})
			toast("New power plant built")
		"brig":
			brig += 1
			toast("Fresh brigade sent to the front")
	sheet_sig = ""


func new_case(n: Dictionary, stage: int) -> Dictionary:
	var c := {"n": n, "stage": stage, "t": D.STAGE_T[stage], "tm": D.STAGE_T[stage]}
	cases.append(c)
	return c


func case_for(n: Dictionary):
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
	sheet_sig = ""


func declare_war(c: Dictionary) -> void:
	var n: Dictionary = c.n
	n.war = true
	cases = cases.filter(func(x): return x.n.id != n.id)
	offers = offers.filter(func(o): return o.n.id != n.id)
	war_pen += 0.12
	ea_t = minf(ea_t, 10.0)
	say("%s declares war on Azuria and joins Karmin." % n.name, "bad")
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
	if randf() < 0.5 or disc < 1.0:
		offers.append({"n": n, "kind": "sell", "t": 70.0, "tm": 70.0, "q": 8, "coins": 34})
		say("%s wants to buy metal x8 for 34 coins" % n.name, "")
	else:
		offers.append({"n": n, "kind": "treaty", "t": 70.0, "tm": 70.0, "q": 0, "coins": 0})
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
			if metal < o.q:
				toast("Not enough metal")
				return
			metal -= o.q
			coins += o.coins
			o.n.mood = minf(100.0, o.n.mood + 6.0)
			say("Sold metal x%d to %s  +%d" % [o.q, o.n.name, o.coins], "good")
		else:
			disc = 0.9
			disc_t = 150.0
			o.n.mood = minf(100.0, o.n.mood + 10.0)
			say("Trade treaty with %s: purchases cost 10%% less for 2:30" % o.n.name, "good")
	offers.remove_at(i)
	sheet_sig = ""


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
		elif event is InputEventMouseMotion and touches.has(0):
			touch_move(0, event.position)


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


func pick(list: Array, sp: Vector2, r: float):
	var best = null
	var bd := r
	for o in list:
		var d := w2s(o.x, o.y).distance_to(sp)
		if d < bd:
			bd = d
			best = o
	return best


func tap(sp: Vector2) -> void:
	if not started or over != "":
		return
	var wx := cam.x + sp.x / zoom
	var wy := cam.y + sp.y / zoom
	if mode == "missile":
		if mis <= 0:
			toast("No ballistic missiles ready")
			return
		mis -= 1
		var f: Dictionary = af_p[0]
		msl.append({"enemy": false, "sx": f.x - 60.0, "sy": f.y + 60.0, "tx": wx, "ty": wy, "t": 0.0, "dur": 4.2,
			"done": false, "fade": 3.0})
		say("Ballistic missile launched", "")
		mode = ""
		return
	if mode == "uav":
		var live: Array = tg.filter(func(o): return o.alive)
		var target = pick(live, sp, 60.0)
		var cost := price("uav")
		if not can_pay(cost):
			toast("Not enough resources")
			mode = ""
			return
		spend(cost)
		var f2: Dictionary = af_p[0]
		var tx := wx
		var ty := wy
		if target != null:
			tx = target.x
			ty = target.y
		uavs.append({"x": f2.x, "y": f2.y, "ang": 0.0, "tg": target, "tx": tx, "ty": ty, "life": 40.0, "tr": 0.0, "dead": false})
		say("UAV launched", "")
		mode = ""
		return
	var own = pick(ac, sp, 56.0)
	if own != null:
		if sel != null and sel.id == own.id:
			select(null)
		else:
			select(own)
		return
	var live2: Array = tg.filter(func(o): return o.alive and o.y > -5.0 and o.y < H + 5.0)
	var target2 = pick(live2, sp, 52.0)
	if target2 != null:
		var nm := tg_name(target2)
		var neu := is_neutral(target2)
		if sel != null:
			give_order(sel, {"t": "attack", "tg": target2})
			toast("No.%d: attacking %s%s" % [sel.n, nm.to_lower(), ". Neutral flag: this will cause a diplomatic incident." if neu else ""])
		else:
			toast("%s  armor %d/%d" % [nm, ceili(target2.hp), int(target2.maxhp)])
		return
	var afp = pick(af_p, sp, 56.0)
	if afp != null and sel != null and sel.st != "parked":
		give_order(sel, {"t": "rtb", "af": afp})
		toast("No.%d: returning to %s" % [sel.n, String(afp.name).to_lower()])
		return
	var pl = pick(pplants, sp, 50.0)
	if pl != null and sel == null:
		toast("%s  armor %d/%d" % [pl.name, ceili(pl.hp), int(pl.maxhp)])
		return
	if sel != null:
		give_order(sel, {"t": "loiter", "x": wx, "y": wy})


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if over == "" and started and tab != "map":
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


func draw_world() -> void:
	var nf := night_f()
	var vx0 := cam.x - 30.0
	var vy0 := cam.y - 30.0
	var vx1 := cam.x + vw / zoom + 30.0
	var vy1 := cam.y + vh / zoom + 30.0
	draw_texture_rect(terr_tex, Rect2(0, 0, W, H), false)
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
	# air defense rings
	for s in tg:
		if s.alive and s.type == "sam" and s.x > vx0 - 100 and s.x < vx1 + 100 and s.y > vy0 - 100 and s.y < vy1 + 100:
			var col := Color(1, 0.27, 0.23, 0.7) if s.get("eng", false) else Color(1, 0.35, 0.27, 0.25)
			for k in range(20):
				var a0 := TAU * k / 20.0
				draw_arc(Vector2(s.x, s.y), SAM_R, a0, a0 + TAU / 40.0, 4, col, 1.4)
	# towns
	var roofs := [
		[Color.html("7a9bd0"), Color.html("6688bd"), Color.html("8aaadb")],
		[Color.html("c75d43"), Color.html("b04d38"), Color.html("d97250")],
	]
	for tw in towns:
		if tw.x < vx0 - tw.r or tw.x > vx1 + tw.r or tw.y < vy0 - tw.r or tw.y > vy1 + tw.r:
			continue
		var pal: Array = roofs[tw.side]
		for b in tw.b:
			draw_rect(Rect2(b[0] + 1, b[1] + 1, b[2], b[3]), Color(0, 0, 0, 0.28))
		for b in tw.b:
			draw_rect(Rect2(b[0], b[1], b[2], b[3]), pal[int(b[4] * 3)])
			draw_rect(Rect2(b[0], b[1] + b[3] - 1, b[2], 1), Color(0, 0, 0, 0.25))
	# facilities
	for a in af_p:
		draw_field(a, Color.html("59708f"))
	for o in tg:
		if o.type == "afield" and o.alive:
			draw_field(af_e, Color.html("8f4a40"))
	for p in pplants:
		draw_plant(p.x, p.y, p.alive, Color.html("6e7f99"))
	for o in tg:
		if not o.alive:
			continue
		match o.type:
			"plant":
				draw_plant(o.x, o.y, true, Color.html("9a6a62"))
			"port":
				facil(o.x, o.y, 16, 10, Color.html("7b6a52"))
				draw_rect(Rect2(o.x + 6, o.y - 3, 24, 6), Color.html("5b4a30"))
				draw_rect(Rect2(o.x - 2, o.y - 12, 2, 10), Color.html("3a3e44"))
				draw_rect(Rect2(o.x - 2, o.y - 12, 8, 2), Color.html("3a3e44"))
			"ship":
				draw_ship(o)
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
	# night
	if nf > 0.01:
		draw_rect(Rect2(0, 0, W, H), Color(6.0 / 255.0, 12.0 / 255.0, 46.0 / 255.0, nf))
		if nf > 0.08:
			var la := clampf(nf * 1.6, 0.0, 1.0)
			for tw in towns:
				if tw.x < vx0 - tw.r or tw.x > vx1 + tw.r or tw.y < vy0 - tw.r or tw.y > vy1 + tw.r:
					continue
				var pw: float = ppow if tw.side == 0 else epow
				if pw <= 0.0:
					continue
				draw_circle(Vector2(tw.x, tw.y), tw.r * 1.05, Color(1, 0.8, 0.39, 0.07 * la * pw))
				var lc := Color(1, 0.84, 0.43, la)
				for b in tw.b:
					if rhash(int(b[0]), int(b[1]), 3) < pw:
						draw_rect(Rect2(b[0] + 1, b[1] + 1, 1, 1), lc)
	# front line
	var fl := PackedVector2Array()
	fl.append(Vector2(F[0], 0.0))
	for i in range(NB):
		fl.append(Vector2(F[i], (i + 0.5) * BH))
	fl.append(Vector2(F[NB - 1], H))
	draw_polyline(fl, Color(0.04, 0.04, 0.08, 0.7), 6.0)
	draw_polyline(offset_line(fl, -2.0), Color.html("4d93ff"), 2.0)
	draw_polyline(offset_line(fl, 2.0), Color.html("e5483f"), 2.0)
	for i in range(2, NB, 4):
		var n := NET[i]
		if absf(n) < 0.04:
			continue
		var y := (i + 0.5) * BH
		if n > 0.0:
			draw_arrow(F[i] - 26.0, y, 1.0, clampf(n * 60.0, 14.0, 52.0), Color.html("ff8a2a"))
		else:
			draw_arrow(F[i] + 26.0, y, -1.0, clampf(-n * 60.0, 14.0, 52.0), Color.html("ff5a4d"))


func offset_line(src: PackedVector2Array, dx: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in src:
		out.append(Vector2(p.x + dx, p.y))
	return out


func facil(x: float, y: float, w: float, h: float, c: Color) -> void:
	draw_rect(Rect2(x - w / 2.0 + 2, y - h / 2.0 + 2, w, h), Color(0, 0, 0, 0.3))
	draw_rect(Rect2(x - w / 2.0, y - h / 2.0, w, h), c)
	draw_rect(Rect2(x - w / 2.0, y - h / 2.0, w, 2), Color(1, 1, 1, 0.18))


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


func draw_plant(x: float, y: float, alive: bool, col: Color) -> void:
	if not alive:
		draw_rect(Rect2(x - 10, y - 7, 20, 14), Color.html("2a2623"))
		return
	facil(x, y, 22, 14, col)
	draw_rect(Rect2(x - 8, y - 14, 4, 12), Color.html("3a3e44"))
	draw_rect(Rect2(x + 3, y - 14, 4, 12), Color.html("3a3e44"))
	if randf() < 0.02:
		pt.append({"k": "smoke", "x": x - 6, "y": y - 14, "vx": 3.0, "vy": -9.0, "l": 2.6, "m": 2.6, "s": 3.5})


func flag_cols(id: String) -> Array:
	if id == "kar":
		return [Color.html("e5483f"), Color.html("222222")]
	var n := nat_of(id)
	if n.is_empty():
		return [Color.GRAY, Color.GRAY]
	return [n.c1, n.c2]


func draw_ship(s: Dictionary) -> void:
	var x: float = s.x
	var y: float = s.y
	var fc := flag_cols(s.flag)
	draw_rect(Rect2(x - 1, y - 8, 7, 18), Color(0, 0.08, 0.24, 0.3))
	draw_rect(Rect2(x - 1, y + (-17 if s.dir > 0 else 11), 2, 6), Color(1, 1, 1, 0.4))
	draw_rect(Rect2(x - 3, y - 9, 6, 18), Color.html("59616b"))
	draw_rect(Rect2(x - 2, y + 9 if s.dir > 0 else y - 12, 4, 3), Color.html("7d8791"))
	draw_rect(Rect2(x - 2, y - 6, 4, 3), s.col)
	draw_rect(Rect2(x - 2, y - 2, 4, 3), Color.html("e9d49a"))
	draw_rect(Rect2(x - 2, y + 2, 4, 3), Color.html("c75d43"))
	draw_rect(Rect2(x - 1, y + 6, 2, 2), Color.html("dddddd"))
	draw_rect(Rect2(x + 3, y - 9, 2, 3), fc[0])
	if s.dock > 0.0:
		draw_rect(Rect2(x - 7, y - 1, 2, 2), Color(1, 1, 1, 0.8))


func draw_arrow(x: float, y: float, dir: float, ln: float, col: Color) -> void:
	var dark := Color.html("2a1608")
	draw_line(Vector2(x - 6 * dir, y), Vector2(x + ln * dir, y), dark, 6.0)
	draw_line(Vector2(x - 6 * dir, y - 9), Vector2(x - 6 * dir, y + 9), dark, 6.0)
	draw_line(Vector2(x - 6 * dir, y), Vector2(x + ln * dir, y), col, 3.0)
	draw_line(Vector2(x - 6 * dir, y - 9), Vector2(x - 6 * dir, y + 9), col, 3.0)
	draw_colored_polygon(PackedVector2Array([Vector2(x + (ln + 12) * dir, y), Vector2(x + (ln - 3) * dir, y - 10), Vector2(x + (ln - 3) * dir, y + 10)]), dark)
	draw_colored_polygon(PackedVector2Array([Vector2(x + (ln + 8) * dir, y), Vector2(x + (ln - 1) * dir, y - 7), Vector2(x + (ln - 1) * dir, y + 7)]), col)


func draw_fx() -> void:
	for o in trail:
		draw_rect(Rect2(o.x - 1, o.y - 1, 2, 2), Color(0.92, 0.94, 0.96, o.l / 1.3 * 0.55))
	for m in msl:
		var f := clampf(m.t / m.dur, 0.0, 1.0)
		var cx: float = (m.sx + m.tx) / 2.0 + (m.ty - m.sy) * 0.28
		var cy: float = (m.sy + m.ty) / 2.0 - (m.tx - m.sx) * 0.28
		var al := clampf(m.fade / 3.0, 0.0, 1.0) if m.done else 1.0
		var steps := 36
		var prev := bez(m, cx, cy, 0.0)
		for i in range(steps):
			var cur := bez(m, cx, cy, f * (i + 1) / steps)
			var tail := 0.25 + 0.75 * (float(i) / steps)
			var base := Color(0.78, 0.27, 0.23, al * tail) if m.enemy else Color(0.66, 0.44, 0.24, al * tail)
			draw_line(prev, cur, base, 3.2)
			draw_line(prev, cur, Color(1, 0.89, 0.67, al * tail * 0.7), 1.1)
			prev = cur
		if not m.done:
			var hd := bez(m, cx, cy, f)
			draw_rect(Rect2(hd.x - 2, hd.y - 2, 4, 4), Color.WHITE)
	for p in pt:
		var a := clampf(p.l / p.m, 0.0, 1.0)
		match p.k:
			"smoke":
				draw_rect(Rect2(p.x - p.s / 2.0, p.y - p.s / 2.0, p.s, p.s), Color(0.8, 0.8, 0.82, a * 0.5))
			"fire":
				var fc := Color(1, 0.78, 0.27, a) if a > 0.5 else Color(1, 0.39, 0.12, a)
				draw_rect(Rect2(p.x - p.s / 2.0, p.y - p.s / 2.0, p.s, p.s), fc)
			"deb":
				draw_rect(Rect2(p.x, p.y, 3, 2), p.c)
			"oil":
				draw_circle(Vector2(p.x, p.y), p.s * (1.3 - a * 0.3), Color(0.08, 0.08, 0.1, a * 0.45))
			"ring":
				draw_arc(Vector2(p.x, p.y), p.s * (1.6 - a) * 1.6, 0.0, TAU, 20, Color(1, 0.86, 0.55, a), 2.0)
				draw_circle(Vector2(p.x, p.y), p.s * a * 0.9, Color(1, 0.94, 0.78, a * 0.7))
	for p in pr:
		if p.k == "gb":
			draw_rect(Rect2(p.x - 1.5, p.y - 1.5, 3, 3), Color.html("fff3b0"))
		elif p.k == "rk":
			var f2 := clampf(p.t / p.dur, 0.0, 1.0)
			var bx := lerpf(p.sx, p.tx, maxf(0.0, f2 - 0.2))
			var by := lerpf(p.sy, p.ty, maxf(0.0, f2 - 0.2))
			draw_line(Vector2(bx, by), Vector2(p.x, p.y), Color(1, 0.67, 0.24, 0.9), 1.4)
		else:
			var col := Color(1, 0.39, 0.31, 0.95)
			if p.k == "aa":
				col = Color(0.47, 0.78, 1, 0.95)
			elif p.k == "ab":
				col = Color(1, 0.9, 0.47, 0.9)
			draw_line(Vector2(lerpf(p.sx, p.x, 0.6), lerpf(p.sy, p.y, 0.6)), Vector2(p.x, p.y), col, 1.8)


func bez(m: Dictionary, cx: float, cy: float, u: float) -> Vector2:
	return Vector2((1 - u) * (1 - u) * m.sx + 2 * (1 - u) * u * cx + u * u * m.tx,
		(1 - u) * (1 - u) * m.sy + 2 * (1 - u) * u * cy + u * u * m.ty)


func draw_marker(p: Vector2, letter: String, col: Color, hp: float, mx: float, pulse: bool) -> void:
	var s := 46.0
	var r := Rect2(p.x - s / 2.0, p.y - s / 2.0, s, s)
	draw_rect(r, Color(0.07, 0.04, 0.04, 0.86))
	draw_rect(r.grow(-2), col, false, 4.0)
	draw_string(ThemeDB.fallback_font, Vector2(p.x - s / 2.0, p.y + 10), letter, HORIZONTAL_ALIGNMENT_CENTER, s, 28, Color.html("f4ead0"))
	if hp < mx:
		draw_rect(Rect2(p.x - s / 2.0, p.y + s / 2.0 + 3, s, 8), Color.BLACK)
		var fc: Color = COL.green if hp / mx > 0.5 else (Color.html("f0b429") if hp / mx > 0.25 else COL.red)
		draw_rect(Rect2(p.x - s / 2.0 + 1, p.y + s / 2.0 + 4, (s - 2) * clampf(hp / mx, 0.0, 1.0), 6), fc)
	if pulse:
		var al := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 160.0)
		draw_rect(r.grow(8), Color(1, 0.54, 0.16, al), false, 3.0)


func draw_plane(sp: Vector2, ang: float, k: float, tex: ImageTexture, shadow: bool) -> void:
	if shadow:
		draw_set_transform(sp + Vector2(2.4, 3.0) * k, ang + PI / 2.0, Vector2(k, k))
		draw_texture(spr_sh, Vector2(-5.5, -5.5), Color(1, 1, 1, 0.3))
	draw_set_transform(sp, ang + PI / 2.0, Vector2(k, k))
	draw_texture(tex, Vector2(-5.5, -5.5))
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
			draw_string_outline(f, sp - Vector2(100, 0), tw.name, HORIZONTAL_ALIGNMENT_CENTER, 200, 22, 6, Color(0.03, 0.04, 0.08, 0.85))
			draw_string(f, sp - Vector2(100, 0), tw.name, HORIZONTAL_ALIGNMENT_CENTER, 200, 22, col)
	# enemy markers
	for o in tg:
		if not o.alive:
			continue
		var p := w2s(o.x, o.y)
		if p.x < -40 or p.y < -60 or p.x > vw + 40 or p.y > vh + 40:
			continue
		var col: Color = Color.html("f0b429") if is_neutral(o) else COL.red
		var pulse: bool = sel != null and sel.order != null and sel.order.has("tg") and is_same(sel.order.tg, o)
		draw_marker(p + Vector2(0, -28), D.TYPES[o.type].L, col, o.hp, o.maxhp, pulse)
	for a in af_p:
		var p := w2s(a.x, a.y)
		if p.x < -40 or p.y < -60 or p.x > vw + 40 or p.y > vh + 100:
			continue
		draw_marker(p + Vector2(0, -50), "A", COL.blue, 1.0, 1.0, false)
	for pl in pplants:
		var p := w2s(pl.x, pl.y)
		if p.x < -40 or p.y < -60 or p.x > vw + 40 or p.y > vh + 100:
			continue
		var warn: bool = pl.warn > 0.0
		var col: Color = COL.blue
		if warn:
			col = COL.red if sin(now / 110.0) > 0.0 else Color.WHITE
		elif not pl.alive:
			col = Color(0.33, 0.33, 0.33)
		draw_marker(p + Vector2(0, -44), "!" if warn else "P", col, pl.hp if pl.alive else pl.maxhp, pl.maxhp, false)
	# selected aircraft route
	if sel != null and not sel.dead and sel.order != null and sel.order.t != "rtb":
		var tx := 0.0
		var ty := 0.0
		if sel.order.t == "attack":
			tx = sel.order.tg.x
			ty = sel.order.tg.y
		else:
			tx = sel.order.x
			ty = sel.order.y
		var a := w2s(sel.x, sel.y)
		var b := w2s(tx, ty)
		var dl := a.distance_to(b)
		var n := int(dl / 22.0)
		for i in range(n):
			if i % 2 == 0:
				var p0 := a.lerp(b, float(i) / maxf(1.0, n))
				var p1 := a.lerp(b, float(i + 1) / maxf(1.0, n))
				draw_line(p0, p1, Color(1, 0.54, 0.16, 0.9), 4.0)
		if sel.order.t == "loiter":
			draw_arc(b, 14.0 + 5.0 * sin(now / 200.0), 0.0, TAU, 24, Color(1, 0.54, 0.16, 0.9), 3.0)
	# uavs
	for u in uavs:
		var p := w2s(u.x, u.y)
		draw_set_transform(p, u.ang, Vector2(2.2, 2.2))
		draw_colored_polygon(PackedVector2Array([Vector2(7, 0), Vector2(-5, -5), Vector2(-3, 0), Vector2(-5, 5)]), Color(0.07, 0.07, 0.07))
		draw_polyline(PackedVector2Array([Vector2(7, 0), Vector2(-5, -5), Vector2(-3, 0), Vector2(-5, 5), Vector2(7, 0)]), Color.WHITE, 0.6)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var k := clampf(zoom * 2.0, 2.8, 4.4)
	for e in ea:
		draw_plane(w2s(e.x, e.y), e.ang, k, spr_e, true)
	for a in ac:
		if a.dead:
			continue
		var sp := w2s(a.x, a.y)
		if sp.x < -60 or sp.y < -60 or sp.x > vw + 60 or sp.y > vh + 60:
			continue
		var grounded: bool = a.st == "parked" or a.st == "rearm"
		draw_plane(sp, a.ang, k * (0.9 if grounded else 1.0), spr_p, not grounded)
		var is_sel: bool = sel != null and sel.id == a.id
		if is_sel:
			var r := 30.0 + 3.0 * sin(now / 180.0)
			draw_rect(Rect2(sp.x - r, sp.y - r, r * 2, r * 2), Color(1, 0.54, 0.16), false, 3.0)
		if zoom > 1.0 or is_sel:
			draw_rect(Rect2(sp.x - 14, sp.y + 24, 28, 22), Color(0.04, 0.05, 0.04, 0.8))
			draw_string(f, Vector2(sp.x - 14, sp.y + 41), str(a.n), HORIZONTAL_ALIGNMENT_CENTER, 28, 18, Color.WHITE)
	if mode != "":
		var msg := "TAP THE TARGET FOR THE BALLISTIC STRIKE" if mode == "missile" else "TAP THE TARGET FOR THE UAV"
		draw_rect(Rect2(vw / 2.0 - 300, vh * 0.3 - 26, 600, 48), Color(0.04, 0.05, 0.04, 0.85))
		draw_string(f, Vector2(vw / 2.0 - 300, vh * 0.3 + 9), msg, HORIZONTAL_ALIGNMENT_CENTER, 600, 24, COL.orange)


func _process(delta: float) -> void:
	var raw := minf(0.1, delta)
	var dt := raw * speed
	var n := maxi(1, ceili(dt / 0.03))
	for i in range(n):
		step(dt / n)
	if toast_t > 0.0:
		toast_t -= raw
		if toast_t <= 0.0 and pn_toast != null:
			pn_toast.visible = false
	hud_t -= raw
	if hud_t <= 0.0:
		hud_t = 0.15
		update_hud()
	queue_redraw()


# ====================================================================== UI construction
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
	th.default_font_size = 24
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
	th.set_font_size("font_size", "Button", 24)
	th.set_stylebox("panel", "PanelContainer", sbox(Color(0.1, 0.13, 0.09, 0.93), brass))
	th.set_color("font_color", "Label", COL.text)
	th.set_font_size("font_size", "Label", 24)
	th.set_stylebox("background", "ProgressBar", sbox(Color.html("121810"), Color.html("0a0e08"), 2))
	var fill := sbox(Color.html("3b86f0"), Color.html("3b86f0"), 0)
	th.set_stylebox("fill", "ProgressBar", fill)
	th.set_constant("separation", "VBoxContainer", 8)
	th.set_constant("separation", "HBoxContainer", 8)
	return th


func mk_label(text: String, size: int = 24, color: Color = COL.text) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func mk_button(text: String, cb: Callable, kind: String = "") -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 64)
	b.pressed.connect(cb)
	if kind == "g":
		b.add_theme_stylebox_override("normal", sbox(Color.html("2f6b2a"), Color.html("58b04a")))
		b.add_theme_stylebox_override("hover", sbox(Color.html("2f6b2a"), Color.html("58b04a")))
	elif kind == "r":
		b.add_theme_stylebox_override("normal", sbox(Color.html("4a2320"), Color.html("a8423a")))
		b.add_theme_stylebox_override("hover", sbox(Color.html("4a2320"), Color.html("a8423a")))
	return b


func mk_panel(child: Control) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_child(child)
	return p


func build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	ui_root = Control.new()
	ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.theme = make_theme()
	layer.add_child(ui_root)

	# top bar
	var top := HBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 8
	top.offset_right = -8
	top.offset_top = 8
	ui_root.add_child(top)
	var coin_row := HBoxContainer.new()
	l_coin = mk_label("250", 28, Color.html("f0c660"))
	l_inc = mk_label("+0/s", 18, COL.dim)
	coin_row.add_child(l_coin)
	coin_row.add_child(l_inc)
	var pc := mk_panel(coin_row)
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(pc)
	l_clock = mk_label("16:00", 26)
	top.add_child(mk_panel(l_clock))
	for s in [[0, "II"], [1, "1x"], [2, "2x"]]:
		var b := mk_button(s[1], _on_speed.bind(s[0]))
		b.custom_minimum_size = Vector2(62, 56)
		speed_btns[s[0]] = b
		top.add_child(b)
	blockers.append(top)

	# resources
	var res := HBoxContainer.new()
	res.set_anchors_preset(Control.PRESET_TOP_WIDE)
	res.offset_left = 8
	res.offset_right = -8
	res.offset_top = 76
	ui_root.add_child(res)
	res.add_child(mk_panel(mk_label("AZURIA", 20, COL.blue)))
	l_oil = mk_label("40 oil", 20)
	l_met = mk_label("60 metal", 20)
	l_pow = mk_label("2/2 power", 20)
	res.add_child(mk_panel(l_oil))
	res.add_child(mk_panel(l_met))
	pn_pow = mk_panel(l_pow)
	res.add_child(pn_pow)
	blockers.append(res)

	# inbound + front bar
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_TOP_WIDE)
	row.offset_left = 8
	row.offset_right = -8
	row.offset_top = 130
	ui_root.add_child(row)
	btn_inbound = mk_button("INBOUND", _on_inbound)
	btn_inbound.custom_minimum_size = Vector2(170, 84)
	row.add_child(btn_inbound)
	var fv := VBoxContainer.new()
	l_front = mk_label("Front 50%", 20, COL.dim)
	bar_front = ProgressBar.new()
	bar_front.custom_minimum_size = Vector2(0, 22)
	bar_front.show_percentage = false
	bar_front.value = 50
	fv.add_child(l_front)
	fv.add_child(bar_front)
	var fp := mk_panel(fv)
	fp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(fp)
	blockers.append(row)

	# toast
	l_toast = mk_label("", 24)
	l_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l_toast.custom_minimum_size = Vector2(560, 0)
	pn_toast = mk_panel(l_toast)
	pn_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	pn_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	pn_toast.offset_top = 236
	pn_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pn_toast.visible = false
	ui_root.add_child(pn_toast)

	# inbound log
	log_box = VBoxContainer.new()
	log_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lsc := ScrollContainer.new()
	lsc.custom_minimum_size = Vector2(560, 460)
	lsc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	lsc.add_child(log_box)
	pn_log = mk_panel(lsc)
	pn_log.set_anchors_preset(Control.PRESET_TOP_LEFT)
	pn_log.offset_left = 8
	pn_log.offset_top = 226
	pn_log.visible = false
	ui_root.add_child(pn_log)
	blockers.append(pn_log)

	# bottom stack
	var bottom := VBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.offset_left = 8
	bottom.offset_right = -8
	bottom.offset_bottom = -8
	ui_root.add_child(bottom)
	blockers.append(bottom)

	var csc := ScrollContainer.new()
	csc.custom_minimum_size = Vector2(0, 84)
	csc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	chips_box = HBoxContainer.new()
	csc.add_child(chips_box)
	bottom.add_child(csc)

	var sv := VBoxContainer.new()
	var hrow := HBoxContainer.new()
	var hv := VBoxContainer.new()
	l_sname = mk_label("Attack Aircraft", 30, COL.orange)
	l_sstat = mk_label("PARKED", 20, COL.dim)
	hv.add_child(l_sname)
	hv.add_child(l_sstat)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hrow.add_child(hv)
	var close_b := mk_button("X", func(): select(null), "r")
	close_b.custom_minimum_size = Vector2(70, 64)
	hrow.add_child(close_b)
	sv.add_child(hrow)
	l_sstats = mk_label("", 24)
	sv.add_child(l_sstats)
	bar_fuel = ProgressBar.new()
	bar_fuel.custom_minimum_size = Vector2(0, 22)
	bar_fuel.show_percentage = false
	sv.add_child(bar_fuel)
	l_armor = mk_label("Armor", 20, COL.dim)
	sv.add_child(l_armor)
	btn_rtb = mk_button("Return to base", _on_rtb)
	sv.add_child(btn_rtb)
	pn_sel = mk_panel(sv)
	bottom.add_child(pn_sel)

	var hint := mk_label("Pick an aircraft chip above, then tap an enemy marker to strike it. Tap empty ground to loiter. Drag to move the map and pinch to zoom.", 22)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pn_hint = mk_panel(hint)
	bottom.add_child(pn_hint)

	sheet_box = VBoxContainer.new()
	sheet_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sheet_scroll = ScrollContainer.new()
	sheet_scroll.custom_minimum_size = Vector2(0, 540)
	sheet_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sheet_scroll.add_child(sheet_box)
	sheet_scroll.visible = false
	bottom.add_child(sheet_scroll)

	var tabs := HBoxContainer.new()
	for tb in [["map", "Map"], ["strike", "Strike"], ["def", "Defense"], ["army", "Army"], ["pol", "Politics"]]:
		var b := mk_button(tb[1], _on_tab.bind(tb[0]))
		b.custom_minimum_size = Vector2(0, 76)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 21)
		tab_btns[tb[0]] = b
		tabs.add_child(b)
	bottom.add_child(tabs)

	# start / end overlay
	ov = Control.new()
	ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.05, 0.03, 0.85)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.add_child(shade)
	var csc2 := ScrollContainer.new()
	csc2.set_anchors_preset(Control.PRESET_FULL_RECT)
	csc2.offset_left = 20
	csc2.offset_right = -20
	csc2.offset_top = 40
	csc2.offset_bottom = -40
	csc2.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ov.add_child(csc2)
	ov_box = VBoxContainer.new()
	ov_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ov_box.add_theme_constant_override("separation", 12)
	var pc2 := mk_panel(ov_box)
	pc2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	csc2.add_child(pc2)
	ui_root.add_child(ov)
	ov.visible = false


func _on_speed(v: int) -> void:
	if over != "":
		return
	speed = v
	update_speed_buttons()


func update_speed_buttons() -> void:
	for k in speed_btns:
		speed_btns[k].modulate = Color(1, 0.85, 0.5) if k == speed else Color(1, 1, 1)


func _on_inbound() -> void:
	pn_log.visible = not pn_log.visible
	if pn_log.visible:
		unread = 0
	refresh_log()


func _on_rtb() -> void:
	if sel != null:
		sel.order = null
		give_order(sel, {"t": "rtb", "af": nearest_af(sel)})


func _on_tab(name: String) -> void:
	if not started or over != "":
		return
	set_tab("map" if (tab == name and name != "map") else name)


func set_tab(name: String) -> void:
	tab = name
	mode = ""
	if sheet_scroll == null:
		return
	var open := name != "map"
	sheet_scroll.visible = open
	pn_sel.visible = (not open) and sel != null
	pn_hint.visible = (not open) and sel == null
	for k in tab_btns:
		tab_btns[k].modulate = Color(1, 0.55, 0.45) if k == name else Color(1, 1, 1)
	sheet_sig = ""
	render_sheet()


func select(a) -> void:
	sel = a
	mode = ""
	if a != null and tab != "map":
		set_tab("map")
	if pn_sel != null:
		var open := tab != "map"
		pn_sel.visible = (not open) and a != null
		pn_hint.visible = (not open) and a == null
	update_chips()
	update_hud()


func build_chips() -> void:
	if chips_box == null:
		return
	for c in chips_box.get_children():
		c.queue_free()
	chip_btns.clear()
	for a in ac:
		var b := mk_button("No.%d" % a.n, _on_chip.bind(a.id))
		b.custom_minimum_size = Vector2(130, 76)
		chip_btns[a.id] = b
		chips_box.add_child(b)
	update_chips()


func _on_chip(id: int) -> void:
	for a in ac:
		if a.id == id:
			if sel != null and sel.id == id:
				select(null)
			else:
				select(a)
			return


const STAT_NAMES := {"parked": "Parked", "rearm": "Rearming", "takeoff": "Taking off", "fly": "In flight",
	"loiter": "Loitering", "rtb": "Returning to base", "landing": "Landing"}
const STAT_COLS := {"parked": "a0a08a", "rearm": "f0b429", "takeoff": "86d963", "fly": "ff8a2a",
	"loiter": "4d93ff", "rtb": "c9b9ff", "landing": "c9b9ff"}


func update_chips() -> void:
	for a in ac:
		if chip_btns.has(a.id):
			var b: Button = chip_btns[a.id]
			if is_instance_valid(b):
				b.text = "No.%d  %d%%" % [a.n, int(maxf(0.0, a.fuel))]
				var is_sel: bool = sel != null and sel.id == a.id
				b.add_theme_color_override("font_color", Color.html(STAT_COLS[a.st]))
				b.add_theme_color_override("font_hover_color", Color.html(STAT_COLS[a.st]))
				b.modulate = Color(1, 0.8, 0.45) if is_sel else Color(1, 1, 1)


func refresh_log() -> void:
	if log_box == null:
		return
	if pn_log.visible:
		for c in log_box.get_children():
			c.queue_free()
		if loglist.is_empty():
			log_box.add_child(mk_label("No reports yet.", 22, COL.dim))
		for e in loglist:
			var col: Color = COL.text
			if e.k == "bad":
				col = Color.html("ff9a90")
			elif e.k == "good":
				col = Color.html("a9e68c")
			var l := mk_label("%s  %s" % [tstr(e.t), e.m], 21, col)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.custom_minimum_size = Vector2(520, 0)
			log_box.add_child(l)
	btn_inbound.text = "INBOUND" if (unread == 0 or pn_log.visible) else "INBOUND (%d)" % unread


func update_hud() -> void:
	if l_coin == null:
		return
	l_coin.text = str(int(coins)) + "  "
	l_inc.text = "+%.1f/s" % income
	var h := fmod(16.0 + t / 300.0 * 24.0, 24.0)
	l_clock.text = "%02d:%02d%s" % [int(h), int((h - int(h)) * 60.0), " (night)" if night_f() > 0.25 else ""]
	l_oil.text = "%d oil" % int(oil)
	l_met.text = "%d metal" % int(metal)
	var pa := 0
	for p in pplants:
		if p.alive:
			pa += 1
	l_pow.text = "%d/2 power" % pa
	l_pow.add_theme_color_override("font_color", COL.red if pa < 2 else COL.text)
	var mean := 0.0
	for i in range(NB):
		mean += F[i]
	mean /= NB
	var lo := pcap.x + 30.0
	var hi := ecap.x - 30.0
	var prog := clampf((mean - lo) / (hi - lo), 0.0, 1.0)
	bar_front.value = prog * 100.0
	l_front.text = "Front: %d%% toward Karmin City" % int(prog * 100.0)
	tab_btns["pol"].text = "Politics (%d)" % (cases.size() + offers.size()) if (cases.size() + offers.size()) > 0 else "Politics"
	update_chips()
	if sel != null and not sel.dead:
		l_sname.text = "Attack Aircraft No.%d" % sel.n
		l_sstat.text = String(STAT_NAMES[sel.st]).to_upper()
		l_sstats.text = "FUEL %d%%   GB %d   RKT %d   AA %d" % [int(maxf(0.0, sel.fuel)), sel.gb, sel.rk, sel.aa]
		bar_fuel.value = clampf(sel.fuel, 0.0, 100.0)
		l_armor.text = "Armor  " + "#".repeat(maxi(0, sel.hp)) + "-".repeat(maxi(0, 3 - sel.hp))
		btn_rtb.disabled = sel.st == "parked" or sel.st == "rearm" or sel.st == "landing" or sel.st == "rtb"
	elif sel != null and sel.dead:
		select(null)
	render_sheet()


# ---- bottom sheet (shop and politics)
func render_sheet() -> void:
	if sheet_scroll == null or not sheet_scroll.visible:
		return
	var sig := ""
	var ok := func(k): return int(can_pay(price(k)))
	match tab:
		"strike":
			sig = "s%d,%d,%.2f,%d,%d,%d" % [ac.size(), mis, disc, ok.call("ac"), ok.call("msl"), ok.call("uav")]
		"def":
			sig = "d%d,%d,%.2f,%d,%d" % [p_ad, pplants.size(), disc, ok.call("ad"), ok.call("plant")]
		"army":
			sig = "a%d,%.2f,%d" % [brig, disc, ok.call("brig")]
		"pol":
			sig = "p"
			for c in cases:
				sig += "%s%d," % [c.n.id, c.stage]
			sig += "|"
			for o in offers:
				sig += "%s%s," % [o.n.id, o.kind]
			sig += "|"
			for n in nat:
				sig += "%d%d%d," % [int(n.mood / 10.0), int(n.war), int(n.promise > 0.0)]
			sig += "|%d" % int(coins >= 120.0)
	if sig != sheet_sig:
		sheet_sig = sig
		rebuild_sheet()
	for pair in dyn_case:
		if pair[1] < cases.size():
			var c: Dictionary = cases[pair[1]]
			if pair[2] == "b":
				pair[0].value = 100.0 * c.t / c.tm
			else:
				pair[0].text = tstr(c.t)
	for pair in dyn_offer:
		if pair[1] < offers.size():
			pair[0].text = tstr(offers[pair[1]].t)
	for l in dyn_es:
		l.text = str(int(round(estock)))
	for l in dyn_fb:
		var av := 0.0
		for i in range(NB):
			av += NET[i]
		av /= NB
		l.text = "%+.2f" % av


func money(p: Dictionary) -> String:
	var s: String = "%d coins" % p.c
	if p.m > 0:
		s += "  %d metal" % p.m
	if p.o > 0:
		s += "  %d oil" % p.o
	return s


func item_card(title: String, price_text: String, desc: String, buttons: Array) -> void:
	var v := VBoxContainer.new()
	var hr := HBoxContainer.new()
	var tl := mk_label(title, 26)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hr.add_child(tl)
	if price_text != "":
		hr.add_child(mk_label(price_text, 20, Color.html("f0c660")))
	v.add_child(hr)
	var dl := mk_label(desc, 21, COL.dim)
	dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dl.custom_minimum_size = Vector2(300, 0)
	v.add_child(dl)
	var br := HBoxContainer.new()
	for b in buttons:
		var btn := mk_button(b[0], b[1], b[2])
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if not b[3]:
			btn.modulate = Color(1, 1, 1, 0.55)
		br.add_child(btn)
	v.add_child(br)
	var p := mk_panel(v)
	p.add_theme_stylebox_override("panel", sbox(Color(0.07, 0.09, 0.06, 0.95), Color.html("3b4430"), 2))
	sheet_box.add_child(p)


func sheet_title(s: String) -> void:
	sheet_box.add_child(mk_label(s.to_upper(), 30, COL.orange))


func sheet_section(s: String) -> void:
	sheet_box.add_child(mk_label(s.to_upper(), 18, COL.dim))


func rebuild_sheet() -> void:
	for c in sheet_box.get_children():
		c.queue_free()
	dyn_case.clear()
	dyn_offer.clear()
	dyn_es.clear()
	dyn_fb.clear()
	match tab:
		"strike":
			sheet_title("Strike")
			item_card("Attack aircraft", money(price("ac")), "Fuel, guided bombs, rockets and air-to-air missiles. Hangar: %d/8" % ac.size(),
				[["Buy", _on_buy.bind("ac"), "", can_pay(price("ac"))]])
			item_card("Ballistic missile", money(price("msl")), "Wrecks power plants and bunkers. In stock: %d" % mis,
				[["Buy", _on_buy.bind("msl"), "", can_pay(price("msl"))], ["Fire", _on_fire, "", mis > 0]])
			item_card("UAV strike drone", money(price("uav")), "One-way drone with light damage. Paid when launched.",
				[["Launch", _on_uav, "", can_pay(price("uav"))]])
		"def":
			sheet_title("Defense")
			item_card("Air defense battery", money(price("ad")), "Each battery intercepts 20%% of incoming ballistic missiles and weakens enemy fighters. Deployed: %d/4" % p_ad,
				[["Buy", _on_buy.bind("ad"), "", can_pay(price("ad"))]])
			item_card("Power plant", money(price("plant")), "Our grid needs 2 working plants. Extra plants cover losses. Built: %d/4" % pplants.size(),
				[["Buy", _on_buy.bind("plant"), "", can_pay(price("plant"))]])
		"army":
			sheet_title("Army")
			item_card("Infantry brigade", money(price("brig")), "Adds front strength on every sector. Brigades: %d/6" % brig,
				[["Buy", _on_buy.bind("brig"), "", can_pay(price("brig"))]])
			var fb_l := mk_label("", 22)
			dyn_fb.append(fb_l)
			var row := HBoxContainer.new()
			row.add_child(mk_label("Front balance (positive pushes east): ", 21, COL.dim))
			row.add_child(fb_l)
			sheet_box.add_child(row)
			var nl := mk_label("Destroy enemy infantry positions (I) from the air to weaken the front.", 21, COL.dim)
			nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			nl.custom_minimum_size = Vector2(300, 0)
			sheet_box.add_child(nl)
		"pol":
			sheet_title("Politics")
			if cases.size() > 0:
				sheet_section("Diplomatic cases")
			for i in range(cases.size()):
				build_case_card(i)
			if offers.size() > 0:
				sheet_section("Requests")
			for i in range(offers.size()):
				build_offer_card(i)
			sheet_section("Nations")
			for n in nat:
				var v := VBoxContainer.new()
				var hr := HBoxContainer.new()
				var tl := mk_label(n.name, 24, n.c1)
				tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				hr.add_child(tl)
				var st := "At war" if n.war else ("Promise kept" if n.promise > 0.0 else ("Friendly" if n.mood > 60.0 else ("Neutral" if n.mood > 30.0 else "Hostile")))
				hr.add_child(mk_label(st.to_upper(), 18, COL.red if n.war else COL.dim))
				v.add_child(hr)
				var mb := ProgressBar.new()
				mb.custom_minimum_size = Vector2(0, 14)
				mb.show_percentage = false
				mb.value = n.mood
				v.add_child(mb)
				var p := mk_panel(v)
				p.add_theme_stylebox_override("panel", sbox(Color(0.07, 0.09, 0.06, 0.95), Color.html("3b4430"), 2))
				sheet_box.add_child(p)
			var es_l := mk_label("", 21)
			dyn_es.append(es_l)
			var er := HBoxContainer.new()
			er.add_child(mk_label("Enemy trade supply: ", 21, COL.dim))
			er.add_child(es_l)
			sheet_box.add_child(er)
			var note := mk_label("Sinking Karmin ships weakens its front. Sinking neutral ships causes incidents.", 20, COL.dim)
			note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			note.custom_minimum_size = Vector2(300, 0)
			sheet_box.add_child(note)


func build_case_card(i: int) -> void:
	var c: Dictionary = cases[i]
	var v := VBoxContainer.new()
	var hr := HBoxContainer.new()
	var tl := mk_label("%s · %s" % [D.STAGES[c.stage], c.n.name], 25, c.n.c1)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hr.add_child(tl)
	var tm := mk_label("", 24, Color.html("ffd27a"))
	hr.add_child(tm)
	dyn_case.append([tm, i, "t"])
	v.add_child(hr)
	var steps := HBoxContainer.new()
	for j in range(4):
		var sl := mk_label(String(D.STAGES[j]).substr(0, 7).to_upper(), 16, Color.html("1b1206") if j <= c.stage else COL.dim)
		sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var sp := PanelContainer.new()
		sp.add_theme_stylebox_override("panel", sbox(Color.html("d9822b") if j <= c.stage else Color.html("2c3126"), Color(0, 0, 0, 0), 0))
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sp.add_child(sl)
		steps.add_child(sp)
	v.add_child(steps)
	var cm := mk_label("Stop sinking our ships. Incidents: %d" % c.n.inc, 21, COL.dim)
	cm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cm.custom_minimum_size = Vector2(300, 0)
	v.add_child(cm)
	var tb := ProgressBar.new()
	tb.custom_minimum_size = Vector2(0, 12)
	tb.show_percentage = false
	tb.add_theme_stylebox_override("fill", sbox(Color.html("f0b429"), Color.html("f0b429"), 0))
	v.add_child(tb)
	dyn_case.append([tb, i, "b"])
	var br := HBoxContainer.new()
	for b in [["Stop", "stop", "g", true], ["Pay 120", "pay", "", coins >= 120.0], ["Refuse", "refuse", "r", true]]:
		var btn := mk_button(b[0], _on_case.bind(i, b[1]), b[2])
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if not b[3]:
			btn.modulate = Color(1, 1, 1, 0.55)
		br.add_child(btn)
	v.add_child(br)
	var p := mk_panel(v)
	p.add_theme_stylebox_override("panel", sbox(Color(0.1, 0.07, 0.04, 0.95), Color.html("c0392b") if c.stage >= 2 else Color.html("8a5a22"), 3))
	sheet_box.add_child(p)


func build_offer_card(i: int) -> void:
	var o: Dictionary = offers[i]
	var v := VBoxContainer.new()
	var hr := HBoxContainer.new()
	var tl := mk_label("%s · %s" % ["Trade request" if o.kind == "sell" else "Trade treaty", o.n.name], 25, o.n.c1)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hr.add_child(tl)
	var tm := mk_label("", 24, Color.html("ffd27a"))
	hr.add_child(tm)
	dyn_offer.append([tm, i])
	v.add_child(hr)
	var txt := "Buys metal x%d for %d coins" % [o.q, o.coins] if o.kind == "sell" else "Purchases cost 10% less for 2:30"
	var cm := mk_label(txt, 21, COL.dim)
	cm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cm.custom_minimum_size = Vector2(300, 0)
	v.add_child(cm)
	var br := HBoxContainer.new()
	var b1 := mk_button("Accept", _on_offer.bind(i, "ok"), "g")
	var b2 := mk_button("Decline", _on_offer.bind(i, "no"), "r")
	b1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	br.add_child(b1)
	br.add_child(b2)
	v.add_child(br)
	var p := mk_panel(v)
	p.add_theme_stylebox_override("panel", sbox(Color(0.07, 0.09, 0.06, 0.95), Color.html("8a5a22"), 3))
	sheet_box.add_child(p)


func _on_buy(k: String) -> void:
	if started and over == "":
		buy(k)
		sheet_sig = ""
		render_sheet()


func _on_fire() -> void:
	if mis <= 0:
		toast("No ballistic missiles in stock")
		return
	set_tab("map")
	mode = "missile"


func _on_uav() -> void:
	if not can_pay(price("uav")):
		toast("Not enough resources")
		return
	set_tab("map")
	mode = "uav"


func _on_case(i: int, act: String) -> void:
	case_act(i, act)
	render_sheet()


func _on_offer(i: int, act: String) -> void:
	offer_act(i, act)
	render_sheet()


# ---- start and end screens
func show_overlay() -> void:
	for c in ov_box.get_children():
		c.queue_free()
	ov.visible = true
	if not started:
		ov_box.add_child(mk_label(D.INTRO_TITLE, 44, COL.orange))
		var sub := mk_label(D.INTRO_SUB, 22, COL.dim)
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sub.custom_minimum_size = Vector2(560, 0)
		ov_box.add_child(sub)
		for line in D.INTRO:
			var l := mk_label("■  " + String(line), 22)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.custom_minimum_size = Vector2(560, 0)
			ov_box.add_child(l)
		var lg := mk_label(D.LEGEND, 20, COL.dim)
		lg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lg.custom_minimum_size = Vector2(560, 0)
		ov_box.add_child(lg)
		var go := mk_button("START MISSION", _on_start)
		go.custom_minimum_size = Vector2(0, 84)
		go.add_theme_font_size_override("font_size", 30)
		ov_box.add_child(go)
	else:
		var win := over == "win"
		ov_box.add_child(mk_label("Victory" if win else "Defeat", 44, COL.orange))
		ov_box.add_child(mk_label("Karmin City has fallen." if win else "Azuria City has fallen.", 24, COL.dim))
		ov_box.add_child(mk_label("Time: %s\nTargets destroyed: %d\nAircraft lost: %d" % [tstr(t), kills, lost], 24))
		ov_box.add_child(standings())
		var again := mk_button("PLAY AGAIN", _on_again)
		again.custom_minimum_size = Vector2(0, 84)
		ov_box.add_child(again)


func _on_start() -> void:
	started = true
	ov.visible = false
	toast("Pick an aircraft and then a target")


func _on_again() -> void:
	new_game()
	started = true
	ov.visible = false
	update_speed_buttons()
	refresh_log()
	update_hud()


func standings() -> Control:
	var covered := 0.0
	for i in range(NB):
		covered += F[i]
	var lo := pcap.x + 30.0
	var hi := ecap.x - 30.0
	var prog := clampf((covered / NB - lo) / (hi - lo), 0.0, 1.0)
	var rows: Array = []
	rows.append({"n": "Azuria (you)", "e": int(earned * 6.0 + coins * 2.0), "w": maxi(0, kills * 150 - lost * 40 + (2500 if over == "win" else 0)), "me": true})
	rows.append({"n": "Karmin", "e": 3500 + int((1.0 - prog) * 5200.0), "w": 1800 + int((1.0 - prog) * 4200.0), "me": false})
	for n in nat:
		rows.append({"n": n.name, "e": 2200 + int(n.mood * 18.0), "w": 900 if n.war else 200, "me": false})
	for r in rows:
		r["t"] = r.e + r.w
	rows.sort_custom(func(a, b): return a.t > b.t)
	var g := GridContainer.new()
	g.columns = 4
	g.add_theme_constant_override("h_separation", 16)
	for h in ["Country", "Economy", "War", "Total"]:
		g.add_child(mk_label(h, 20, COL.dim))
	for r in rows:
		var col: Color = COL.orange if r.me else COL.text
		g.add_child(mk_label(r.n, 22, col))
		g.add_child(mk_label(str(r.e), 22, col))
		g.add_child(mk_label(str(r.w), 22, col))
		g.add_child(mk_label(str(r.t), 22, col))
	return g
