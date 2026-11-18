extends Node2D
## Flipperbrott: a brick breaker on a pinball table.
## Break the bricks at the top with a paddle; if the ball gets past it, two flippers, slingshots and
## bumpers give it another chance. Balls are shot in from a spring lane on the right.

const W := 720.0
const H := 1280.0
const R := 11.0               # ball radius
const G := 900.0              # gravity
const MAXV := 2700.0
const SUB := 10
const PY := 880.0             # paddle top
const FL_LEN := 104.0
const FL_REST := 0.5
const FL_UP := 0.5
const BCOLS := 11
const BROWS := 10
const BW_ := 50.0
const BH_ := 24.0
const BX0 := 60.0
const BY0 := 170.0
const LANE_X := 630.0
const PLUNGER_Y := 1215.0
const SAVE := "user://save.cfg"

const BRICK_COLORS := {
	"r": Color(1.0, 0.32, 0.38), "o": Color(1.0, 0.6, 0.22), "y": Color(1.0, 0.86, 0.26),
	"g": Color(0.35, 1.0, 0.5), "c": Color(0.25, 0.9, 1.0), "b": Color(0.32, 0.52, 1.0),
	"p": Color(0.78, 0.42, 1.0), "w": Color(0.95, 0.95, 1.0), "s": Color(0.74, 0.77, 0.85), "G": Color(1.0, 0.76, 0.28),
}
const POWERS := {
	"M": ["Multiboll", Color(0.35, 0.6, 1.0)],
	"B": ["Bred paddel", Color(0.35, 1.0, 0.5)],
	"E": ["Eldboll", Color(1.0, 0.4, 0.2)],
	"L": ["Laser", Color(1.0, 0.35, 0.8)],
	"S": ["Skydd", Color(0.3, 0.95, 1.0)],
	"+": ["Extra boll", Color(1, 1, 1)],
}
const LEVELS := [
	["rrrrrrrrrrr", "ooooooooooo", "yyyyyyyyyyy", "ggggggggggg", "ccccccccccc", "bbbbbbbbbbb"],
	[".....w.....", "....ppp....", "...bbbbb...", "..ccccccc..", ".ggggggggg.", "yyyyyyyyyyy", "s.s.s.s.s.s"],
	["G.........G", "rrrr...oooo", "rsrr...osoo", "rrrr...oooo", "...........", "..bbbbbbb..", "..bsbsbsb..", "..bbbbbbb.."],
	["..g.....g..", "...g...g...", "..ccccccc..", ".cc.ccc.cc.", "ccccscccccc", "c.ccccccc.c", "c.c.....c.c", "...cc.cc..."],
	["r.o.y.g.c.b", ".o.y.g.c.b.", "o.y.g.c.b.p", ".y.g.c.b.p.", "y.g.c.b.p.w", "GGG.....GGG"],
	["..rr...rr..", ".rrrr.rrrr.", "rrrrrrrrrrr", "rrrwrrrwrrr", ".rrrrrrrrr.", "..rrrrrrr..", "...rrrrr...", "....rrr....", ".....r....."],
	["GsG.....GsG", "sss.....sss", "bbbbbbbbbbb", "b.........b", "b.yyyyyyy.b", "b.y.....y.b", "b.y.ppp.y.b", "bGGGG.GGGGb"],
	["wpwpwpwpwpw", "pspspspspsp", "wpwpwpwpwpw", "...........", "ooo.ooo.ooo", "oso.oso.oso", "ooo.ooo.ooo"],
]

var state := "title"
var t := 0.0
var rng := RandomNumberGenerator.new()

# table geometry
var segs: Array = []     # {a, b, e, kind, id}
var posts: Array = []    # {p, r, e, kind, id}
var gate_a := Vector2(LANE_X, 400)
var gate_b := Vector2(680, 368)
var flippers: Array = [] # {piv, a, rest, up, w, side}
var lights := [false, false, false, false]
var rollover_pos := [Vector2(70, 1000), Vector2(122, 1000), Vector2(548, 1000), Vector2(600, 1000)]
var roll_inside := {}
var flash := {}          # id -> time left

# play state
var balls: Array = []    # {p, v, trail, lane, still}
var bricks: Array = []   # BROWS*BCOLS of null or {k, hp, f}
var caps: Array = []     # {p, k}
var shots: Array = []
var paddle_x := 335.0
var paddle_w := 110.0
var mouse_target := -1.0
var power := {}          # kind -> time left
var plunger := 0.0
var charging := false
var save_t := 0.0
var score := 0
var level := 1
var lives := 3
var mult := 1
var best := 0
var new_best := false
var over_t := 0.0
var clear_t := 0.0
var laser_t := 0.0
var demo_t := 0.0
var autoplay := false  # used by the attract mode logic in tests

# fx
var parts: Array = []
var texts: Array = []
var shake := 0.0
var banner := ""
var banner_sub := ""
var banner_t := 0.0

# input
var held := {}
var prev := {}
var touch_mode := false
var touch_map := {}      # finger -> "left"/"right"/"paddle"
var tap := false
var tap_pos := Vector2.ZERO

var bg_node: Node2D
var game_node: Node2D
var glow_node: Node2D
var hud_node: Node2D
var glow_tex: Texture2D
var music: AudioStreamPlayer
var sfx := {}
var muted := false
var stars: Array = []


func _ready() -> void:
	rng.randomize()
	_setup_input()
	_load()
	_build_table()
	var gt := GradientTexture2D.new()
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.35, Color(1, 1, 1, 0.45))
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 64
	gt.height = 64
	glow_tex = gt
	bg_node = _layer(-5, _draw_bg)
	game_node = _layer(0, _draw_game)
	glow_node = _layer(1, _draw_glow)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow_node.material = mat
	var cl := CanvasLayer.new()
	cl.layer = 5
	add_child(cl)
	hud_node = preload("res://drawer.gd").new()
	hud_node.fn = _draw_hud
	cl.add_child(hud_node)
	music = AudioStreamPlayer.new()
	add_child(music)
	for n in ["flip", "bumper", "sling", "brick", "metal", "gold", "paddle", "wall", "power", "laser", "launch",
			"drain", "save", "rollover", "lights", "clear", "multi", "extra", "over", "start", "music"]:
		var s: AudioStreamWAV = load("res://assets/sfx/%s.wav" % n)
		if n == "music":
			s.loop_mode = AudioStreamWAV.LOOP_FORWARD
			s.loop_end = s.data.size() / 2
			music.stream = s
			music.volume_db = -10.0
			continue
		var a := AudioStreamPlayer.new()
		a.stream = s
		a.max_polyphony = 5
		add_child(a)
		sfx[n] = a
	music.play()
	AudioServer.set_bus_mute(0, muted)
	for i in 90:
		stars.append([Vector2(rng.randf_range(-300, 1020), rng.randf_range(-300, 1580)), rng.randf_range(0.6, 2.0), rng.randf() * TAU])
	touch_mode = DisplayServer.is_touchscreen_available()
	_demo_start()
	get_viewport().size_changed.connect(_layout)
	_layout()


func _layer(z: int, f: Callable) -> Node2D:
	var n: Node2D = preload("res://drawer.gd").new()
	n.fn = f
	n.z_index = z
	add_child(n)
	return n


func _layout() -> void:
	var vs := get_viewport_rect().size
	position = Vector2(roundf((vs.x - W) * 0.5), roundf((vs.y - H) * 0.5))


