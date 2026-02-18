extends CanvasLayer

const DECORATION_ENEMY_COUNT := 9
const EDGE_MARGIN := 80
const EDGE_MARGIN_PORTRAIT := 24  # From left/right arena edges
const WALL_INSET_PORTRAIT := 70  # Inset from top/bottom so we only spawn on floor, not on walls
const MENU_PADDING := 16
const MIN_ENEMY_DISTANCE := 50.0
const SPAWN_ATTEMPTS_PER_ENEMY := 50
## Arena designed for 640x360 landscape; in portrait we show center 360x360
const ARENA_SIZE := Vector2(640, 360)

var options_scene = preload("res://scenes/UI/options_menu.tscn")
var highscores_scene = preload("res://scenes/UI/highscores_screen.tscn")
var ability_selector_scene = preload("res://scenes/UI/ability_selector_screen.tscn")

var _enemy_scenes: Array[PackedScene] = [
	preload("res://scenes/game_object/basic_enemy/basic_enemy.tscn"),
	preload("res://scenes/game_object/basic_enemy_2/basic_enemy_2.tscn"),
	preload("res://scenes/game_object/bat_enemy/bat_enemy.tscn"),
	preload("res://scenes/game_object/ghost_enemy/ghost_enemy.tscn"),
	preload("res://scenes/game_object/wizard_enemy/wizard_enemy.tscn"),
	preload("res://scenes/game_object/spider_enemy/spider_enemy.tscn"),
	preload("res://scenes/game_object/ogre_enemy/ogre_enemy.tscn"),
]

func _ready():
	_apply_portrait_layout()
	call_deferred("_setup_decoration_enemies")
	$%PlayButton.pressed.connect(on_play_pressed)
	$%OptionsButton.pressed.connect(on_options_pressed)
	$%HighscoresButton.pressed.connect(on_highscores_pressed)
	$%QuitButton.pressed.connect(on_quit_pressed)


func _apply_portrait_layout() -> void:
	var vp_size := ViewportHelper.get_viewport_size()
	var tilemap: Node2D = get_node_or_null("TileMapLayer")
	var margin_container: MarginContainer = $MarginContainer

	if ViewportHelper.is_portrait():
		# Center the arena in viewport: horizontally center 640-wide in 360, vertically center 360-tall in 640
		if tilemap != null:
			var offset_x := -(ARENA_SIZE.x - vp_size.x) / 2.0
			var offset_y := (vp_size.y - ARENA_SIZE.y) / 2.0
			tilemap.position = Vector2(offset_x, offset_y)
		# Center UI in arena (middle 360px) with equal top/bottom margins
		var arena_margin := int((vp_size.y - ARENA_SIZE.y) / 2.0)
		margin_container.add_theme_constant_override("margin_top", arena_margin)
		margin_container.add_theme_constant_override("margin_bottom", arena_margin)
	else:
		if tilemap != null:
			tilemap.position = Vector2.ZERO
		margin_container.remove_theme_constant_override("margin_top")
		margin_container.remove_theme_constant_override("margin_bottom")


func _get_arena_spawn_bounds() -> Rect2:
	var vp_size := ViewportHelper.get_viewport_size()
	if ViewportHelper.is_portrait():
		# Portrait: spawn only on the arena floor between the walls (not on walls or off-arena)
		var arena_w := minf(ARENA_SIZE.x, vp_size.x)
		var offset_y := int((vp_size.y - ARENA_SIZE.y) / 2.0)
		var edge := EDGE_MARGIN_PORTRAIT
		var wall := WALL_INSET_PORTRAIT
		var floor_top := offset_y + wall
		var floor_height := ARENA_SIZE.y - wall * 2
		return Rect2(edge, floor_top, arena_w - edge * 2, floor_height)
	else:
		return Rect2(EDGE_MARGIN, EDGE_MARGIN, vp_size.x - EDGE_MARGIN * 2, vp_size.y - EDGE_MARGIN * 2)


func _setup_decoration_enemies() -> void:
	await get_tree().process_frame
	await get_tree().process_frame  # Extra frame so layout (margins, centering) is fully applied
	var enemy_paths: Array[String] = []
	for scene in _enemy_scenes:
		enemy_paths.append(scene.resource_path)
	for child in get_children():
		if child.get("scene_file_path") != null and child.scene_file_path in enemy_paths:
			remove_child(child)
			child.queue_free()
	var panel: Control = get_node_or_null("MarginContainer/PanelContainer") as Control
	var menu_rect: Rect2
	var menu_padding := MENU_PADDING
	if ViewportHelper.is_portrait():
		menu_padding = 24  # Large exclusion zone so decoration enemies never overlap the menu
	if panel != null:
		menu_rect = panel.get_global_rect()
		menu_rect = menu_rect.grow(menu_padding)
	else:
		menu_rect = Rect2(Vector2(200, 100), Vector2(240, 160)).grow(menu_padding)
	var spawn_bounds := _get_arena_spawn_bounds()
	var container := Node2D.new()
	container.name = "DecorationEnemies"
	add_child(container)
	var positions: Array[Vector2] = []
	for i in DECORATION_ENEMY_COUNT:
		var pos: Vector2 = _random_valid_position(positions, menu_rect, spawn_bounds, i)
		positions.append(pos)
		var scene: PackedScene = _enemy_scenes.pick_random()
		var enemy: Node2D = scene.instantiate() as Node2D
		enemy.position = pos
		container.add_child(enemy)


