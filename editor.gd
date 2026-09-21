extends Node
## In-game map painter for "Sir, We Have an Orc Problem".
##
## Registered by the installers as the MapEditor autoload; by hand, that is the
## MapEditor line in override.cfg.
##
##   F11          open the painter, and close it again
##   F5           save and play this map straight away
##   N            move to your next map, if you have more than one
##   Ctrl+N       start a new map
##   Ctrl+T       rename this map
##   Ctrl+A       how big the map is, in tiles (192, or 256x128)
##   Ctrl+O       how many orcs altogether (12000, or 12k)
##   Ctrl+H       how tough each orc is
##   Ctrl+D       how many seconds they take to arrive
##   left drag    paint          right drag   erase to open ground
##   P            cycle how the map looks: grass, ice, desert, lava, stone...
##   S            switch between painting and placing spawn points
##   G R B        ground, rock, base
##   1 - 9        brush size, in cells across
##   Ctrl+Z       undo           Ctrl+S       save the PNG
##   Ctrl+E       copy the stock maps and sprite sheets to user://reference/
##   middle drag  pan            wheel        zoom
##
## The view is the game's own renderer, rebuilt shortly after you stop painting
## -- about 30 ms for a 192x192 map -- so what you see is what the battle draws.

const MODS_DIR := "user://mods"
const EDITOR_SCENE := "res://levels/level_1_1/level_1_1.tscn"
const GROUND := Color(0, 0, 0, 0)
const ROCK := Color(0, 0, 1, 1)
const BASE := Color(1, 0, 0, 1)
const UNDO_MAX := 30
const REGEN_DELAY := 0.08
## The looks a map can have, with the tile-variant counts the game itself uses
## for each. "space" is in the game's files but no level uses it, so its counts
## are the safe pair rather than an observed one.
const PALETTES := [
	{"name": "grass",  "wall": 1, "ground": 1},
	{"name": "ice",    "wall": 1, "ground": 1},
	{"name": "desert", "wall": 3, "ground": 3},
	{"name": "lava",   "wall": 2, "ground": 3},
	{"name": "stone",  "wall": 2, "ground": 2},
	{"name": "cave",   "wall": 2, "ground": 1},
	{"name": "space",  "wall": 1, "ground": 1},
]

const NEW_MAP := {
	"name": "New Map", "map": "map.png", "map_size": [128, 128],
	"sprite_sheet": "res://levels/sprite_sheet_grass.png",
	"wall_tiles_count": 1, "ground_tiles_count": 1,
	"enemy_health_buff": 40.0, "level_bonus_marks": 1000,
	"marks_upon_survival": 10000, "marks_upon_all_killed": 0,
	"spawners": [{
		"position": [-25, 512], "size": [20, 100], "initial_velocity": [50, 0],
		"waves": [{"enemy_type": 0, "amount": 20000, "duration": 60.0}],
	}],
}

const LEGEND := """drag paint   right-drag erase   wheel zoom   middle-drag pan
G ground   R rock   B base   1-9 brush size   S spawn points   P look
Ctrl+A size   Ctrl+O orcs   Ctrl+H toughness   Ctrl+D seconds   Ctrl+T rename
Ctrl+S save   Ctrl+Z undo   Ctrl+N new map   Ctrl+E dump stock
F5 save and play   F11 close"""

var _maps: Array[Dictionary] = []
var _index := -1
var _dir := ""
var _img: Image
var _tex: ImageTexture
var _undo: Array[Dictionary] = []
var _paint_with := ROCK
var _brush := 1
var _dirty := false
var _backed_up := false