func _setup_input() -> void:
	var keys := {
		"left": [KEY_LEFT, KEY_A], "right": [KEY_RIGHT, KEY_D],
		"fl": [KEY_SHIFT, KEY_Z, KEY_CTRL], "fr": [KEY_X, KEY_PERIOD, KEY_MINUS, KEY_ALT],
		"launch": [KEY_SPACE, KEY_DOWN, KEY_ENTER], "pause": [KEY_ESCAPE, KEY_P],
	}
	var pads := {
		"left": [JOY_BUTTON_DPAD_LEFT], "right": [JOY_BUTTON_DPAD_RIGHT],
		"fl": [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_X], "fr": [JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_B],
		"launch": [JOY_BUTTON_A, JOY_BUTTON_DPAD_DOWN], "pause": [JOY_BUTTON_START],
	}
	for a in keys:
		if not InputMap.has_action(a):
			InputMap.add_action(a, 0.4)
		for k in keys[a]:
			var e := InputEventKey.new()
			e.physical_keycode = k
			InputMap.action_add_event(a, e)
		for b in pads[a]:
			var j := InputEventJoypadButton.new()
			j.button_index = b
			InputMap.action_add_event(a, j)
	for pair in [["left", JOY_AXIS_LEFT_X, -1.0], ["right", JOY_AXIS_LEFT_X, 1.0], ["fl", JOY_AXIS_TRIGGER_LEFT, 1.0], ["fr", JOY_AXIS_TRIGGER_RIGHT, 1.0]]:
		var m := InputEventJoypadMotion.new()
		m.axis = pair[1]
		m.axis_value = pair[2]
		InputMap.action_add_event(pair[0], m)
	# right-shift is a separate key on most keyboards; physical keycode only knows SHIFT, so also map by keycode
	var rs := InputEventKey.new()
	rs.keycode = KEY_SHIFT
	rs.location = KEY_LOCATION_RIGHT
	InputMap.action_add_event("fr", rs)


func _load() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE) == OK:
		best = cf.get_value("s", "best", 0)
		muted = cf.get_value("s", "muted", false)


func _save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("s", "best", best)
	cf.set_value("s", "muted", muted)
	cf.save(SAVE)


func _snd(n: String, pitch := 1.0) -> void:
	var a: AudioStreamPlayer = sfx.get(n)
	if a:
		a.pitch_scale = pitch
		a.play()


# ---------------------------------------------------------------- table
func _seg(a: Vector2, b: Vector2, e := 0.5, kind := "wall", id := "") -> void:
	segs.append({"a": a, "b": b, "e": e, "kind": kind, "id": id})


func _arc(c: Vector2, r: float, a0: float, a1: float, n: int) -> void:
	var prevp := c + Vector2.from_angle(a0) * r
	for i in range(1, n + 1):
		var p := c + Vector2.from_angle(lerpf(a0, a1, float(i) / n)) * r
		_seg(prevp, p)
		prevp = p


func _build_table() -> void:
	segs.clear()
	posts.clear()
	# outer walls and the rounded top corners
	_seg(Vector2(40, 210), Vector2(40, 1300))
	_arc(Vector2(140, 210), 100, PI, PI * 1.5, 10)
	_seg(Vector2(140, 110), Vector2(580, 110))
	_arc(Vector2(580, 210), 100, PI * 1.5, TAU, 10)
	_seg(Vector2(680, 210), Vector2(680, 1300))
	# spring lane
	_seg(Vector2(LANE_X, 400), Vector2(LANE_X, 1300))
	_seg(Vector2(LANE_X, PLUNGER_Y), Vector2(680, PLUNGER_Y), 0.1, "plunger")
	# inlane guides, slingshots (mirrored about x = 335)
	for side in [1, -1]:
		var m := func(p: Vector2) -> Vector2: return p if side == 1 else Vector2(670.0 - p.x, p.y)
		_seg(m.call(Vector2(100, 960)), m.call(Vector2(100, 1062)))
		_seg(m.call(Vector2(100, 1062)), m.call(Vector2(203, 1122)))
		posts.append({"p": m.call(Vector2(100, 960)), "r": 6.0, "e": 0.5, "kind": "post", "id": ""})
		var sid := "slingL" if side == 1 else "slingR"
		var A: Vector2 = m.call(Vector2(145, 950))
		var B: Vector2 = m.call(Vector2(145, 1040))
		var C: Vector2 = m.call(Vector2(198, 1072))
		_seg(A, B)
		_seg(B, C)
		_seg(A, C, 0.6, "sling", sid)
		posts.append({"p": A, "r": 6.0, "e": 0.5, "kind": "post", "id": ""})
		posts.append({"p": C, "r": 6.0, "e": 0.5, "kind": "post", "id": ""})
	posts.append({"p": Vector2(125, 700), "r": 28.0, "e": 0.8, "kind": "bumper", "id": "b0"})
	posts.append({"p": Vector2(545, 700), "r": 28.0, "e": 0.8, "kind": "bumper", "id": "b1"})
	posts.append({"p": Vector2(335, 590), "r": 22.0, "e": 0.8, "kind": "bumper", "id": "b2"})
	flippers = [
		{"piv": Vector2(215, 1130), "a": FL_REST, "rest": FL_REST, "up": -FL_UP, "w": 0.0, "side": 0},
		{"piv": Vector2(455, 1130), "a": PI - FL_REST, "rest": PI - FL_REST, "up": PI + FL_UP, "w": 0.0, "side": 1},
	]


func _load_level(n: int) -> void:
	bricks.clear()
	bricks.resize(BCOLS * BROWS)
	var rows: Array
	if n - 1 < LEVELS.size():
		rows = LEVELS[n - 1]
	else:
		rows = _random_level(n)
	for r in rows.size():
		var row: String = rows[r]
		for c in BCOLS:
			var k := row[c]
			if k == ".":
				continue
			var hp := 1
			if k == "s":
				hp = 2 + n / 4
			elif k == "G":
				hp = -1
			bricks[r * BCOLS + c] = {"k": k, "hp": hp, "f": 0.0}


func _random_level(n: int) -> Array:
	var rows: Array = []
	var nrows := rng.randi_range(6, BROWS)
	var cols := "roygcbpw"
	for r in nrows:
		var half := ""
		var col := cols[rng.randi_range(0, cols.length() - 1)]
		for c in 6:
			var x := rng.randf()
			if x < 0.18:
				half += "."
			elif x < 0.18 + minf(0.04 * n, 0.3):
				half += "s"
			elif x < 0.24 + minf(0.04 * n, 0.3) and r < 3:
				half += "G"
			else:
				half += col
		var full := half + half.substr(0, 5).reverse()
		rows.append(full)
	return rows


func _bricks_left() -> int:
	var n := 0
	for b in bricks:
		if b != null and b.hp > 0:
			n += 1
	return n


func _brick_rect(i: int) -> Rect2:
	return Rect2(BX0 + (i % BCOLS) * BW_, BY0 + (i / BCOLS) * BH_, BW_, BH_)


# ---------------------------------------------------------------- game flow
func _new_game() -> void:
	score = 0
	level = 1
	lives = 3
	new_best = false
	_start_level()


func _start_level() -> void:
	_load_level(level)
	balls.clear()
	caps.clear()
	shots.clear()
	power.clear()
	paddle_w = 110.0
	lights = [false, false, false, false]
	mult = 1
	_new_ball_in_lane()


func _new_ball_in_lane() -> void:
	balls.append({"p": Vector2(655, PLUNGER_Y - R), "v": Vector2.ZERO, "trail": [], "lane": true, "still": 0.0})
	plunger = 0.0
	charging = false


func _start() -> void:
	state = "play"
	_new_game()
	_snd("start")
	_banner("BANA 1", "Håll in en flipperknapp och släpp för att skjuta ut kulan")


func _demo_start() -> void:
	level = rng.randi_range(1, LEVELS.size())
	_load_level(level)
	level = 1
	balls.clear()
	caps.clear()
	shots.clear()
	power.clear()
	balls.append({"p": Vector2(335, 700), "v": Vector2(rng.randf_range(-300, 300), -1300), "trail": [], "lane": false, "still": 0.0})