func _is_position_valid(p: Vector2, menu_rect: Rect2, spawn_bounds: Rect2) -> bool:
	if p.x < spawn_bounds.position.x or p.x > spawn_bounds.position.x + spawn_bounds.size.x:
		return false
	if p.y < spawn_bounds.position.y or p.y > spawn_bounds.position.y + spawn_bounds.size.y:
		return false
	if menu_rect.has_point(p):
		return false
	return true


func _random_valid_position(existing: Array[Vector2], menu_rect: Rect2, spawn_bounds: Rect2, fallback_index: int) -> Vector2:
	var min_dist_sq: float = MIN_ENEMY_DISTANCE * MIN_ENEMY_DISTANCE
	var attempts := SPAWN_ATTEMPTS_PER_ENEMY
	if ViewportHelper.is_portrait():
		attempts = attempts * 2  # Smaller spawn area in portrait, need more tries
	for attempt in attempts:
		var x: float = randf_range(spawn_bounds.position.x, spawn_bounds.position.x + spawn_bounds.size.x)
		var y: float = randf_range(spawn_bounds.position.y, spawn_bounds.position.y + spawn_bounds.size.y)
		var p := Vector2(x, y)
		if not _is_position_valid(p, menu_rect, spawn_bounds):
			continue
		var ok := true
		for other in existing:
			if p.distance_squared_to(other) < min_dist_sq:
				ok = false
				break
		if ok:
			return p
	# Fallback: place only in strips above or below the menu (never on menu or walls)
	var margin := 12.0
	var usable_w := spawn_bounds.size.x - margin * 2
	var above_menu_y := spawn_bounds.position.y + margin
	var below_menu_y := spawn_bounds.position.y + spawn_bounds.size.y - margin
	# Use only y values that are clearly outside the menu and inside spawn bounds
	above_menu_y = clampf(above_menu_y, spawn_bounds.position.y + margin, menu_rect.position.y - 15.0)
	below_menu_y = clampf(below_menu_y, menu_rect.end.y + 15.0, spawn_bounds.position.y + spawn_bounds.size.y - margin)
	var col := fallback_index % 5
	var row := fallback_index / 5
	var x := spawn_bounds.position.x + margin + (col * usable_w / 4.0) if col < 4 else spawn_bounds.position.x + usable_w / 2.0
	var y: float
	if row == 0:
		y = above_menu_y
	else:
		y = below_menu_y
	var fallback_pos := Vector2(clampf(x, spawn_bounds.position.x + margin, spawn_bounds.position.x + spawn_bounds.size.x - margin), y)
	if menu_rect.has_point(fallback_pos):
		# Force into top or bottom strip
		if fallback_index % 2 == 0:
			y = clampf(above_menu_y, spawn_bounds.position.y + margin, menu_rect.position.y - 10.0)
		else:
			y = clampf(below_menu_y, menu_rect.end.y + 10.0, spawn_bounds.position.y + spawn_bounds.size.y - margin)
		x = spawn_bounds.position.x + margin + (fallback_index * 31) % int(maxf(1, usable_w))
		fallback_pos = Vector2(x, y)
	return fallback_pos


func on_play_pressed():
	var selector_instance = ability_selector_scene.instantiate()
	get_tree().root.add_child(selector_instance)
	selector_instance.back_pressed.connect(on_ability_selector_closed.bind(selector_instance))
	selector_instance.start_pressed.connect(on_ability_selector_start.bind(selector_instance))


func on_ability_selector_closed(selector_instance: Node):
	selector_instance.queue_free()


func on_ability_selector_start(selector_instance: Node):
	selector_instance.queue_free()
	ScreenTransition.transition()
	await ScreenTransition.transitioned_halfway
	$MainMenuMusic.stop()
	get_tree().change_scene_to_file("res://scenes/main/main.tscn")
	
	
func on_options_pressed():
	var options_instance = options_scene.instantiate()
	add_child(options_instance)
	options_instance.back_pressed.connect(on_options_closed.bind(options_instance))


func on_highscores_pressed():
	var highscores_instance = highscores_scene.instantiate()
	# Add to root so it's a sibling of MainMenu, not a child - ensures correct layer/input order
	get_tree().root.add_child(highscores_instance)
	highscores_instance.back_pressed.connect(on_highscores_closed.bind(highscores_instance))


func on_highscores_closed(highscores_instance: Node):
	highscores_instance.queue_free()


func on_quit_pressed():
	get_tree().quit()
	
	
func on_options_closed(options_instance: Node):
	options_instance.queue_free()