var _layer: CanvasLayer
var _sub: SubViewport
var _canvas: Control
var _hud: Label
var _scene: Node2D
var _cam: Camera2D
var _regen: Timer
var _regenerating := false
var _stroke := 0          # 0 none, 1 painting, 2 erasing
var _panning := false
var _open := false
var _note := ""
var _spawner_mode := false
var _drag_spawner = null
var _name_edit: LineEdit
var _prompt: PanelContainer
var _prompt_label: Label
var _asking := ""          # which value the text box is collecting
var _base_cells := -1
var _note_at := 0


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	var key := (event as InputEventKey).keycode
	if key == KEY_F11:
		_toggle()
	elif not _open:
		return
	elif key == KEY_T and (event as InputEventKey).ctrl_pressed:
		_ask("name", _maps[_index]["name"], "what should this map be called?")
	elif key == KEY_A and (event as InputEventKey).ctrl_pressed:
		_ask("size", "%dx%d" % [_img.get_width(), _img.get_height()],
			"how big, in tiles? 192 for a square, or 256x128")
	elif key == KEY_O and (event as InputEventKey).ctrl_pressed:
		_ask("orcs", str(_total_orcs()), "how many orcs altogether?")
	elif key == KEY_P:
		_next_palette()
	elif key == KEY_H and (event as InputEventKey).ctrl_pressed:
		_ask("buff", str(_data().enemy_health_buff),
			"how tough is each orc? (the game's last level uses 97.7)")
	elif key == KEY_D and (event as InputEventKey).ctrl_pressed:
		_ask("secs", str(_spawn_seconds()),
			"how many seconds do they take to all arrive?")
	elif key == KEY_S and not (event as InputEventKey).ctrl_pressed:
		_spawner_mode = not _spawner_mode
	elif key == KEY_N and (event as InputEventKey).ctrl_pressed:
		_new_map()
	elif key == KEY_N:
		_next_map()
	elif key == KEY_F5:
		_save_and_play()
	elif key == KEY_G:
		_paint_with = GROUND
		_spawner_mode = false      # picking a colour means you want to paint
	elif key == KEY_R:
		_paint_with = ROCK
		_spawner_mode = false
	elif key == KEY_B:
		_paint_with = BASE
		_spawner_mode = false
	elif key >= KEY_1 and key <= KEY_9:
		_brush = key - KEY_0
	elif key == KEY_Z and (event as InputEventKey).ctrl_pressed:
		_undo_once()
	elif key == KEY_S and (event as InputEventKey).ctrl_pressed:
		_save()
	elif key == KEY_E and (event as InputEventKey).ctrl_pressed:
		_dump_reference()
	else:
		return
	_refresh_hud()
	if _canvas:
		_canvas.queue_redraw()      # size and material change without the mouse moving
	get_viewport().set_input_as_handled()


# --- opening and closing -----------------------------------------------------

## F11 opens what you were last working on, and closes it again. Moving to a
## different map is N, and only means anything if you have more than one.
func _toggle() -> void:
	if _open:
		_close()
	else:
		_open_map(maxi(_index, 0))


func _next_map() -> void:
	if _maps.size() < 2:
		_refresh_hud("only one map in user://mods")
		return
	if _dirty:
		_save()          # moving on should never lose a painting
	_open_map((_index + 1) % _maps.size())


## A new map is a folder with a level.json in it. The loader paints a blank
## walled box for one that has no PNG yet, so there is something to start on.
func _new_map() -> void:
	if _dirty:
		_save()
	var n := 2
	while DirAccess.dir_exists_absolute(MODS_DIR + "/map_%d" % n):
		n += 1
	var dir := MODS_DIR + "/map_%d" % n
	DirAccess.make_dir_recursive_absolute(dir)
	var cfg := NEW_MAP.duplicate(true)
	cfg["name"] = "Map %d" % n
	var f := FileAccess.open(dir + "/level.json", FileAccess.WRITE)
	if f == null:
		push_error("[editor] could not create %s" % dir)
		return
	f.store_string(JSON.stringify(cfg, "\t"))
	f.close()
	_open_map(0, dir)
	_refresh_hud("new map in %s -- rename it in level.json" % dir)