func _banner(a: String, b := "") -> void:
	banner = a
	banner_sub = b
	banner_t = 2.6


func _game_over() -> void:
	state = "over"
	over_t = 0.0
	if score > best:
		best = score
		new_best = true
	_save()
	_snd("over")


func _add(pts: int) -> void:
	score += pts * mult


# ---------------------------------------------------------------- input
func _held(a: String) -> bool:
	return held.get(a, false)


func _jp(a: String) -> bool:
	return held.get(a, false) and not prev.get(a, false)


func _poll_input() -> void:
	prev = held.duplicate()
	for a in ["left", "right", "fl", "fr", "launch", "pause"]:
		held[a] = Input.is_action_pressed(a)
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not touch_mode:
		held["fl"] = true
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and not touch_mode:
		held["fr"] = true
	for f in touch_map:
		var z: String = touch_map[f]
		if z == "left":
			held["fl"] = true
		elif z == "right":
			held["fr"] = true


func _flip_zone_y() -> float:
	return get_viewport_rect().size.y * 0.8


func _touch_zone(p: Vector2) -> String:
	var vs := get_viewport_rect().size
	if p.x > vs.x - 90 and p.y < 120:
		return "pause"
	if p.y >= _flip_zone_y():
		return "left" if p.x < vs.x * 0.5 else "right"
	return "paddle"


func _input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		touch_mode = true
		if e.pressed:
			if state != "play":
				tap = true
				tap_pos = e.position
				return
			var z := _touch_zone(e.position)
			if z == "pause":
				state = "pause"
				touch_map.clear()
				return
			touch_map[e.index] = z
			if z == "paddle":
				mouse_target = e.position.x - position.x
		else:
			touch_map.erase(e.index)
	elif e is InputEventScreenDrag:
		if touch_map.get(e.index, "") == "paddle":
			mouse_target = e.position.x - position.x
	elif e is InputEventMouseMotion and not touch_mode:
		mouse_target = e.position.x - position.x
	elif e is InputEventMouseButton and e.pressed:
		if state != "play":
			tap = true
			tap_pos = e.position
	elif e is InputEventKey and e.pressed and not e.echo:
		touch_mode = false
		if e.physical_keycode == KEY_M:
			muted = not muted
			AudioServer.set_bus_mute(0, muted)
			_save()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if state == "play":
			state = "pause"
		elif state in ["pause", "over"]:
			state = "title"
			_demo_start()
		else:
			get_tree().quit()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT and state == "play":
		state = "pause"


func _menu_buttons() -> Array:
	var vs := get_viewport_rect().size
	var cx := vs.x * 0.5
	var cy := vs.y * 0.5
	if state == "pause":
		return [["resume", Rect2(cx - 160, cy - 20, 320, 72)], ["menu", Rect2(cx - 160, cy + 72, 320, 72)], ["mute", Rect2(cx - 160, cy + 164, 320, 60)]]
	if state == "title":
		return [["mute", Rect2(vs.x - 200, 20, 180, 56)]]
	return []


func _menu_hit(p: Vector2) -> String:
	for b in _menu_buttons():
		if b[1].has_point(p):
			return b[0]
	return ""


# ---------------------------------------------------------------- main loop
func _process(delta: float) -> void:
	var dt := minf(delta, 1.0 / 30.0)
	t += dt
	_poll_input()
	_update_fx(dt)
	var tapped := tap
	tap = false
	match state:
		"title":
			_auto_play(dt)
			_physics(dt)
			if balls.is_empty() or _bricks_left() == 0:
				_demo_start()
			var m := _menu_hit(tap_pos) if tapped else ""
			if m == "mute":
				muted = not muted
				AudioServer.set_bus_mute(0, muted)
				_save()
			elif tapped or _jp("launch"):
				_start()
		"pause":
			var m := _menu_hit(tap_pos) if tapped else ""
			if m == "resume" or _jp("pause") or _jp("launch"):
				state = "play"
				touch_map.clear()
			elif m == "menu" or Input.is_physical_key_pressed(KEY_Q):
				state = "title"
				_demo_start()
			elif m == "mute":
				muted = not muted
				AudioServer.set_bus_mute(0, muted)
				_save()
		"over":
			over_t += dt
			_physics(dt)
			if over_t > 1.2 and (tapped or _jp("launch")):
				_start()
			elif over_t > 1.2 and _jp("pause"):
				state = "title"
				_demo_start()
		"clear":
			clear_t -= dt
			if clear_t <= 0.0:
				level += 1
				state = "play"
				_start_level()
				_banner("BANA %d" % level, "")
		"play":
			if _jp("pause"):
				state = "pause"
				return
			if autoplay:
				_auto_play(dt)
			_update_play(dt)
	for n: Node2D in [bg_node, game_node, glow_node, hud_node]:
		n.queue_redraw()


func _auto_play(dt: float) -> void:
	## Attract mode: the paddle tracks the ball and flippers fire when the ball is near.
	held["fl"] = false
	held["fr"] = false
	if balls.is_empty():
		return
	var b: Dictionary = balls[0]
	if b.lane:
		held["launch"] = fmod(t, 1.6) < 0.9
		return
	held["launch"] = false
	mouse_target = clampf(b.p.x + sin(t) * 20.0, 100, 570)
	for f in flippers:
		var tip: Vector2 = f.piv + Vector2.from_angle(f.rest) * FL_LEN * 0.6
		if b.p.distance_to(tip) < 70 and b.v.y > -100:
			held["fl" if f.side == 0 else "fr"] = true


func _update_play(dt: float) -> void:
	save_t = maxf(0.0, save_t - dt)
	for k in power.keys():
		power[k] -= dt
		if power[k] <= 0.0:
			power.erase(k)
	paddle_w = move_toward(paddle_w, 170.0 if power.has("B") else 110.0, 200.0 * dt)
	# spring
	var lane_ball: Dictionary = {}
	for b in balls:
		if b.lane:
			lane_ball = b
	var want := _held("launch") or _held("fl") or _held("fr")
	if not lane_ball.is_empty() and lane_ball.p.y > PLUNGER_Y - R - 30:
		if want:
			charging = true
			plunger = minf(1.0, plunger + dt * 1.2)
		elif charging:
			charging = false
			lane_ball.v = Vector2(0, -(1550.0 + 1050.0 * plunger))
			lane_ball.p.y = PLUNGER_Y - R - 2
			plunger = 0.0
			save_t = 9.0
			_snd("launch")
	else:
		charging = false
		plunger = move_toward(plunger, 0.0, dt * 6.0)
	# flippers: lane-change the lights on each press, like on a real table
	if _jp("fl") and lane_ball.is_empty():
		lights = [lights[1], lights[2], lights[3], lights[0]]
		_snd("flip")
	if _jp("fr") and lane_ball.is_empty():
		lights = [lights[3], lights[0], lights[1], lights[2]]
		_snd("flip")
	# lasers
	if power.has("L"):
		laser_t -= dt
		if laser_t <= 0.0:
			laser_t = 0.28
			shots.append(Vector2(paddle_x - paddle_w * 0.5 + 8, PY - 4))
			shots.append(Vector2(paddle_x + paddle_w * 0.5 - 8, PY - 4))
			_snd("laser")
	_physics(dt)
	# capsules
	for c in caps:
		c.p.y += 170.0 * dt
		var got := Rect2(paddle_x - paddle_w * 0.5, PY - 6, paddle_w, 20).grow(12).has_point(c.p)
		for b in balls:
			if b.p.distance_to(c.p) < R + 16:
				got = true
		if got:
			_power(c.k, c.p)
			c.p.y = 9999.0
	caps = caps.filter(func(c: Dictionary) -> bool: return c.p.y < H + 40)
	# drained balls
	var kept: Array = []
	for b in balls:
		if b.p.y > H + 20 or b.p.x < 0 or b.p.x > W:
			continue
		kept.append(b)
	if kept.size() < balls.size():
		balls = kept
		if balls.is_empty():
			if save_t > 0.0 or power.has("S"):
				_new_ball_in_lane()
				_text("KULAN RÄDDAD!", Vector2(335, 1000), Color(0.4, 1, 0.9), 34)
				_snd("save")
				save_t = 0.0
			else:
				lives -= 1
				mult = 1
				lights = [false, false, false, false]
				power.clear()
				caps.clear()
				_snd("drain")
				shake = 8.0
				if lives <= 0:
					_game_over()
				else:
					_new_ball_in_lane()
					_banner("KULA FÖRLORAD", "%d kvar" % lives)
	if state == "play" and _bricks_left() == 0:
		state = "clear"
		clear_t = 2.4
		var bonus := 2000 * level
		score += bonus
		_snd("clear")
		_banner("BANAN KLAR!", "Bonus %d" % bonus)


