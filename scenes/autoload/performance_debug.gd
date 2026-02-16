extends Node

## Enable to print FPS/enemy stats every few seconds. Set PERFORMANCE_DEBUG_ENABLED = true to use.
const PERFORMANCE_DEBUG_ENABLED := true
const PRINT_INTERVAL := 3.0

var _timer: float = 0.0


func _process(delta: float) -> void:
	if not PERFORMANCE_DEBUG_ENABLED:
		return
	_timer += delta
	if _timer < PRINT_INTERVAL:
		return
	_timer = 0.0

	var tree := get_tree()
	if tree == null:
		return
	var enemy_count := tree.get_nodes_in_group("enemy").size()
	var orb_count := tree.get_nodes_in_group("experience_vial").size()
	var fps := Engine.get_frames_per_second()
	var process_ms := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var physics_ms := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0

	print("[Perf] FPS: %d | Process: %.2fms | Physics: %.2fms | Enemies: %d | Orbs: %d" % [fps, process_ms, physics_ms, enemy_count, orb_count])