func _open_map(which: int, prefer_dir := "") -> void:
	var loader := get_node_or_null("/root/ModLoader")
	if loader == null or not loader.has_method("map_list"):
		push_error("[editor] no ModLoader, or it predates map_list(); update mod_loader.gd")
		return
	if GameManager.levels.is_empty():
		# No save loaded yet, so a map cannot be registered or played from here.
		push_error("[editor] open a save first, then press F11 on the Upgrades screen")
		return
	_maps = loader.map_list()
	if _maps.is_empty():
		push_error("[editor] no maps under user://mods to edit")
		return

	if _layer == null:
		_build_overlay()
	_index = clampi(which, 0, _maps.size() - 1)
	if prefer_dir != "":
		for i in _maps.size():
			if _maps[i]["dir"] == prefer_dir:
				_index = i
				break
	if _maps[_index]["dir"] != _dir:
		_undo.clear()          # a different map; its history is not this one's
	_dir = _maps[_index]["dir"]
	_dirty = false
	_backed_up = false

	var data: LevelData = _maps[_index]["data"]
	_tex = data.map_texture
	_img = _tex.get_image()
	_img.convert(Image.FORMAT_RGBA8)

	for c in _sub.get_children():
		_sub.remove_child(c)
		c.queue_free()
	_scene = load(EDITOR_SCENE).instantiate()
	_scene.map_texture = _tex
	_scene.sprite_sheet_texture = data.sprite_sheet_texture
	_sub.add_child(_scene)

	_cam = Camera2D.new()
	_cam.position = Vector2(_img.get_size()) * WorldGen.WORLD_UNITS_PER_PIXEL / 2.0
	_cam.zoom = Vector2.ONE * _fit_zoom()
	_scene.add_child(_cam)
	_cam.make_current()

	_layer.visible = true
	_open = true
	_refresh_level_menu()      # a map made with Ctrl+N has no panel yet
	_regen_now()


func _close() -> void:
	if _dirty:
		_save()      # reopening re-reads from disk, so never close on unsaved work
	_open = false
	if _layer:
		_layer.visible = false
	for c in _sub.get_children():
		c.queue_free()
	_scene = null


func _build_overlay() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 128

	var container := SubViewportContainer.new()
	container.stretch = true
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sub = SubViewport.new()
	_sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(_sub)
	_layer.add_child(container)

	# Input is taken here rather than inside the SubViewport, so the coordinate
	# maths is ours and does not depend on how a container forwards events.
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.gui_input.connect(_on_gui_input)
	_canvas.draw.connect(_on_draw)
	_layer.add_child(_canvas)

	_hud = Label.new()
	_hud.position = Vector2(12, 8)
	_hud.add_theme_color_override("font_outline_color", Color.BLACK)
	_hud.add_theme_constant_override("outline_size", 6)
	_layer.add_child(_hud)

	# Added after the HUD so it draws over it, and centred rather than tucked
	# into the corner where the map's name already is.
	# A LineEdit rather than collecting keystrokes by hand: it brings a cursor,
	# selection and IME with it, and while it has focus the paint keys cannot leak.
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt = PanelContainer.new()
	_prompt.visible = false
	var rows := VBoxContainer.new()
	_prompt_label = Label.new()
	_name_edit = LineEdit.new()
	_name_edit.custom_minimum_size = Vector2(440, 0)
	_name_edit.text_submitted.connect(_finish_rename)
	_name_edit.gui_input.connect(_rename_input)
	rows.add_child(_prompt_label)
	rows.add_child(_name_edit)
	_prompt.add_child(rows)
	centre.add_child(_prompt)
	_layer.add_child(centre)

	_regen = Timer.new()
	_regen.one_shot = true
	_regen.wait_time = REGEN_DELAY
	_regen.timeout.connect(_regen_now)
	add_child(_regen)

	get_tree().root.add_child(_layer)


func _fit_zoom() -> float:
	var world := Vector2(_img.get_size()) * WorldGen.WORLD_UNITS_PER_PIXEL
	var vp := get_tree().root.get_visible_rect().size
	return minf(vp.x / world.x, vp.y / world.y) * 0.9


# --- painting ----------------------------------------------------------------

func _on_gui_input(event: InputEvent) -> void:
	if not _open:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE:
		_panning = event.pressed
		return
	if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		_zoom_at(event.position, 1.1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.1)
		return
	if _panning and event is InputEventMouseMotion:
		_cam.position -= event.relative / _cam.zoom
		_canvas.queue_redraw()
		return
	if _spawner_mode:
		_spawner_input(event)
		return
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT:
				if event.pressed:
					_push_undo()
					_stroke = 1 if event.button_index == MOUSE_BUTTON_LEFT else 2
					_stamp(event.position)
				else:
					_stroke = 0
					_regen.start()
	elif event is InputEventMouseMotion:
		if _stroke != 0:
			_stamp(event.position)
		_canvas.queue_redraw()