func _power(k: String, p: Vector2) -> void:
	_snd("power")
	_text(POWERS[k][0].to_upper() + "!", p, POWERS[k][1], 26)
	match k:
		"M":
			var src: Array = balls.filter(func(b: Dictionary) -> bool: return not b.lane)
			if src.is_empty():
				return
			var b0: Dictionary = src[0]
			for i in 2:
				var v: Vector2 = b0.v.rotated((i * 2 - 1) * 0.5)
				if v.length() < 600:
					v = Vector2(0, -900).rotated((i * 2 - 1) * 0.4)
				balls.append({"p": b0.p, "v": v, "trail": [], "lane": false, "still": 0.0})
			_snd("multi")
		"+":
			lives += 1
			_snd("extra")
		"B":
			power["B"] = 20.0
		"E":
			power["E"] = 10.0
		"L":
			power["L"] = 10.0
			laser_t = 0.0
		"S":
			power["S"] = 15.0


# ---------------------------------------------------------------- physics
func _physics(dt: float) -> void:
	# paddle
	var target := paddle_x
	if _held("left"):
		target -= 900.0 * dt
		mouse_target = -1.0
	elif _held("right"):
		target += 900.0 * dt
		mouse_target = -1.0
	elif mouse_target >= 0.0:
		target = move_toward(paddle_x, mouse_target, 1800.0 * dt)
	paddle_x = clampf(target, 40.0 + paddle_w * 0.5, LANE_X - paddle_w * 0.5)
	# laser shots
	for i in range(shots.size() - 1, -1, -1):
		shots[i].y -= 1300.0 * dt
		var bi := _brick_at(shots[i])
		if bi >= 0:
			_hit_brick(bi, false)
			shots.remove_at(i)
		elif shots[i].y < 110:
			shots.remove_at(i)
	var h := dt / SUB
	for s in SUB:
		for f in flippers:
			var on: bool = _held("fl") if f.side == 0 else _held("fr")
			var goal: float = f.up if on else f.rest
			var old: float = f.a
			f.a = move_toward(f.a, goal, (30.0 if on else 16.0) * h)
			f.w = (f.a - old) / h
		for b in balls:
			_step_ball(b, h)
		for i in balls.size():
			for j in range(i + 1, balls.size()):
				_ball_ball(balls[i], balls[j])
	for b in balls:
		b.trail.push_back(b.p)
		if b.trail.size() > 10:
			b.trail.pop_front()
		if b.v.length() < 40.0 and not b.lane:
			b.still += dt
			if b.still > 3.0:
				b.v = Vector2(rng.randf_range(-300, 300), -500)
				b.still = 0.0
		else:
			b.still = 0.0


func _step_ball(b: Dictionary, h: float) -> void:
	if b.lane and b.v == Vector2.ZERO:
		b.p = Vector2(655, PLUNGER_Y - R + plunger * 34.0)
		return
	b.v.y += G * h
	b.p += b.v * h
	if b.lane and b.p.x < LANE_X - R:
		b.lane = false
	# walls and slingshots
	for s in segs:
		if s.kind == "plunger" and not b.lane:
			continue
		var n := _hit_seg(b, s.a, s.b, s.e)
		if n != Vector2.ZERO and s.kind == "sling":
			b.v += n * 650.0
			flash[s.id] = 0.15
			_add(20)
			_snd("sling")
	# one-way gate at the top of the spring lane
	if not b.lane:
		var q := Geometry2D.get_closest_point_to_segment(b.p, gate_a, gate_b)
		var d: Vector2 = b.p - q
		var nup := (gate_b - gate_a).normalized().rotated(-PI * 0.5)
		if d.length() < R and d.dot(nup) > -2.0:
			b.p = q + nup * R
			var vn: float = b.v.dot(nup)
			if vn < 0.0:
				b.v -= 1.5 * vn * nup
	elif b.p.y < 380 and b.v.y > 0.0 and b.p.x > LANE_X:
		b.lane = false
	# posts and bumpers
	for p in posts:
		var d: Vector2 = b.p - p.p
		var dist := d.length()
		if dist < R + p.r and dist > 0.001:
			var n := d / dist
			b.p = p.p + n * (R + p.r)
			var vn: float = b.v.dot(n)
			if vn < 0.0:
				b.v -= (1.0 + p.e) * vn * n
			if p.kind == "bumper":
				var out: float = b.v.dot(n)
				if out < 850.0:
					b.v += n * (850.0 - out)
				flash[p.id] = 0.18
				_add(100)
				_snd("bumper", rng.randf_range(0.95, 1.08))
				shake = maxf(shake, 2.0)
				for k in 6:
					_part(p.p + n * p.r, n.rotated(rng.randf_range(-1, 1)) * rng.randf_range(100, 300), Color(1, 0.8, 0.3), 0.35, 3)
	# flippers
	for f in flippers:
		_hit_flipper(b, f)
	# paddle (one-way: only stops a ball on its way down)
	var half := paddle_w * 0.5
	if b.v.y > 0.0 and b.p.y + R >= PY and b.p.y < PY + 10.0 and absf(b.p.x - paddle_x) <= half + R * 0.6:
		var off := clampf((b.p.x - paddle_x) / half, -1.0, 1.0)
		var sp := clampf(b.v.length(), 1150.0, 1600.0)
		b.v = Vector2(sin(off * 1.05), -cos(off * 1.05)) * sp
		b.p.y = PY - R
		_snd("paddle", 1.0 + off * 0.1)
	# protective barrier
	if power.has("S") and b.p.y + R > 1250.0 and b.v.y > 0.0:
		b.v.y = -maxf(b.v.y, 1300.0)
		b.p.y = 1250.0 - R
		_snd("paddle", 1.4)
	# bricks
	var c0 := int((b.p.x - R - BX0) / BW_)
	var c1 := int((b.p.x + R - BX0) / BW_)
	var r0 := int((b.p.y - R - BY0) / BH_)
	var r1 := int((b.p.y + R - BY0) / BH_)
	var done := false
	for r in range(maxi(r0, 0), mini(r1, BROWS - 1) + 1):
		for c in range(maxi(c0, 0), mini(c1, BCOLS - 1) + 1):
			if done:
				break
			var i := r * BCOLS + c
			var br = bricks[i]
			if br == null:
				continue
			var rect := _brick_rect(i)
			var q := Vector2(clampf(b.p.x, rect.position.x, rect.end.x), clampf(b.p.y, rect.position.y, rect.end.y))
			var d: Vector2 = b.p - q
			var dist := d.length()
			if dist >= R:
				continue
			var fire: bool = power.has("E") and br.hp > 0
			if not fire:
				var n: Vector2
				if dist < 0.001:
					n = Vector2(0, 1) if b.v.y < 0 else Vector2(0, -1)
				else:
					n = d / dist
				b.p = q + n * R
				var vn: float = b.v.dot(n)
				if vn < 0.0:
					b.v -= 2.0 * vn * n
					b.v.x += rng.randf_range(-15, 15)
				done = true
			_hit_brick(i, fire)
	if b.v.length() > MAXV:
		b.v = b.v.normalized() * MAXV


