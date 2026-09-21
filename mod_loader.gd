extends Node
## Adds user-made levels to "Sir, We Have an Orc Problem", and previews them with the
## game's own level-editor script. That script's drawing runs fine at runtime; its
## editing UI is the Godot editor's and does not exist here, so F9 is a viewer.
##
## Every subfolder of user://mods needs a level.json and the map PNG it names.
## F9  cycles the editor through your maps, re-reading them from disk each press.
## F10 closes the editor.

const MODS_DIR := "user://mods"
const EDITOR_SCENE := "res://levels/level_1_1/level_1_1.tscn"

var _levels: Array[Dictionary] = []
var _stock_count := -1
var _edit_index := -1
var _in_editor := false
var _overlay: CanvasLayer = null
var _sub: SubViewport = null


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(node: Node) -> void:
	if node.name == "LevelContainer":
		_inject()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	# ESC is not usable here: GameManager handles ui_cancel first and consumes it.
	if event.keycode == KEY_F9:
		_open_editor()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_F10 and _in_editor:
		_close_editor()
		get_viewport().set_input_as_handled()


# --- level registration ------------------------------------------------------

func _inject() -> void:
	if _levels.is_empty():
		_read_mods()
	if _stock_count < 0:
		_stock_count = GameManager.levels.size()
	var saved: Dictionary = {}
	if SaveSystem.current_save_slot >= 0:
		saved = SaveSystem.load_save_data(SaveSystem.current_save_slot).get("levels", {})
	var id := _stock_count
	for entry in _levels:
		id += 1
		entry["id"] = id
		var existing = GameManager.levels.get(id)
		if existing != null and existing.name == entry["name"]:
			existing.data = entry["data"]   # keep progress, take the edited map
			continue
		var level = GameManager.Level.new(entry["name"], entry["data"])
		_restore(level, saved.get(str(id), {}))
		GameManager.levels[id] = level


## The game saves our levels along with its own, but GameManager.load_data() only
## rebuilds the stock ones -- we are registered afterwards. Without this the fresh
## entry overwrites real progress on the next save.
func _restore(level, saved: Dictionary) -> void:
	if saved.is_empty():
		return
	level.has_survived = saved.get("has_survived", false)
	level.has_killed_all = saved.get("has_killed_all", false)
	level.towers.clear()
	level.towers.append_array(saved.get("towers", []))
	var stats: Dictionary = saved.get("stats", {})
	for key in stats:
		# JSON numbers all arrive as floats; the counters are ints.
		var current = level.stats.get(key)
		level.stats.set(key, int(stats[key]) if typeof(current) == TYPE_INT else stats[key])


func _read_mods() -> void:
	_levels.clear()
	var dirs := DirAccess.get_directories_at(MODS_DIR)
	dirs.sort()       # ids key the save data, so the order must be stable
	for dir_name in dirs:
		var base := "%s/%s" % [MODS_DIR, dir_name]
		var cfg = JSON.parse_string(FileAccess.get_file_as_string(base + "/level.json"))
		if cfg == null:
			push_error("[mods] %s: missing or malformed level.json" % dir_name)
			continue
		var name: String = cfg.get("name", dir_name)
		_levels.append({"name": name, "dir": base, "cfg": cfg,
			"data": _build_level(base, cfg)})
		print("[mods] loaded '%s'" % name)


## Re-read the mods from disk and hand them over. Used by the map editor, which is a
## separate autoload so that players never carry it.
func map_list() -> Array[Dictionary]:
	_read_mods()
	if _stock_count >= 0:
		_inject()      # otherwise a battle would still use the pre-edit map
	return _levels