func _stamp(screen: Vector2) -> void:
	var cell := _cell_at(screen)
	var colour := _paint_with if _stroke == 1 else GROUND
	var half: int = _brush / 2
	var rect := Rect2i(cell.x - half, cell.y - half, _brush, _brush)
	rect = rect.intersection(Rect2i(Vector2i.ZERO, _img.get_size()))
	if rect.size == Vector2i.ZERO:
		return
	_img.fill_rect(rect, colour)
	_tex.update(_img)
	_dirty = true
	_regen.start()
	_canvas.queue_redraw()
	_refresh_hud()


# --- spawn points ------------------------------------------------------------
#
# Spawn points live in level.json rather than the PNG, so editing them writes
# that file as well. They are drawn in both modes: you cannot place an entrance
# sensibly without seeing where the orcs come in.

func _spawners() -> Array:
	return (_maps[_index]["data"] as LevelData).spawners


func _spawner_at(screen: Vector2):
	for s in _spawners():
		var half: Vector2 = (s.shape as RectangleShape2D).size / 2.0
		var r := Rect2(_world_to_screen(s.position - half), half * 2.0 * _cam.zoom)
		if r.grow(6.0).has_point(screen):
			return s
	return null


func _spawner_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var hit = _spawner_at(event.position)
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_push_undo()
				if hit == null:
					_add_spawner(_screen_to_world(event.position))
				_drag_spawner = hit if hit else _spawners().back()
			else:
				_drag_spawner = null
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and hit:
			_push_undo()
			_spawners().erase(hit)
			_dirty = true
			_refresh_hud("spawn point removed")
	elif event is InputEventMouseMotion and _drag_spawner:
		_drag_spawner.position = _screen_to_world(event.position)
		_dirty = true
	_canvas.queue_redraw()
	_refresh_hud()


## A new spawn point faces the middle of the map, so the orcs walk inwards
## without you having to work out a velocity by hand.
func _add_spawner(world: Vector2) -> void:
	var s := EnemySpawnerData.new()
	s.position = world
	var to_centre := Vector2(_img.get_size()) * WorldGen.WORLD_UNITS_PER_PIXEL / 2.0 - world
	var shape := RectangleShape2D.new()
	if absf(to_centre.x) > absf(to_centre.y):
		s.initial_velocity = Vector2(signf(to_centre.x) * 50.0, 0.0)
		shape.size = Vector2(20, 100)
	else:
		s.initial_velocity = Vector2(0.0, signf(to_centre.y) * 50.0)
		shape.size = Vector2(100, 20)
	s.shape = shape
	for w in (_spawners()[0].waves if not _spawners().is_empty() else []):
		var copy := EnemySpawnWave.new()
		copy.enemy_type = w.enemy_type
		copy.amount = w.amount
		copy.duration = w.duration
		s.waves.append(copy)
	if s.waves.is_empty():
		var w := EnemySpawnWave.new()
		w.enemy_type = 0
		w.amount = 20000
		w.duration = 60.0
		s.waves.append(w)
	_spawners().append(s)
	_dirty = true
	_refresh_hud("spawn point added")


func _count_base() -> void:
	# cheap enough beside a world rebuild, and far too dear once per frame
	var n := 0
	for y in _img.get_height():
		for x in _img.get_width():
			var c := _img.get_pixel(x, y)
			if c.a > 0.5 and c.r > 0.5 and c.b < 0.5:
				n += 1
	_base_cells = n


func _regen_now() -> void:
	if _scene == null or _regenerating:
		return
	_count_base()
	_regenerating = true
	var t := Time.get_ticks_usec()
	await _scene._on_preview_world_data()
	_regenerating = false
	_refresh_hud("rebuilt in %.0f ms" % ((Time.get_ticks_usec() - t) / 1000.0))


# --- coordinates -------------------------------------------------------------

