extends Node3D
class_name ForestGenerator

@export_category("Area")
@export var area_size := Vector2(200.0, 200.0) # X,Z size
@export var origin := Vector3.ZERO
@export var ground_y := 0.0

@export_category("Exclusions")
@export var house_finish: Node3D
@export var house_clear_radius := 18.0
@export var exclusion_nodes: Array[Node3D] = []
@export var exclusion_radius := 18.0


@export_category("Ground")
@export var ground: Node3D
@export var use_ground_aabb := true

@export_category("Paths")
@export var main_path_points := 14
@export var path_step := 12.0
@export var path_width := 6.0
@export var branch_count := 8
@export var branch_points := 8
@export var branch_chance := 0.55 # how often branches actually spawn
@export var path_wiggle := 0.75 # 0..1 (higher = more curvy)

@export_category("Scatter Density")
@export var tree_count := 1200
@export var bush_count := 250
@export var grass_count := 900
@export var min_spacing_trees := 3.5
@export var min_spacing_bushes := 2.0
@export var min_spacing_grass := 1.0

@export_category("Trail")
@export var trail_patch_spacing := 5.5      # distance between clusters along the path
@export var trail_patch_radius := 2.2      # how wide each cluster spreads
@export var trail_patch_min := 14          # minimum instances per cluster
@export var trail_patch_max := 32           # maximum instances per cluster
@export var trail_patch_forward_bias := 0.35 # 0..1 stretch along path direction
@export var trail_spacing := 2.2
@export var trail_jitter := 0.6
@export var trail_scale := Vector2(0.8, 1.4)
@export var trail_mislead_ratio := 0.8 # 0..1 (how much trail goes to wrong branches)

@export_category("Assets (PackedScenes)")
@export var tree_scenes: Array[PackedScene] = []
@export var bush_scenes: Array[PackedScene] = []
@export var grass_scenes: Array[PackedScene] = []
@export var trail_scenes: Array[PackedScene] = [] # clover/flowers/petals

@export_category("Random")
@export var seed_value := 1337

var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.seed = seed_value
	generate()

func generate() -> void:
	_clear_previous()
	
		# --- Align generator to your ground mesh ---
	if ground != null:
		origin = ground.global_position

		# If your ground is a MeshInstance3D, auto-get its size from AABB
		if use_ground_aabb and ground is MeshInstance3D:
			var mi := ground as MeshInstance3D
			if mi.mesh != null:
				var aabb := mi.mesh.get_aabb()
				# AABB is in local mesh space; multiply by scale for world-ish size
				var world_scale := mi.global_transform.basis.get_scale()
				area_size = Vector2(aabb.size.x * world_scale.x, aabb.size.z * world_scale.z)


		ground_y = ground.global_position.y

	# 1) Make paths (main + branches)
	var main_path := _make_path_polyline(main_path_points, true)
	var branches: Array[PackedVector3Array] = []
	for i in branch_count:
		if _rng.randf() <= branch_chance:
			branches.append(_make_branch_from(main_path, branch_points))

	# 2) Choose which paths get "trail" (mostly misleading)
	var trail_paths: Array[PackedVector3Array] = []
	var misleading_count := int(round(branches.size() * trail_mislead_ratio))
	branches.shuffle()
	for i in range(min(misleading_count, branches.size())):
		trail_paths.append(branches[i])
	if _rng.randf() < (1.0 - trail_mislead_ratio) and _rng.randf() < 0.35:
		trail_paths.append(_subsection(main_path, 0.15, 0.55))

	# 3) Scatter vegetation using MultiMeshes, avoiding paths
	var all_paths := [main_path]
	for b in branches:
		all_paths.append(b)

	_scatter_group_multimesh(tree_scenes, tree_count, min_spacing_trees, all_paths, path_width)
	_scatter_group_multimesh(bush_scenes, bush_count, min_spacing_bushes, all_paths, path_width * 0.85)
	_scatter_group_multimesh(grass_scenes, grass_count, min_spacing_grass, all_paths, path_width * 0.65)

	# 4) Place trails (can be MeshInstances, because count is usually smaller)
	_place_trails(trail_paths)

func _is_in_exclusion(p: Vector3, extra_radius := 0.0) -> bool:
	for n in exclusion_nodes:
		if n == null:
			continue
		var d := Vector2(p.x, p.z).distance_to(Vector2(n.global_position.x, n.global_position.z))
		if d < (exclusion_radius + extra_radius):
			return true
	return false


func _distance_to_exclusions(p: Vector3) -> float:
	var best := INF
	if house_finish != null:
		var d := Vector2(p.x, p.z).distance_to(Vector2(house_finish.global_position.x, house_finish.global_position.z)) - house_clear_radius
		best = min(best, d)
	return best

func _clear_previous() -> void:
	for c in get_children():
		c.queue_free()

