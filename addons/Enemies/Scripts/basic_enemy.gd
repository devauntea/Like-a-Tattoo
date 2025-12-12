extends CharacterBody3D
class_name BasicEnemy

@export var max_health: float = 50.0
@export var can_display_damage_number: bool = true

# Movement / AI settings
@export var move_speed: float = 3.0
@export var detection_radius: float = 100.0      # start chasing at this distance
@export var gravity: float = 9.8

# Attack settings (health damage)
@export var attack_radius: float = 0.5         # must be <= detection_radius
@export var attack_damage: int = 10
@export var attack_cooldown: float = 1.0

# Sanity drain settings
@export var sanity_damage: int = 5
@export var sanity_cooldown: float = 1.0       # seconds between sanity hits

var health: float
var is_dead: bool = false

var player: CharacterBody3D = null
var _attack_cd_timer: float = 0.0
var _sanity_cd_timer: float = 0.0

@onready var anim: AnimationPlayer = $Model/AnimationPlayer
@onready var damage_number_spawn: Marker3D = $DamageNumberSpawnPoint


func _ready() -> void:
	health = max_health
	if anim and anim.has_animation("idle"):
		anim.play("idle")


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	_find_player()
	if player == null:
		return

	# tick cooldowns
	if _attack_cd_timer > 0.0:
		_attack_cd_timer = max(_attack_cd_timer - delta, 0.0)
	if _sanity_cd_timer > 0.0:
		_sanity_cd_timer = max(_sanity_cd_timer - delta, 0.0)

	# gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

	var distance := _chase_player_and_get_distance()

	_try_attack(distance)
	_try_sanity_damage(distance)

	move_and_slide()


func _find_player() -> void:
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("Player") as CharacterBody3D


func _chase_player_and_get_distance() -> float:
	var to_player: Vector3 = player.global_position - global_position
	var flat := Vector3(to_player.x, 0.0, to_player.z)
	var distance := flat.length()

	if distance < detection_radius and distance > 0.05:
		var dir: Vector3 = flat.normalized()

		look_at(
			Vector3(player.global_position.x, global_position.y, player.global_position.z),
			Vector3.UP
		)

		velocity.x = dir.x * move_speed
		velocity.z = dir.z * move_speed

		if anim and anim.has_animation("walk"):
			if anim.current_animation != "walk":
				anim.play("walk")
	else:
		velocity.x = 0.0
		velocity.z = 0.0

		if anim and anim.has_animation("idle"):
			if anim.current_animation != "idle":
				anim.play("idle")

	return distance


func _try_attack(distance: float) -> void:
	if distance <= attack_radius and _attack_cd_timer <= 0.0:
		if player != null and player.has_method("apply_damage"):
			player.apply_damage(attack_damage)
		_attack_cd_timer = attack_cooldown


func _try_sanity_damage(distance: float) -> void:
	# "once you get close to an enemy" -> within detection_radius
	if distance <= detection_radius and _sanity_cd_timer <= 0.0:
		if player != null and player.has_method("lose_sanity"):
			player.lose_sanity(sanity_damage)
		_sanity_cd_timer = sanity_cooldown


# ===== DAMAGE FROM PLAYER =====
func hitscanHit(damage_val: float, _dir: Vector3, _pos: Vector3) -> void:
	_apply_damage(damage_val)

func projectileHit(damage_val: float, _dir: Vector3) -> void:
	_apply_damage(damage_val)


func _apply_damage(amount: float) -> void:
	if is_dead:
		return

	health -= amount

	if can_display_damage_number:
		DamageNumberScript.displayNumber(
			amount,
			damage_number_spawn.global_position,
			110,
			DamageNumberScript.DamageType.NORMAL
		)

	if health <= 0.0:
		_die()


func _die() -> void:
	is_dead = true
	velocity = Vector3.ZERO

	if anim and anim.has_animation("die"):
		anim.play("die")
	else:
		queue_free()