func _screen_to_world(screen: Vector2) -> Vector2:
	return _cam.position + (screen - _canvas.size / 2.0) / _cam.zoom


func _world_to_screen(world: Vector2) -> Vector2:
	return (world - _cam.position) * _cam.zoom + _canvas.size / 2.0


func _cell_at(screen: Vector2) -> Vector2i:
	return Vector2i((_screen_to_world(screen) / WorldGen.WORLD_UNITS_PER_PIXEL).floor())


func _cell_to_screen(cell: Vector2i) -> Vector2:
	var world := Vector2(cell) * WorldGen.WORLD_UNITS_PER_PIXEL
	return (world - _cam.position) * _cam.zoom + _canvas.size / 2.0


func _zoom_at(screen: Vector2, factor: float) -> void:
	var before: Vector2 = _cam.position + (screen - _canvas.size / 2.0) / _cam.zoom
	_cam.zoom *= factor
	var after: Vector2 = _cam.position + (screen - _canvas.size / 2.0) / _cam.zoom
	_cam.position += before - after
	_canvas.queue_redraw()


# --- overlay drawing ---------------------------------------------------------

func _on_draw() -> void:
	if not _open or _cam == null:
		return
	var step: float = WorldGen.WORLD_UNITS_PER_PIXEL * _cam.zoom.x
	if step >= 7.0:                                   # only when cells are legible
		var size := _img.get_size()
		var grid := Color(1, 1, 1, 0.10)
		for x in range(size.x + 1):
			var a := _cell_to_screen(Vector2i(x, 0))
			_canvas.draw_line(a, _cell_to_screen(Vector2i(x, size.y)), grid, 1.0)
		for y in range(size.y + 1):
			var a := _cell_to_screen(Vector2i(0, y))
			_canvas.draw_line(a, _cell_to_screen(Vector2i(size.x, y)), grid, 1.0)

	for sp in _spawners():
		var sz: Vector2 = (sp.shape as RectangleShape2D).size
		var r := Rect2(_world_to_screen(sp.position - sz / 2.0), sz * _cam.zoom)
		var col := Color(1.0, 0.45, 0.1, 1.0 if _spawner_mode else 0.5)
		_canvas.draw_rect(r, col, false, 2.0)
		var mid := _world_to_screen(sp.position)
		if sp.initial_velocity.length() > 0.1:
			_canvas.draw_line(mid, mid + sp.initial_velocity.normalized() * 30.0, col, 2.0)

	if _spawner_mode:
		return
	var cell := _cell_at(_canvas.get_local_mouse_position())
	var half: int = _brush / 2
	var tl := _cell_to_screen(Vector2i(cell.x - half, cell.y - half))
	var br := _cell_to_screen(Vector2i(cell.x - half + _brush, cell.y - half + _brush))
	_canvas.draw_rect(Rect2(tl, br - tl), Color.WHITE, false, 2.0)


func _refresh_hud(note := "") -> void:
	if _hud == null:
		return
	if note != "":
		_note = note
		_note_at = Time.get_ticks_msec()
	elif Time.get_ticks_msec() - _note_at > 3000:
		_note = ""
	var names := {GROUND: "ground", ROCK: "rock", BASE: "base"}
	var warn := "   NO BASE -- orcs will have nothing to walk to" if _base_cells == 0 else ""
	var line2 := "spawn points: %d   click place   drag move   right-click remove" % _spawners().size() \
		if _spawner_mode else "paint: %s   brush: %d" % [names.get(_paint_with, "?"), _brush]
	_hud.text = "%s%s   %dx%d %s   %s orcs over %ss   toughness %s\n%s   %s\n\n%s" % [
		_maps[_index]["name"], " *" if _dirty else "",
		_img.get_width(), _img.get_height(), _palette_name(),
		String.num_uint64(_total_orcs()),
		String.num(_spawn_seconds(), 0), String.num(_data().enemy_health_buff, 2),
		line2, _note + warn,
		LEGEND + ("   N next map (saves)" if _maps.size() > 1 else "")]


# --- undo, save, reference ---------------------------------------------------

# --- the map's name, which lives in level.json beside the spawn points --------