func _hit_seg(b: Dictionary, a: Vector2, c: Vector2, e: float) -> Vector2:
	var q := Geometry2D.get_closest_point_to_segment(b.p, a, c)
	var d: Vector2 = b.p - q
	var dist := d.length()
	if dist >= R or dist < 0.0001:
		return Vector2.ZERO
	var n := d / dist
	b.p = q + n * R
	var vn: float = b.v.dot(n)
	if vn < 0.0:
		b.v -= (1.0 + e) * vn * n
		if vn < -500.0 and state == "play":
			_snd("wall", rng.randf_range(0.9, 1.1))
	return n


func _hit_flipper(b: Dictionary, f: Dictionary) -> void:
	var piv: Vector2 = f.piv
	var tip: Vector2 = piv + Vector2.from_angle(f.a) * FL_LEN
	var q := Geometry2D.get_closest_point_to_segment(b.p, piv, tip)
	var tt := piv.distance_to(q) / FL_LEN
	var fr := lerpf(14.0, 7.0, tt)
	var d: Vector2 = b.p - q
	var dist := d.length()
	if dist >= R + fr or dist < 0.0001:
		return
	var n := d / dist
	b.p = q + n * (R + fr)
	var rel: Vector2 = q - piv
	var vf: Vector2 = Vector2(-rel.y, rel.x) * f.w
	var vrel: Vector2 = b.v - vf
	var vn := vrel.dot(n)
	if vn < 0.0:
		b.v -= (1.0 + 0.3) * vn * n


func _ball_ball(a: Dictionary, b: Dictionary) -> void:
	if a.lane or b.lane:
		return
	var d: Vector2 = b.p - a.p
	var dist := d.length()
	if dist >= R * 2.0 or dist < 0.001:
		return
	var n := d / dist
	var push := (R * 2.0 - dist) * 0.5
	a.p -= n * push
	b.p += n * push
	var rv: float = (b.v - a.v).dot(n)
	if rv < 0.0:
		a.v += n * rv
		b.v -= n * rv


func _brick_at(p: Vector2) -> int:
	var c := int(floor((p.x - BX0) / BW_))
	var r := int(floor((p.y - BY0) / BH_))
	if c < 0 or c >= BCOLS or r < 0 or r >= BROWS:
		return -1
	return r * BCOLS + c if bricks[r * BCOLS + c] != null else -1


func _hit_brick(i: int, fire: bool) -> void:
	var br: Dictionary = bricks[i]
	var rect := _brick_rect(i)
	br.f = 0.15
	if br.hp < 0:
		_snd("gold")
		return
	br.hp -= 99 if fire else 1
	if br.hp > 0:
		_snd("metal")
		_add(20)
		return
	var col: Color = BRICK_COLORS[br.k]
	bricks[i] = null
	_add(100 if br.k == "s" else 50)
	_snd("brick", 0.9 + (i / BCOLS) * 0.04)
	for k in 10:
		_part(rect.get_center() + Vector2(rng.randf_range(-20, 20), rng.randf_range(-8, 8)), Vector2(rng.randf_range(-220, 220), rng.randf_range(-220, 80)), col, rng.randf_range(0.4, 0.8), rng.randf_range(3, 6))
	if state == "play" and rng.randf() < 0.17:
		var ks := ["M", "B", "E", "L", "S", "M", "B", "S"]
		var k: String = "+" if rng.randf() < 0.06 else ks[rng.randi_range(0, ks.size() - 1)]
		caps.append({"p": rect.get_center(), "k": k})


func _update_rollovers() -> void:
	for i in 4:
		var inside := false
		for b in balls:
			if b.p.distance_to(rollover_pos[i]) < 16.0:
				inside = true
		if inside and not roll_inside.get(i, false):
			if not lights[i]:
				lights[i] = true
				_snd("rollover")
			_add(50)
		roll_inside[i] = inside
	if lights.all(func(x: bool) -> bool: return x):
		lights = [false, false, false, false]
		if mult < 5:
			mult += 1
		_text("MULTIPLIKATOR x%d" % mult, Vector2(335, 960), Color(1, 0.9, 0.4), 30)
		_snd("lights")


# ---------------------------------------------------------------- effects
func _part(p: Vector2, v: Vector2, col: Color, life: float, size: float) -> void:
	if parts.size() < 700:
		parts.append({"p": p, "v": v, "c": col, "life": life, "max": life, "s": size})


func _text(s: String, p: Vector2, col: Color, size: int) -> void:
	texts.append({"s": s, "p": p, "c": col, "t": 0.0, "size": size})


func _update_fx(dt: float) -> void:
	for p in parts:
		p.life -= dt
		p.v.y += 600.0 * dt
		p.p += p.v * dt
	parts = parts.filter(func(p: Dictionary) -> bool: return p.life > 0.0)
	for x in texts:
		x.t += dt
		x.p.y -= 40.0 * dt
	texts = texts.filter(func(x: Dictionary) -> bool: return x.t < 1.4)
	for k in flash.keys():
		flash[k] -= dt
		if flash[k] <= 0.0:
			flash.erase(k)
	for br in bricks:
		if br != null and br.f > 0.0:
			br.f -= dt
	shake = maxf(0.0, shake - dt * 30.0)
	banner_t = maxf(0.0, banner_t - dt)
	if state in ["play", "title"]:
		_update_rollovers()


# ---------------------------------------------------------------- drawing
func _str(c: CanvasItem, s: String, p: Vector2, size: int, col: Color, align := HORIZONTAL_ALIGNMENT_CENTER, outline := 6) -> void:
	var f := ThemeDB.fallback_font
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var x := p.x
	if align == HORIZONTAL_ALIGNMENT_CENTER:
		x -= w * 0.5
	elif align == HORIZONTAL_ALIGNMENT_RIGHT:
		x -= w
	if outline > 0:
		c.draw_string_outline(f, Vector2(x, p.y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, Color(0.02, 0.01, 0.06, col.a * 0.9))
	c.draw_string(f, Vector2(x, p.y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _hue() -> float:
	return fmod(0.62 + (level - 1) * 0.11, 1.0)


func _draw_bg(c: CanvasItem) -> void:
	var vs := get_viewport_rect().size
	var r := Rect2(-position, vs)
	var top := Color.from_hsv(_hue(), 0.7, 0.14)
	var bot := Color.from_hsv(fmod(_hue() + 0.1, 1.0), 0.8, 0.05)
	c.draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]), PackedColorArray([top, top, bot, bot]))
	for s in stars:
		var a: float = 0.35 + 0.35 * sin(t * 1.7 + s[2])
		c.draw_rect(Rect2(s[0], Vector2(s[1], s[1])), Color(0.85, 0.9, 1, a))
	# playfield glass
	var pf := PackedVector2Array()
	pf.append(Vector2(40, 1300))
	for i in 11:
		pf.append(Vector2(140, 210) + Vector2.from_angle(PI + i * PI * 0.05) * 100)
	for i in 11:
		pf.append(Vector2(580, 210) + Vector2.from_angle(PI * 1.5 + i * PI * 0.05) * 100)
	pf.append(Vector2(680, 1300))
	c.draw_colored_polygon(pf, Color(0.02, 0.02, 0.07, 0.82))
	# decorative rings and a faint logo under the glass
	var hc := Color.from_hsv(_hue(), 0.6, 1.0)
	for i in 3:
		c.draw_arc(Vector2(335, 760), 120.0 + i * 46.0, 0, TAU, 64, Color(hc, 0.05 + 0.02 * sin(t * 2.0 + i)), 2.0, true)
	_str(c, "FLIPPERBROTT", Vector2(335, 800), 44, Color(hc, 0.07), HORIZONTAL_ALIGNMENT_CENTER, 0)
	# lane arrows
	for i in 4:
		var y := 760.0 + i * 36.0
		var a := 0.15 + 0.5 * maxf(0.0, sin(t * 5.0 - i))
		c.draw_colored_polygon(PackedVector2Array([Vector2(655, y), Vector2(667, y + 14), Vector2(643, y + 14)]), Color(1, 0.8, 0.3, a))