func _make_path_polyline(points_count: int, start_edge: bool) -> PackedVector3Array:
	# Start on one edge, end on the opposite, with a noisy walk
	var half := area_size * 0.5
	var start_x := origin.x - half.x + _rng.randf_range(10.0, 25.0) if start_edge else origin.x + _rng.randf_range(-half.x, half.x)
	var end_x := origin.x + half.x - _rng.randf_range(10.0, 25.0)

	var z := origin.z + _rng.randf_range(-half.y * 0.4, half.y * 0.4)
	var x := start_x

	var pts := PackedVector3Array()
	pts.append(Vector3(x, ground_y, z))

	for i in range(points_count - 2):
		var t := float(i + 1) / float(points_count - 1)
		var target_x := lerp(start_x, end_x, t)

		# advance mostly in X with sideways wiggle in Z
		x = lerp(x, target_x, 0.8)
		var wig := _rng.randf_range(-1.0, 1.0) * path_step * path_wiggle
		z = clampf(z + wig, origin.z - half.y + 12.0, origin.z + half.y - 12.0)

		pts.append(Vector3(x, ground_y, z))

	pts.append(Vector3(end_x, ground_y, z + _rng.randf_range(-6.0, 6.0)))
	return pts

func _make_branch_from(main_path: PackedVector3Array, points_count: int) -> PackedVector3Array:
	# Pick a random anchor on main path and branch out, then curl back toward woods
	var idx := _rng.randi_range(2, main_path.size() - 3)
	var anchor := main_path[idx]

	var half := area_size * 0.5
	var dir := Vector3(0, 0, _rng.randf_range(-1.0, 1.0)).normalized()
	if dir.length() < 0.001:
		dir = Vector3(0, 0, 1)

	var pts := PackedVector3Array()
	pts.append(anchor)

	var p := anchor
	for i in range(points_count - 1):
		var turn := _rng.randf_range(-0.8, 0.8)
		dir = dir.rotated(Vector3.UP, turn * 0.35).normalized()
		p += Vector3(path_step * 0.7, 0, 0) * _rng.randf_range(0.25, 0.55) # slight forward drift
		p += dir * _rng.randf_range(path_step * 0.8, path_step * 1.2)

		p.x = clampf(p.x, origin.x - half.x + 8.0, origin.x + half.x - 8.0)
		p.z = clampf(p.z, origin.z - half.y + 8.0, origin.z + half.y - 8.0)

		pts.append(Vector3(p.x, ground_y, p.z))

	return pts

func _subsection(path: PackedVector3Array, a: float, b: float) -> PackedVector3Array:
	var i0 := int(floor((path.size() - 1) * a))
	var i1 := int(ceil((path.size() - 1) * b))
	var out := PackedVector3Array()
	for i in range(i0, i1 + 1):
		out.append(path[i])
	return out

# Scattering (MultiMesh)

func _scatter_group_multimesh(
	scenes: Array[PackedScene],
	count: int,
	min_spacing: float,
	paths: Array,
	avoid_radius: float
) -> void:
	if scenes.is_empty() or count <= 0:
		return

	# Collect transforms per unique mesh (one MultiMesh per mesh)
	var transforms_by_mesh: Dictionary = {} # Mesh -> Array[Transform3D]

	var accepted_positions: Array[Vector3] = []
	var half := area_size * 0.5
	var attempts := count * 25

	for _i in attempts:
		if accepted_positions.size() >= count:
			break

		var pos := Vector3(
			_rng.randf_range(origin.x - half.x, origin.x + half.x),
			ground_y,
			_rng.randf_range(origin.z - half.y, origin.z + half.y)
		)

		# avoid paths
		if _distance_to_paths(pos, paths) < avoid_radius:
			continue
		
		# avoid house/building clearing
		if _is_in_exclusion(pos):
			continue

		# avoid house clearing
		if _distance_to_exclusions(pos) < 0.0:
			continue

		# simple spacing vs same group
		if _too_close(pos, accepted_positions, min_spacing):
			continue

		accepted_positions.append(pos)

		var scene := scenes[_rng.randi_range(0, scenes.size() - 1)]
		var mesh := _extract_mesh_from_scene(scene)
		if mesh == null:
			continue

		var yaw := _rng.randf_range(0.0, TAU)
		var sc := _rng.randf_range(0.85, 1.25)

		var t := Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * sc), pos)

		if not transforms_by_mesh.has(mesh):
			transforms_by_mesh[mesh] = []
		transforms_by_mesh[mesh].append(t)

	# Build MultiMeshes
	for mesh in transforms_by_mesh.keys():
		var xforms: Array = transforms_by_mesh[mesh]
		_add_multimesh(mesh, xforms)