func _ask(what: String, current: String, label: String) -> void:
	_asking = what
	_prompt_label.text = "%s\n(Enter to keep it, Esc to leave it alone)" % label
	_name_edit.text = current
	_prompt.visible = true
	_name_edit.visible = true
	_name_edit.grab_focus()
	_name_edit.select_all()
	_refresh_hud()


## People write numbers like people: 12k, 1.5k, 120,000, 2m. Returns -1 for
## anything that is not a number at all.
## Resizing keeps what you have drawn in the top left corner and fills the rest
## with rock, so the map stays walled in rather than leaking orcs off the edge.
func _resize_map(w: int, h: int) -> void:
	w = clampi(w, 32, 512)
	h = clampi(h, 32, 512)
	if w == _img.get_width() and h == _img.get_height():
		return
	var grown := Image.create(w, h, false, Image.FORMAT_RGBA8)
	grown.fill(ROCK)
	var keep := Rect2i(0, 0, mini(w, _img.get_width()), mini(h, _img.get_height()))
	grown.blit_rect(_img, keep, Vector2i.ZERO)
	_adopt(grown)
	_dirty = true


## Take a new image as the map, coping with it being a different size from the
## one before -- which ImageTexture.update() will not do, and undo has to.
func _adopt(img: Image) -> void:
	var resized := img.get_size() != _img.get_size()
	_img = img
	if resized:
		_tex.set_image(_img)
		var d := _data()
		d.world_size = Vector2(_img.get_size()) * WorldGen.WORLD_UNITS_PER_PIXEL
		_maps[_index]["cfg"]["map_size"] = [_img.get_width(), _img.get_height()]
		if _cam:
			_cam.position = d.world_size / 2.0
			_cam.zoom = Vector2.ONE * _fit_zoom()
	else:
		_tex.update(_img)
	_regen.start()
	if _canvas:
		_canvas.queue_redraw()


## The level list builds its panels once, when the tech tree loads, and copies
## each name into a label. Renaming a map, or making a new one, therefore has to
## reach in and say so.
func _refresh_level_menu() -> void:
	var container := get_tree().root.find_child("LevelContainer", true, false)
	if container == null:
		return                      # not on the tech tree; it will build fresh
	var shown := {}
	for panel in container.get_children():
		shown[panel.level_id] = true
		var label := panel.find_child("LevelNameLabel", true, false)
		if label and GameManager.levels.has(panel.level_id):
			label.text = GameManager.levels[panel.level_id].name
	for id in GameManager.levels:
		if not shown.has(id):
			var panel = load("res://tech_tree/hud/level_panel.tscn").instantiate()
			panel.level_id = id     # set before adding, as the container does
			container.add_child(panel)


func _palette_name() -> String:
	return _data().sprite_sheet_texture.resource_path \
		.get_file().trim_prefix("sprite_sheet_").trim_suffix(".png")


func _next_palette() -> void:
	var here := _palette_name()
	var at := 0
	for i in PALETTES.size():
		if PALETTES[i]["name"] == here:
			at = i
			break
	var p: Dictionary = PALETTES[(at + 1) % PALETTES.size()]
	var path := "res://levels/sprite_sheet_%s.png" % p["name"]
	var tex := load(path)
	if tex == null:
		_refresh_hud("no sprite sheet called %s" % p["name"])
		return
	_push_undo()
	var d := _data()
	d.sprite_sheet_texture = tex
	d.wall_tiles_count = p["wall"]
	d.ground_tiles_count = p["ground"]
	var cfg: Dictionary = _maps[_index]["cfg"]
	cfg["sprite_sheet"] = path
	cfg["wall_tiles_count"] = p["wall"]
	cfg["ground_tiles_count"] = p["ground"]
	if _scene:
		_scene.sprite_sheet_texture = tex
	_dirty = true
	_regen.start()
	_refresh_hud("look: %s" % p["name"])


func _parse_number(text: String) -> float:
	var t := text.strip_edges().to_lower().replace(",", "").replace(" ", "")
	var scale := 1.0
	if t.ends_with("k"):
		scale = 1000.0
		t = t.left(t.length() - 1)
	elif t.ends_with("m"):
		scale = 1000000.0
		t = t.left(t.length() - 1)
	if t == "" or not t.is_valid_float():
		return -1.0
	return maxf(t.to_float() * scale, -1.0)