func _draw_game(c: CanvasItem) -> void:
	var sh := Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * shake if shake > 0.0 else Vector2.ZERO
	c.draw_set_transform(sh)
	var hc := Color.from_hsv(_hue(), 0.45, 1.0)
	# rollovers
	for i in 4:
		var p: Vector2 = rollover_pos[i]
		var on: bool = lights[i]
		c.draw_circle(p, 10.0, Color(1, 0.85, 0.3) if on else Color(0.25, 0.22, 0.12))
		c.draw_arc(p, 10.0, 0, TAU, 20, Color(1, 1, 1, 0.4), 1.5, true)
		c.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -26), p + Vector2(6, -18), p + Vector2(-6, -18)]), Color(1, 1, 1, 0.35))
	if mult > 1:
		_str(c, "x%d" % mult, Vector2(335, 990), 28, Color(1, 0.85, 0.3))
	# bricks
	for i in bricks.size():
		var br = bricks[i]
		if br == null:
			continue
		_brick(c, _brick_rect(i), br)
	# walls
	for s in segs:
		var col := Color(0.55, 0.6, 0.75)
		var w := 8.0
		if s.kind == "sling":
			var f: float = flash.get(s.id, 0.0)
			col = Color(1, 1, 1).lerp(Color(1, 0.5, 0.3), 1.0 - f / 0.15) if f > 0.0 else Color(0.95, 0.95, 1.0)
			w = 7.0
		elif s.kind == "plunger":
			continue
		c.draw_line(s.a, s.b, col.darkened(0.45), w + 3.0, true)
		c.draw_line(s.a, s.b, col, w * 0.5, true)
	# slingshot bodies
	for side in [0, 1]:
		var m := func(p: Vector2) -> Vector2: return p if side == 0 else Vector2(670.0 - p.x, p.y)
		var f: float = flash.get("slingL" if side == 0 else "slingR", 0.0)
		var body := Color.from_hsv(fmod(_hue() + 0.5, 1.0), 0.7, 0.8 + f * 1.2)
		c.draw_colored_polygon(PackedVector2Array([m.call(Vector2(150, 962)), m.call(Vector2(150, 1036)), m.call(Vector2(188, 1060))]), Color(body, 0.85))
	# gate
	c.draw_line(gate_a, gate_b, Color(0.9, 0.8, 0.4), 4.0, true)
	# spring
	var py := PLUNGER_Y + plunger * 34.0
	c.draw_rect(Rect2(636, py, 40, 10), Color(0.85, 0.2, 0.25))
	c.draw_rect(Rect2(636, py, 40, 3), Color(1, 0.6, 0.6))
	var prevp := Vector2(656, py + 10)
	for i in 8:
		var p := Vector2(656 + (12 if i % 2 == 0 else -12), lerpf(py + 10, 1290, (i + 1) / 8.0))
		c.draw_line(prevp, p, Color(0.8, 0.82, 0.9), 2.5, true)
		prevp = p
	# posts and bumpers
	for p in posts:
		if p.kind == "bumper":
			var f: float = flash.get(p.id, 0.0)
			var k := f / 0.18
			var rr: float = p.r
			c.draw_circle(p.p + Vector2(3, 5), rr + 4, Color(0, 0, 0, 0.35))
			c.draw_circle(p.p, rr + 4, Color.from_hsv(fmod(_hue() + 0.45, 1.0), 0.75, 0.9).lerp(Color.WHITE, k))
			c.draw_circle(p.p, rr - 2, Color(0.12, 0.1, 0.2))
			c.draw_circle(p.p, rr - 7 + 3 * k, Color(1, 0.85, 0.35).lerp(Color.WHITE, k))
			c.draw_circle(p.p + Vector2(-5, -6), 5, Color(1, 1, 1, 0.7))
			_star(c, p.p, rr * 0.45, Color(0.9, 0.3, 0.2, 0.9))
		else:
			c.draw_circle(p.p, p.r + 1.0, Color(0.95, 0.95, 1.0))
			c.draw_circle(p.p, p.r * 0.5, Color(0.5, 0.55, 0.7))
	# flippers
	for f in flippers:
		_flipper(c, f)
	# barrier
	if power.has("S"):
		var a: float = 0.6 + 0.4 * sin(t * 10.0) if power["S"] < 3.0 else 1.0
		c.draw_line(Vector2(40, 1250), Vector2(LANE_X, 1250), Color(0.4, 1, 1, a), 4.0)
	# paddle
	_paddle(c)
	# capsules
	for cp in caps:
		var col: Color = POWERS[cp.k][1]
		var r := Rect2(cp.p - Vector2(22, 10), Vector2(44, 20))
		c.draw_rect(r.grow(2), col.darkened(0.6))
		c.draw_rect(r, col)
		var sx: float = fmod(t * 60.0, 44.0)
		c.draw_rect(Rect2(r.position.x + sx, r.position.y, 4, 20), Color(1, 1, 1, 0.5))
		c.draw_rect(Rect2(r.position, Vector2(44, 5)), Color(1, 1, 1, 0.35))
		_str(c, cp.k, cp.p + Vector2(0, 7), 18, Color(0.05, 0.05, 0.1), HORIZONTAL_ALIGNMENT_CENTER, 0)
	for s in shots:
		c.draw_line(s, s + Vector2(0, 18), Color(1, 0.4, 0.8), 3.0)
	# balls
	for b in balls:
		_ball(c, b)
	for p in parts:
		var a: float = clampf(p.life / p.max * 1.5, 0.0, 1.0)
		c.draw_rect(Rect2(p.p - Vector2(p.s, p.s) * 0.5, Vector2(p.s, p.s)), Color(p.c, a))
	for x in texts:
		var a: float = clampf(1.4 - x.t, 0.0, 1.0)
		var pop: float = 1.0 + maxf(0.0, 0.25 - x.t) * 1.6
		_str(c, x.s, x.p, int(x.size * pop), Color(x.c, a))
	c.draw_set_transform(Vector2.ZERO)
	_draw_top(c)


