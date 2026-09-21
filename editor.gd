extends Node
## In-game map painter for "Sir, We Have an Orc Problem".
##
## For map makers only. Turn it on by uncommenting the MapEditor autoload in
## override.cfg; it is not in the player zip.
##
##   F11          open the painter, and close it again
##   F5           save and play this map straight away
##   N            move to your next map, if you have more than one
##   Ctrl+N       start a new map
##   left drag    paint          right drag   erase to open ground
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
G ground   R rock   B base   1-9 brush size
Ctrl+S save   Ctrl+Z undo   Ctrl+N new map   Ctrl+E dump stock maps
F5 save and play   F11 close"""

var _maps: Array[Dictionary] = []
var _index := -1
var _dir := ""
var _img: Image
var _tex: ImageTexture
var _undo: Array[Image] = []
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
var _note_at := 0


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	var key := (event as InputEventKey).keycode
	if key == KEY_F11:
		_toggle()
	elif not _open:
		return
	elif key == KEY_N and (event as InputEventKey).ctrl_pressed:
		_new_map()
	elif key == KEY_N:
		_next_map()
	elif key == KEY_F5:
		_save_and_play()
	elif key == KEY_G:
		_paint_with = GROUND
	elif key == KEY_R:
		_paint_with = ROCK
	elif key == KEY_B:
		_paint_with = BASE
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
	_dir = _maps[_index]["dir"]
	_undo.clear()
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
	_regen_now()


func _close() -> void:
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
			MOUSE_BUTTON_MIDDLE:
				_panning = event.pressed
			MOUSE_BUTTON_WHEEL_UP:
				_zoom_at(event.position, 1.1)
			MOUSE_BUTTON_WHEEL_DOWN:
				_zoom_at(event.position, 1.0 / 1.1)
	elif event is InputEventMouseMotion:
		if _panning:
			_cam.position -= event.relative / _cam.zoom
		elif _stroke != 0:
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


func _regen_now() -> void:
	if _scene == null or _regenerating:
		return
	_regenerating = true
	var t := Time.get_ticks_usec()
	await _scene._on_preview_world_data()
	_regenerating = false
	_refresh_hud("rebuilt in %.0f ms" % ((Time.get_ticks_usec() - t) / 1000.0))


# --- coordinates -------------------------------------------------------------

func _cell_at(screen: Vector2) -> Vector2i:
	var world: Vector2 = _cam.position + (screen - _canvas.size / 2.0) / _cam.zoom
	return Vector2i((world / WorldGen.WORLD_UNITS_PER_PIXEL).floor())


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
	_hud.text = "%s%s   %dx%d\npaint: %s   brush: %d   %s\n\n%s" % [
		_maps[_index]["name"], " *" if _dirty else "",
		_img.get_width(), _img.get_height(),
		names.get(_paint_with, "?"), _brush, _note,
		LEGEND + ("   N next map (saves)" if _maps.size() > 1 else "")]


# --- undo, save, reference ---------------------------------------------------

func _push_undo() -> void:
	_undo.append(_img.duplicate())
	if _undo.size() > UNDO_MAX:
		_undo.pop_front()


func _undo_once() -> void:
	if _undo.is_empty():
		return
	_img.copy_from(_undo.pop_back())
	_tex.update(_img)
	_regen.start()
	_canvas.queue_redraw()


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
	_dirty = false
	_refresh_hud("saved")


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