func _build_level(base: String, cfg: Dictionary) -> LevelData:
	var map_path: String = base + "/" + cfg.get("map", "map.png")
	var img: Image
	if FileAccess.file_exists(map_path):
		img = Image.load_from_file(map_path)
		img.convert(Image.FORMAT_RGBA8)
	else:
		# a new map, not yet painted: a walled box at the requested size
		var wh: Array = cfg.get("map_size", [128, 128])
		img = Image.create(int(wh[0]), int(wh[1]), false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		for i in 4:
			img.fill_rect(Rect2i(i, i, img.get_width() - i * 2, 1), Color(0, 0, 1, 1))
			img.fill_rect(Rect2i(i, img.get_height() - 1 - i, img.get_width() - i * 2, 1), Color(0, 0, 1, 1))
			img.fill_rect(Rect2i(i, i, 1, img.get_height() - i * 2), Color(0, 0, 1, 1))
			img.fill_rect(Rect2i(img.get_width() - 1 - i, i, 1, img.get_height() - i * 2), Color(0, 0, 1, 1))

	var d := LevelData.new()
	d.map_texture = ImageTexture.create_from_image(img)
	d.world_size = Vector2(img.get_size()) * WorldGen.WORLD_UNITS_PER_PIXEL
	d.sprite_sheet_texture = load(cfg["sprite_sheet"])
	d.wall_tiles_count = cfg.get("wall_tiles_count", 1)
	d.ground_tiles_count = cfg.get("ground_tiles_count", 1)
	d.enemy_health_buff = cfg.get("enemy_health_buff", 1.0)
	d.level_bonus_marks = cfg.get("level_bonus_marks", 0)
	d.marks_upon_survival = cfg.get("marks_upon_survival", 0)
	d.marks_upon_all_killed = cfg.get("marks_upon_all_killed", 0)

	for s in cfg.get("spawners", []):
		var spawner := EnemySpawnerData.new()
		spawner.position = _vec(s["position"])
		spawner.initial_velocity = _vec(s.get("initial_velocity", [0, 0]))
		var shape := RectangleShape2D.new()
		shape.size = _vec(s.get("size", [20, 60]))
		spawner.shape = shape
		for w in s.get("waves", []):
			var wave := EnemySpawnWave.new()
			wave.enemy_type = w.get("enemy_type", 0)
			wave.amount = w.get("amount", 100)
			wave.duration = w.get("duration", 30.0)
			spawner.waves.append(wave)
		d.spawners.append(spawner)
	return d


func _vec(a: Array) -> Vector2:
	return Vector2(a[0], a[1])


# --- the game's own level-editor script, used to preview your map ------------
#
# The editor lives in a SubViewport laid over the game. Nothing in the running
# scene is touched: swapping scenes out from under a live tooltip popup frees the
# window it is connected to, and the game dies.

func _build_overlay() -> void:
	_overlay = CanvasLayer.new()
	_overlay.layer = 128
	var container := SubViewportContainer.new()
	container.stretch = true
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.mouse_filter = Control.MOUSE_FILTER_STOP
	_sub = SubViewport.new()
	_sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(_sub)
	_overlay.add_child(container)
	get_tree().root.add_child(_overlay)


func _close_editor() -> void:
	_in_editor = false
	if _overlay == null:
		return
	_overlay.visible = false
	for c in _sub.get_children():
		c.queue_free()


func _open_editor() -> void:
	_read_mods()
	if _levels.is_empty():
		push_error("[mods] nothing in %s to edit" % MODS_DIR)
		return
	if _stock_count >= 0:
		_inject()          # re-register so a battle uses the map you just edited
	if _overlay == null:
		_build_overlay()
	for c in _sub.get_children():
		_sub.remove_child(c)
		c.queue_free()

	_edit_index = (_edit_index + 1) % _levels.size()
	var entry := _levels[_edit_index]
	var data: LevelData = entry["data"]

	var ed: Node2D = load(EDITOR_SCENE).instantiate()
	ed.map_texture = data.map_texture
	ed.sprite_sheet_texture = data.sprite_sheet_texture
	ed.enemy_health_buff = data.enemy_health_buff
	_place_spawners(ed.get_node("EnemySpawners"), data.spawners)
	_sub.add_child(ed)
	_overlay.visible = true
	_in_editor = true

	var cam := Camera2D.new()
	cam.position = data.world_size / 2.0
	var vp := Vector2(_sub.size)
	cam.zoom = Vector2.ONE * minf(vp.x / data.world_size.x, vp.y / data.world_size.y) * 0.9
	ed.add_child(cam)
	cam.make_current()

	await ed._on_preview_world_data()
	ed._on_preview_health_values()
	print("[mods] editing '%s'  world=%s  wall polygons=%d" % [
		entry["name"], data.world_size, ed.get_node("WorldCollision").get_child_count()])


func _place_spawners(parent: Node, spawners: Array) -> void:
	var template: Node2D = parent.get_child(0)
	for child in parent.get_children():
		parent.remove_child(child)
	for s in spawners:
		var node: Node2D = template.duplicate()
		node.position = s.position
		node.shape = s.shape
		node.initial_velocity = s.initial_velocity
		node.waves = s.waves
		parent.add_child(node)
	template.queue_free()