func _star(c: CanvasItem, p: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var rr := r if i % 2 == 0 else r * 0.45
		pts.append(p + Vector2.from_angle(-PI * 0.5 + i * PI / 5.0) * rr)
	c.draw_colored_polygon(pts, col)


func _brick(c: CanvasItem, r: Rect2, br: Dictionary) -> void:
	var col: Color = BRICK_COLORS[br.k]
	var b := r.grow(-1.5)
	c.draw_rect(b, col.darkened(0.5))
	c.draw_rect(b.grow(-3), col)
	c.draw_rect(Rect2(b.position, Vector2(b.size.x, 3)), col.lightened(0.55))
	c.draw_rect(Rect2(b.position, Vector2(3, b.size.y)), col.lightened(0.3))
	c.draw_rect(Rect2(b.position.x, b.end.y - 3, b.size.x, 3), col.darkened(0.6))
	if br.k == "s" or br.k == "G":
		var sx := fmod(t * 0.6 + r.position.x * 0.003 + r.position.y * 0.002, 1.6) - 0.3
		var x := b.position.x + sx * b.size.x
		if x > b.position.x and x < b.end.x - 6:
			c.draw_colored_polygon(PackedVector2Array([Vector2(x, b.position.y + 3), Vector2(x + 8, b.position.y + 3), Vector2(x + 2, b.end.y - 3), Vector2(x - 6, b.end.y - 3)]), Color(1, 1, 1, 0.45))
		if br.k == "s" and br.hp == 1:
			c.draw_line(b.position + Vector2(10, 4), b.get_center() + Vector2(4, 2), Color(0.2, 0.2, 0.3), 1.5)
			c.draw_line(b.get_center() + Vector2(4, 2), b.end - Vector2(14, 4), Color(0.2, 0.2, 0.3), 1.5)
	else:
		c.draw_rect(Rect2(b.position + Vector2(5, 5), Vector2(8, 4)), Color(1, 1, 1, 0.55))
	if br.f > 0.0:
		c.draw_rect(b, Color(1, 1, 1, br.f / 0.15 * 0.8))


func _flipper(c: CanvasItem, f: Dictionary) -> void:
	var piv: Vector2 = f.piv
	var dir := Vector2.from_angle(f.a)
	var tip := piv + dir * FL_LEN
	var nrm := dir.orthogonal()
	var pts := PackedVector2Array()
	for i in 9:
		pts.append(piv + Vector2.from_angle(f.a + PI * 0.5 + i * PI / 8.0) * 14.0)
	for i in 9:
		pts.append(tip + Vector2.from_angle(f.a - PI * 0.5 + i * PI / 8.0) * 7.0)
	var sh := PackedVector2Array()
	for p in pts:
		sh.append(p + Vector2(3, 6))
	c.draw_colored_polygon(sh, Color(0, 0, 0, 0.35))
	c.draw_colored_polygon(pts, Color(0.95, 0.95, 1.0))
	pts.append(pts[0])
	c.draw_polyline(pts, Color(0.85, 0.15, 0.25), 3.0, true)
	c.draw_line(piv + nrm * -4.0, tip + nrm * -2.0, Color(0.85, 0.15, 0.25, 0.8), 3.0, true)
	c.draw_circle(piv, 5.0, Color(0.6, 0.6, 0.7))


func _paddle(c: CanvasItem) -> void:
	var w := paddle_w
	var r := Rect2(paddle_x - w * 0.5, PY, w, 16)
	c.draw_rect(Rect2(r.position + Vector2(3, 6), r.size), Color(0, 0, 0, 0.35))
	c.draw_rect(Rect2(r.position.x + 8, r.position.y, w - 16, 16), Color(0.75, 0.78, 0.88))
	c.draw_rect(Rect2(r.position.x + 8, r.position.y + 2, w - 16, 4), Color(1, 1, 1, 0.8))
	c.draw_rect(Rect2(r.position.x + 8, r.position.y + 12, w - 16, 4), Color(0.4, 0.42, 0.55))
	var ends := Color(1, 0.3, 0.8) if power.has("L") else Color(0.9, 0.25, 0.3)
	for x in [r.position.x + 8, r.end.x - 8]:
		c.draw_circle(Vector2(x, PY + 8), 8.0, ends)
		c.draw_circle(Vector2(x - 2, PY + 5), 3.0, Color(1, 1, 1, 0.6))
	c.draw_rect(Rect2(paddle_x - 10, PY + 4, 20, 8), Color.from_hsv(_hue(), 0.6, 1.0))


func _ball(c: CanvasItem, b: Dictionary) -> void:
	var fire := power.has("E")
	var n: int = b.trail.size()
	for i in n:
		var a := float(i) / n
		var col := Color(1, 0.5, 0.2, a * 0.5) if fire else Color(0.7, 0.85, 1.0, a * 0.25)
		c.draw_circle(b.trail[i], R * (0.4 + 0.6 * a), col)
	c.draw_circle(b.p + Vector2(3, 5), R, Color(0, 0, 0, 0.35))
	if fire:
		c.draw_circle(b.p, R, Color(1, 0.45, 0.15))
		c.draw_circle(b.p, R * 0.65, Color(1, 0.85, 0.4))
	else:
		c.draw_circle(b.p, R, Color(0.55, 0.58, 0.68))
		c.draw_circle(b.p + Vector2(-1, -1), R * 0.82, Color(0.82, 0.85, 0.93))
		c.draw_circle(b.p + Vector2(2, 3), R * 0.45, Color(0.6, 0.62, 0.72))
	c.draw_circle(b.p + Vector2(-4, -4), R * 0.3, Color(1, 1, 1, 0.95))


func _draw_top(c: CanvasItem) -> void:
	if state == "title":
		return
	c.draw_rect(Rect2(20, 14, 680, 84), Color(0.02, 0.02, 0.07, 0.75))
	c.draw_rect(Rect2(20, 14, 680, 84), Color.from_hsv(_hue(), 0.45, 0.9, 0.5), false, 2.0)
	_str(c, "POÄNG", Vector2(40, 40), 16, Color(0.75, 0.8, 1.0), HORIZONTAL_ALIGNMENT_LEFT, 0)
	_str(c, str(score), Vector2(40, 82), 36, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
	_str(c, "BANA", Vector2(330, 40), 16, Color(0.75, 0.8, 1.0), HORIZONTAL_ALIGNMENT_CENTER, 0)
	_str(c, str(level), Vector2(330, 82), 36, Color(1, 0.88, 0.4))
	_str(c, "KULOR", Vector2(560, 40), 16, Color(0.75, 0.8, 1.0), HORIZONTAL_ALIGNMENT_CENTER, 0)
	for i in mini(lives, 6):
		var p := Vector2(560 + (i - (mini(lives, 6) - 1) * 0.5) * 26, 70)
		c.draw_circle(p, 9, Color(0.8, 0.83, 0.92))
		c.draw_circle(p + Vector2(-3, -3), 3, Color.WHITE)
	_str(c, "x%d" % mult, Vector2(680, 82), 22, Color(1, 0.85, 0.35) if mult > 1 else Color(1, 1, 1, 0.3), HORIZONTAL_ALIGNMENT_RIGHT, 0)
	# active powers
	var x := 60.0
	for k in power:
		var col: Color = POWERS[k][1]
		var frac: float = power[k] / (20.0 if k == "B" else 15.0 if k == "S" else 10.0)
		c.draw_rect(Rect2(x, 120, 110, 22), Color(col, 0.25))
		c.draw_rect(Rect2(x, 120, 110 * frac, 22), Color(col, 0.6))
		_str(c, POWERS[k][0], Vector2(x + 55, 137), 14, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 3)
		x += 120.0
	if save_t > 0.0 and state == "play":
		var a := 0.5 + 0.5 * sin(t * 8.0) if save_t < 3.0 else 1.0
		_str(c, "RÄDDNING", Vector2(335, 1215), 18, Color(0.4, 1, 0.9, a))
	if banner_t > 0.0:
		var a := clampf(banner_t / 0.4, 0.0, 1.0) * clampf((2.6 - banner_t) / 0.15, 0.0, 1.0)
		c.draw_rect(Rect2(40, 470, 590, 110 if banner_sub != "" else 80), Color(0.02, 0.02, 0.08, 0.78 * a))
		_str(c, banner, Vector2(335, 528), 46, Color(1, 0.9, 0.45, a))
		if banner_sub != "":
			_str(c, banner_sub, Vector2(335, 562), 18, Color(1, 1, 1, a), HORIZONTAL_ALIGNMENT_CENTER, 4)


func _draw_glow(c: CanvasItem) -> void:
	for p in posts:
		if p.kind == "bumper":
			var f: float = flash.get(p.id, 0.0)
			var s: float = p.r * (3.0 + 3.0 * f / 0.18)
			c.draw_texture_rect(glow_tex, Rect2(p.p - Vector2(s, s), Vector2(s, s) * 2), false, Color(1, 0.75, 0.3, 0.25 + f * 2.5))
	for i in 4:
		if lights[i]:
			c.draw_texture_rect(glow_tex, Rect2(rollover_pos[i] - Vector2(28, 28), Vector2(56, 56)), false, Color(1, 0.8, 0.3, 0.5))
	for b in balls:
		var col := Color(1, 0.5, 0.2, 0.7) if power.has("E") else Color(0.6, 0.8, 1, 0.25)
		c.draw_texture_rect(glow_tex, Rect2(b.p - Vector2(34, 34), Vector2(68, 68)), false, col)
	for s in shots:
		c.draw_texture_rect(glow_tex, Rect2(s - Vector2(12, 4), Vector2(24, 30)), false, Color(1, 0.4, 0.8, 0.7))
	for cp in caps:
		c.draw_texture_rect(glow_tex, Rect2(cp.p - Vector2(36, 24), Vector2(72, 48)), false, Color(POWERS[cp.k][1], 0.45))
	if power.has("S"):
		c.draw_texture_rect(glow_tex, Rect2(40, 1230, LANE_X - 40, 40), false, Color(0.4, 1, 1, 0.5))
	for p in parts:
		if p.s >= 4.0:
			c.draw_texture_rect(glow_tex, Rect2(p.p - Vector2(10, 10), Vector2(20, 20)), false, Color(p.c, clampf(p.life / p.max, 0, 1) * 0.35))
	if charging:
		c.draw_texture_rect(glow_tex, Rect2(Vector2(655, PLUNGER_Y) - Vector2(40, 40), Vector2(80, 80)), false, Color(1, 0.3 + 0.7 * (1.0 - plunger), 0.2, 0.3 + plunger * 0.5))


func _draw_hud(c: CanvasItem) -> void:
	var vs := get_viewport_rect().size
	var cx := vs.x * 0.5
	if state == "play" and touch_mode:
		var zy := _flip_zone_y()
		for side in [0, 1]:
			var on := false
			for f in touch_map:
				if touch_map[f] == ("left" if side == 0 else "right"):
					on = true
			var r := Rect2(side * cx, zy, cx, vs.y - zy)
			c.draw_rect(r.grow(-6), Color(1, 1, 1, 0.10 if on else 0.03))
			_str(c, "◀ FLIPPER" if side == 0 else "FLIPPER ▶", Vector2(r.get_center().x, vs.y - 26), 18, Color(1, 1, 1, 0.3), HORIZONTAL_ALIGNMENT_CENTER, 0)
		c.draw_circle(Vector2(vs.x - 46, 66), 28, Color(1, 1, 1, 0.12))
		_str(c, "II", Vector2(vs.x - 46, 76), 26, Color(1, 1, 1, 0.7), HORIZONTAL_ALIGNMENT_CENTER, 0)
	match state:
		"title":
			c.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.01, 0.0, 0.05, 0.45))
			var title := "FLIPPERBROTT"
			var f := ThemeDB.fallback_font
			var size := 80
			var total := f.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
			var x := cx - total * 0.5
			var cols := ["r", "o", "y", "g", "c", "b", "p"]
			for i in title.length():
				var ch := title[i]
				var w := f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
				var y := vs.y * 0.2 + sin(t * 3.0 + i * 0.5) * 8.0
				c.draw_string_outline(f, Vector2(x, y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 12, Color(0.02, 0.01, 0.08))
				c.draw_string(f, Vector2(x, y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, BRICK_COLORS[cols[i % 7]])
				x += w
			_str(c, "Krossa tegel med paddel och flippers", Vector2(cx, vs.y * 0.2 + 50), 26, Color(0.9, 0.92, 1.0))
			if best > 0:
				_str(c, "Rekord: %d" % best, Vector2(cx, vs.y * 0.2 + 90), 22, Color(1, 1, 1, 0.7), HORIZONTAL_ALIGNMENT_CENTER, 0)
			var lines_: Array
			if touch_mode:
				lines_ = ["Dra fingret i mitten för att flytta paddeln.", "Tryck längst ned till vänster / höger för flipprarna.",
					"Håll in och släpp för att skjuta ut kulan."]
			else:
				lines_ = ["Paddel: ← → eller musen", "Flippers: Z / Skift vänster · X / Skift höger · musknapparna",
					"Skjut ut kulan: håll in Mellanslag eller en flipper och släpp", "Esc paus · M ljud"]
			lines_.append_array(["Kapslar: M multiboll · B bred paddel · E eldboll", "L laser · S skydd · + extra kula",
				"Tänd alla fyra lamporna längst ned för högre multiplikator."])
			var py := vs.y * 0.56
			c.draw_rect(Rect2(cx - 330, py - 32, 660, lines_.size() * 32 + 24), Color(0.02, 0.02, 0.08, 0.7))
			for i in lines_.size():
				_str(c, lines_[i], Vector2(cx, py + i * 32), 19, Color(1, 1, 1, 0.9), HORIZONTAL_ALIGNMENT_CENTER, 0)
			var start := "Tryck på skärmen för att börja" if touch_mode else "Tryck MELLANSLAG eller klicka för att börja"
			_str(c, start, Vector2(cx, vs.y - 80), 28, Color(1, 0.92, 0.45, 0.6 + 0.4 * sin(t * 4.0)))
			for b in _menu_buttons():
				var r: Rect2 = b[1]
				c.draw_rect(r, Color(1, 1, 1, 0.08))
				c.draw_rect(r, Color(1, 1, 1, 0.4), false, 2.0)
				_str(c, "Ljud: " + ("av" if muted else "på"), r.get_center() + Vector2(0, 8), 20, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 0)
		"pause":
			c.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.01, 0.0, 0.05, 0.7))
			_str(c, "PAUS", Vector2(cx, vs.y * 0.5 - 70), 70, Color(1, 0.92, 0.45))
			for b in _menu_buttons():
				var r: Rect2 = b[1]
				c.draw_rect(r, Color(1, 1, 1, 0.1))
				c.draw_rect(r, Color(1, 1, 1, 0.5), false, 2.0)
				var label: String = {"resume": "Fortsätt", "menu": "Till menyn", "mute": "Ljud: " + ("av" if muted else "på")}[b[0]]
				_str(c, label, r.get_center() + Vector2(0, 10), 28, Color.WHITE)
			if not touch_mode:
				_str(c, "Esc fortsätter · Q till menyn · M ljud", Vector2(cx, vs.y - 60), 20, Color(1, 1, 1, 0.6), HORIZONTAL_ALIGNMENT_CENTER, 0)
		"over":
			var a := clampf(over_t / 0.6, 0.0, 1.0)
			c.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.01, 0.0, 0.05, 0.72 * a))
			_str(c, "SPELET ÄR SLUT", Vector2(cx, vs.y * 0.5 - 110), 58, Color(1, 0.45, 0.5, a))
			_str(c, "%d poäng" % score, Vector2(cx, vs.y * 0.5 - 30), 48, Color(1, 1, 1, a))
			_str(c, "Du kom till bana %d" % level, Vector2(cx, vs.y * 0.5 + 16), 24, Color(0.8, 0.85, 1, a))
			if new_best:
				_str(c, "NYTT REKORD!", Vector2(cx, vs.y * 0.5 + 70), 36, Color(1, 0.9, 0.35, a * (0.7 + 0.3 * sin(t * 8.0))))
			else:
				_str(c, "Rekord: %d" % best, Vector2(cx, vs.y * 0.5 + 70), 24, Color(1, 1, 1, a * 0.7))
			if over_t > 1.2:
				var msg := "Tryck på skärmen för att spela igen" if touch_mode else "Mellanslag: spela igen · Esc: menyn"
				_str(c, msg, Vector2(cx, vs.y * 0.5 + 150), 24, Color(1, 1, 1, 0.6 + 0.4 * sin(t * 4.0)))