func _data() -> LevelData:
	return _maps[_index]["data"]


func _spawn_seconds() -> float:
	var longest := 0.0
	for s in _spawners():
		for w in s.waves:
			longest = maxf(longest, w.duration)
	return longest


func _total_orcs() -> int:
	var n := 0
	for s in _spawners():
		for w in s.waves:
			n += w.amount
	return n


## Spread evenly over the spawn points, the way the game's own levels do it,
## with any remainder given to the first.
func _set_total_orcs(total: int) -> void:
	var points := _spawners()
	if points.is_empty():
		_refresh_hud("place a spawn point first, with S")
		return
	for s in points:
		if s.waves.is_empty():
			var w := EnemySpawnWave.new()
			w.enemy_type = 0
			w.duration = 60.0
			s.waves.append(w)
	var each: int = total / points.size()
	for i in points.size():
		var share := each + (total - each * points.size() if i == 0 else 0)
		points[i].waves[0].amount = share
		for j in range(1, points[i].waves.size()):
			points[i].waves[j].amount = 0
	_dirty = true


func _rename_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_end_rename()
		_name_edit.accept_event()


func _finish_rename(text: String) -> void:
	var value := text.strip_edges()
	var changed := false
	match _asking:
		"name":
			if value != "":
				_push_undo()
				_maps[_index]["name"] = value
				_maps[_index]["cfg"]["name"] = value
				var id: int = _maps[_index].get("id", -1)
				if id >= 0 and GameManager.levels.has(id):
					GameManager.levels[id].name = value
				_refresh_level_menu()
				_dirty = true
				changed = true
		"size":
			var parts := value.to_lower().replace(" ", "").split("x")
			var w := _parse_number(parts[0])
			var h := _parse_number(parts[1]) if parts.size() > 1 else w
			if w >= 1.0 and h >= 1.0:
				_push_undo()
				_resize_map(int(w), int(h))
				changed = true
			else:
				_refresh_hud("give a size like 192, or 256x128")
		"orcs":
			var n := _parse_number(value)
			if n >= 1.0:
				_push_undo()
				_set_total_orcs(int(n))
				changed = true
			else:
				_refresh_hud("that is not a number of orcs -- try 12000 or 12k")
		"buff":
			var b := _parse_number(value)
			if b > 0.0:
				_push_undo()
				_data().enemy_health_buff = b
				_maps[_index]["cfg"]["enemy_health_buff"] = b
				_dirty = true
				changed = true
			else:
				_refresh_hud("toughness has to be a number above zero")
		"secs":
			var secs := _parse_number(value)
			if secs > 0.0:
				_push_undo()
				for s in _spawners():
					for w in s.waves:
						w.duration = secs
				_dirty = true
				changed = true
			else:
				_refresh_hud("that is not a number of seconds")
	_end_rename()
	if changed:
		_refresh_hud("changed -- Ctrl+S to keep it")


func _end_rename() -> void:
	_prompt.visible = false
	_name_edit.visible = false
	_name_edit.release_focus()
	_asking = ""


func _push_undo() -> void:
	_undo.append({"img": _img.duplicate(), "cfg": _settings().duplicate(true)})
	if _undo.size() > UNDO_MAX:
		_undo.pop_front()


func _undo_once() -> void:
	if _undo.is_empty():
		_refresh_hud("nothing left to undo")
		return
	var step: Dictionary = _undo.pop_back()
	_restore_settings(step["cfg"])
	_adopt(step["img"])
	_dirty = true
	_refresh_hud("undone")


## The whole point of the loop: edit, F5, fight it, come back. Edits are already
## live in the registered level, so this saves first and then drops into the battle.
func _save_and_play() -> void:
	var id: int = _maps[_index].get("id", -1)
	if id < 0:
		push_error("[editor] this map is not registered yet; open the Levels list once")
		return
	if _dirty:
		_save()
	_close()
	GameManager.load_level(id)