func _add_multimesh(mesh: Mesh, xforms: Array) -> void:
	var mm := MultiMesh.new()
	mm.mesh = mesh
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = xforms.size()

	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])

	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	add_child(mmi)

func _extract_mesh_from_scene(scene: PackedScene) -> Mesh:
	var inst := scene.instantiate()
	var mesh: Mesh = null

	var stack: Array[Node] = [inst]
	while not stack.is_empty():
		var n := stack.pop_back()
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			if mi.mesh != null:
				mesh = mi.mesh
				break
		for c in n.get_children():
			stack.append(c)

	inst.queue_free()
	return mesh

# ----------------------------
# Trails (flowers / clovers)
# ----------------------------

func _place_trails(paths: Array[PackedVector3Array]) -> void:
	if trail_scenes.is_empty():
		print("Trail scenes array is empty!")
		return
	if paths.is_empty():
		print("No trail paths selected!")
		return

	for path in paths:
		_place_trail_patches_on_path(path)

func _place_trail_patches_on_path(path: PackedVector3Array) -> void:
	# Patch centers along the path
	var centers: Array[Vector3] = _resample_polyline(path, trail_patch_spacing)

	for i in range(centers.size()):
		var center := centers[i]
		center.y = ground_y

		# estimate forward direction for slight stretching along the path
		var forward := Vector3(1, 0, 0)
		if centers.size() >= 2:
			var prev := centers[max(i - 1, 0)]
			var next := centers[min(i + 1, centers.size() - 1)]
			var dir := (next - prev)
			dir.y = 0.0
			if dir.length() > 0.001:
				forward = dir.normalized()

		var count := _rng.randi_range(trail_patch_min, trail_patch_max)

		for _k in range(count):
			var scene := trail_scenes[_rng.randi_range(0, trail_scenes.size() - 1)]
			var inst := scene.instantiate()

			# Always wrap in a Node3D so we can transform it even if root isn't Node3D
			var holder := Node3D.new()
			holder.name = "TrailPatchItem"
			add_child(holder)
			holder.add_child(inst)

			# random offset in a disk + a little stretch along forward direction
			var r := sqrt(_rng.randf()) * trail_patch_radius
			var ang := _rng.randf_range(0.0, TAU)
			var offset_side := Vector3(cos(ang), 0, sin(ang)) * r

			var offset_fwd := forward * _rng.randf_range(-trail_patch_radius, trail_patch_radius) * trail_patch_forward_bias
			var pos := center + offset_side + offset_fwd

			# small per-item jitter so it doesn't look stamped
			pos.x += _rng.randf_range(-trail_jitter, trail_jitter)
			pos.z += _rng.randf_range(-trail_jitter, trail_jitter)
			pos.y = ground_y + 0.02

			holder.global_position = pos
			holder.rotation.y = _rng.randf_range(0.0, TAU)

			var sc := _rng.randf_range(trail_scale.x, trail_scale.y)
			holder.scale = Vector3.ONE * sc

func _resample_polyline(poly: PackedVector3Array, step: float) -> Array[Vector3]:
	var out: Array[Vector3] = []
	if poly.size() < 2:
		return out

	var remaining := 0.0
	out.append(poly[0])

	for i in range(poly.size() - 1):
		var a := poly[i]
		var b := poly[i + 1]
		var seg := b - a
		var seg_len := seg.length()
		if seg_len <= 0.0001:
			continue

		var dir := seg / seg_len
		var d := step - remaining
		while d <= seg_len:
			out.append(a + dir * d)
			d += step
		remaining = seg_len - (d - step)

	return out

# ----------------------------
# Helpers
# ----------------------------

func _distance_to_paths(p: Vector3, paths: Array) -> float:
	var best := INF
	for poly in paths:
		var d := _distance_to_polyline(p, poly)
		if d < best:
			best = d
	return best

func _distance_to_polyline(p: Vector3, poly: PackedVector3Array) -> float:
	var best := INF
	for i in range(poly.size() - 1):
		var a := poly[i]
		var b := poly[i + 1]
		var d := _distance_point_segment_xz(p, a, b)
		if d < best:
			best = d
	return best

func _distance_point_segment_xz(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ap := Vector2(p.x - a.x, p.z - a.z)
	var ab := Vector2(b.x - a.x, b.z - a.z)
	var ab_len2 := ab.length_squared()
	if ab_len2 <= 0.000001:
		return ap.length()
	var t := clampf(ap.dot(ab) / ab_len2, 0.0, 1.0)
	var closest := Vector2(a.x, a.z) + ab * t
	return Vector2(p.x, p.z).distance_to(closest)

func _too_close(p: Vector3, others: Array[Vector3], min_dist: float) -> bool:
	var md2 := min_dist * min_dist
	for o in others:
		if Vector2(p.x, p.z).distance_squared_to(Vector2(o.x, o.z)) < md2:
			return true
	return false
