extends Node3D

@export var enemy_scene: PackedScene                
@export var max_alive: int = 10
@export var spawn_on_start: bool = true
@export var spawn_interval: float = 5.0

var _spawn_points: Array[Node3D] = []
var _alive_enemies: Array[Node3D] = []
var _rng := RandomNumberGenerator.new()

@onready var _spawn_timer: Timer = $SpawnTimer


func _ready() -> void:
	await get_tree().process_frame

	_collect_spawn_points()

	if enemy_scene == null:
		push_warning("EnemySpawnerManager: 'enemy_scene' is NOT assigned!")
		return

	if _spawn_points.is_empty():
		push_warning("EnemySpawnerManager: No spawn points found as children!")
		return

	_spawn_timer.wait_time = spawn_interval
	_spawn_timer.one_shot = false
	_spawn_timer.autostart = false
	_spawn_timer.timeout.connect(_on_spawn_timer_timeout)

	if spawn_on_start:
		_spawn_timer.start()


func _collect_spawn_points() -> void:
	_spawn_points.clear()
	for child in get_children():
		if child is Marker3D or child is Node3D:
			_spawn_points.append(child)


func _on_spawn_timer_timeout() -> void:
	_cleanup_dead_enemies()

	if _alive_enemies.size() >= max_alive:
		return

	_spawn_enemy()


func _spawn_enemy() -> void:
	if enemy_scene == null or _spawn_points.is_empty():
		return

	var spawn_point := _spawn_points[_rng.randi_range(0, _spawn_points.size() - 1)]

	var enemy := enemy_scene.instantiate()

	# Add to scene BEFORE setting transform
	get_parent().add_child(enemy)

	enemy.global_position = spawn_point.global_position

	_alive_enemies.append(enemy)


func _cleanup_dead_enemies() -> void:
	_alive_enemies = _alive_enemies.filter(func(e):
		return is_instance_valid(e)
	)