func _save() -> void:
	var path := _dir + "/map.png"
	# one backup per session, before the first overwrite
	if not _backed_up and FileAccess.file_exists(path):
		var prev := FileAccess.get_file_as_bytes(path)
		var bak := FileAccess.open(path + ".bak", FileAccess.WRITE)
		if bak:
			bak.store_buffer(prev)
			bak.close()
		_backed_up = true
	var err := _img.save_png(path)
	if err != OK:
		push_error("[editor] could not save %s: %s" % [path, error_string(err)])
		return
	_save_config()
	_dirty = false
	_refresh_hud("saved")


## Everything about a map except the picture. One description, used both for
## writing level.json and for undo, so the two cannot drift apart.
func _settings() -> Dictionary:
	var cfg: Dictionary = _maps[_index]["cfg"]
	var out := []
	for s in _spawners():
		var waves := []
		for w in s.waves:
			waves.append({"enemy_type": int(w.enemy_type), "amount": int(w.amount),
				"duration": w.duration})
		var sz: Vector2 = (s.shape as RectangleShape2D).size
		out.append({
			"position": [s.position.x, s.position.y],
			"size": [sz.x, sz.y],
			"initial_velocity": [s.initial_velocity.x, s.initial_velocity.y],
			"waves": waves,
		})
	cfg["spawners"] = out
	cfg["name"] = _maps[_index]["name"]
	cfg["enemy_health_buff"] = _data().enemy_health_buff
	cfg["sprite_sheet"] = _data().sprite_sheet_texture.resource_path
	cfg["wall_tiles_count"] = _data().wall_tiles_count
	cfg["ground_tiles_count"] = _data().ground_tiles_count
	return cfg


## The reverse: put a remembered set of settings back.
func _restore_settings(cfg: Dictionary) -> void:
	var d := _data()
	d.enemy_health_buff = cfg["enemy_health_buff"]
	d.wall_tiles_count = cfg["wall_tiles_count"]
	d.ground_tiles_count = cfg["ground_tiles_count"]
	var sheet = load(cfg["sprite_sheet"])
	if sheet:
		d.sprite_sheet_texture = sheet
		if _scene:
			_scene.sprite_sheet_texture = sheet
	d.spawners.clear()
	for entry in cfg["spawners"]:
		var s := EnemySpawnerData.new()
		s.position = Vector2(entry["position"][0], entry["position"][1])
		s.initial_velocity = Vector2(entry["initial_velocity"][0], entry["initial_velocity"][1])
		var shape := RectangleShape2D.new()
		shape.size = Vector2(entry["size"][0], entry["size"][1])
		s.shape = shape
		for w in entry["waves"]:
			var wave := EnemySpawnWave.new()
			wave.enemy_type = int(w["enemy_type"])
			wave.amount = int(w["amount"])
			wave.duration = w["duration"]
			s.waves.append(wave)
		d.spawners.append(s)
	_maps[_index]["name"] = cfg["name"]
	_maps[_index]["cfg"] = cfg
	var id: int = _maps[_index].get("id", -1)
	if id >= 0 and GameManager.levels.has(id):
		GameManager.levels[id].name = cfg["name"]
	_refresh_level_menu()          # undo has to reach the menu too


func _save_config() -> void:
	var cfg := _settings()
	var f := FileAccess.open(_dir + "/level.json", FileAccess.WRITE)
	if f == null:
		push_error("[editor] could not write %s/level.json" % _dir)
		return
	f.store_string(JSON.stringify(cfg, "\t"))
	f.close()


## The stock maps make good starting points but are the developers' artwork, so
## they are not redistributed. This copies them out of your own installed game.
func _dump_reference() -> void:
	DirAccess.make_dir_recursive_absolute("user://reference")
	var n := 0
	for k in GameManager.levels:
		var d: LevelData = GameManager.levels[k].data
		d.map_texture.get_image().save_png("user://reference/map_%s.png" % k)
		d.sprite_sheet_texture.get_image().save_png(
			"user://reference/%s" % d.sprite_sheet_texture.resource_path.get_file())
		n += 1
	_refresh_hud("wrote %d maps to user://reference" % n)
