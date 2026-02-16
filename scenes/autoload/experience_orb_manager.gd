extends Node

## Periodically merges experience orbs with tiered thresholds.
## Tier 1: 25 orbs → merge 5 into 1 (5 value). Tier 2: 125 value → merge 25 into 1. Each tier 50% larger.

@export var merge_interval: float = 5
@export var off_screen_radius: float = 110.0
@export var on_screen_radius: float = 55.0
@export var off_screen_margin: float = 80.0

## Tier 1: min 25 orbs in radius to merge 5 into 1 (5 value orb).
const TIER1_MIN_COUNT := 25
const TIER1_MERGE_COUNT := 5
## Tier 2+: min total value to merge. Each tier 50% larger than previous.
const TIER2_MIN_VALUE := 125
const TIER2_MERGE_VALUE := 25
const TIER_GROWTH := 1.5

var _merge_timer: float = 0.0
var _value_tiers: Array[Dictionary] = []


func _ready() -> void:
	_build_value_tiers()


func _build_value_tiers() -> void:
	_value_tiers.clear()
	var min_val := TIER2_MIN_VALUE
	var merge_val := TIER2_MERGE_VALUE
	while merge_val < 10000:
		_value_tiers.append({"min_value": int(min_val), "merge_value": int(merge_val)})
		min_val *= TIER_GROWTH
		merge_val = int(merge_val * TIER_GROWTH)


func _process(delta: float) -> void:
	_merge_timer -= delta
	if _merge_timer <= 0.0:
		_merge_timer = merge_interval
		_try_merge_orbs()


func _try_merge_orbs() -> void:
	if _value_tiers.is_empty():
		_build_value_tiers()
	var tree = get_tree()
	if tree == null:
		return
	var orbs: Array[Node2D] = []
	for node in tree.get_nodes_in_group("experience_vial"):
		if node is Node2D and is_instance_valid(node):
			orbs.append(node as Node2D)
	if orbs.size() < 2:
		return

	var to_free: Array[Node2D] = []
	var merged: Dictionary = {}

	for orb in orbs:
		if merged.get(orb, false):
			continue
		var is_off := _is_off_screen(orb)
		var merge_radius := off_screen_radius if is_off else on_screen_radius
		var in_radius := _get_orbs_in_radius(orb, orbs, merged, merge_radius)
		if in_radius.size() < 2:
			continue

		var total_value: float = 0.0
		for o in in_radius:
			total_value += o.experience_value if "experience_value" in o else 1.0

		var centroid := Vector2.ZERO
		for o in in_radius:
			centroid += o.global_position
		centroid /= in_radius.size()

		# Check value tiers first (highest to lowest)
		var did_merge := false
		for i in range(_value_tiers.size() - 1, -1, -1):
			var tier: Dictionary = _value_tiers[i]
			if total_value >= tier.min_value:
				var to_merge := _pick_orbs_for_value(in_radius, merged, tier.merge_value)
				if to_merge.size() >= 2:
					_do_merge(to_merge, centroid, tier.merge_value, merged, to_free)
					did_merge = true
					break

		# Tier 1: merge by count (25 orbs → merge 5 into 1)
		if not did_merge:
			var available: Array[Node2D] = []
			for o in in_radius:
				if not merged.get(o, false):
					available.append(o)
			if available.size() >= TIER1_MIN_COUNT and available.size() >= TIER1_MERGE_COUNT:
				var to_merge: Array[Node2D] = []
				for i in TIER1_MERGE_COUNT:
					to_merge.append(available[i])
				var merge_value: float = 0.0
				for o in to_merge:
					merge_value += o.experience_value if "experience_value" in o else 1.0
				_do_merge(to_merge, centroid, merge_value, merged, to_free)

	for orb in to_free:
		if is_instance_valid(orb):
			orb.queue_free()


func _pick_orbs_for_value(orbs: Array[Node2D], merged: Dictionary, target_value: float) -> Array[Node2D]:
	var result: Array[Node2D] = []
	var sum := 0.0
	# Sort by value ascending to merge smallest first
	var sorted: Array[Node2D] = orbs.duplicate()
	sorted.sort_custom(func(a, b): return _orb_value(a) < _orb_value(b))
	for o in sorted:
		if merged.get(o, false):
			continue
		result.append(o)
		sum += _orb_value(o)
		if sum >= target_value:
			break
	return result


func _orb_value(orb: Node2D) -> float:
	return orb.experience_value if "experience_value" in orb else 1.0


func _do_merge(to_merge: Array[Node2D], centroid: Vector2, merge_value: float, merged: Dictionary, to_free: Array[Node2D]) -> void:
	var survivor: Node2D = to_merge[0]
	survivor.experience_value = merge_value
	survivor.global_position = centroid
	if survivor.has_method("update_visual_scale"):
		survivor.update_visual_scale()
	for o in to_merge:
		merged[o] = true
	for i in range(1, to_merge.size()):
		to_free.append(to_merge[i])


func _get_orbs_in_radius(center: Node2D, orbs: Array[Node2D], merged: Dictionary, radius: float) -> Array[Node2D]:
	var result: Array[Node2D] = []
	var radius_sq := radius * radius
	for orb in orbs:
		if merged.get(orb, false):
			continue
		if not is_instance_valid(orb):
			continue
		if center.global_position.distance_squared_to(orb.global_position) <= radius_sq:
			result.append(orb)
	return result


func _is_off_screen(orb: Node2D) -> bool:
	var cam = get_viewport().get_camera_2d()
	if cam == null:
		return false
	var vp_rect = get_viewport().get_visible_rect()
	var world_size = vp_rect.size / cam.zoom
	var visible_rect = Rect2(cam.get_screen_center_position() - world_size / 2, world_size)
	visible_rect = visible_rect.grow(off_screen_margin)
	return not visible_rect.has_point(orb.global_position)
