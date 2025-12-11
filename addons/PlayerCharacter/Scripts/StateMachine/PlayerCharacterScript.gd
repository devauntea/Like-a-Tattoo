extends CharacterBody3D

class_name PlayerCharacter 

@export_group("Movement variables")
var moveSpeed : float
var moveAccel : float
var moveDeccel : float
var desiredMoveSpeed : float 
@export var desiredMoveSpeedCurve : Curve
@export var maxSpeed : float
@export var inAirMoveSpeedCurve : Curve
var inputDirection : Vector2 
var moveDirection : Vector3 
@export var hitGroundCooldown : float
var hitGroundCooldownRef : float 
@export var bunnyHopDmsIncre : float
@export var autoBunnyHop : bool = false
var lastFramePosition : Vector3 
var lastFrameVelocity : Vector3
var wasOnFloor : bool
var walkOrRun : String = "WalkState"
@export var baseHitboxHeight : float
@export var baseModelHeight : float
@export var heightChangeSpeed : float

@export_group("Crouch variables")
@export var crouchSpeed : float
@export var crouchAccel : float
@export var crouchDeccel : float
@export var continiousCrouch : bool = false
@export var crouchHitboxHeight : float
@export var crouchModelHeight : float

@export_group("Walk variables")
@export var walkSpeed : float
@export var walkAccel : float
@export var walkDeccel : float

@export_group("Run variables")
@export var runSpeed : float
@export var runAccel : float 
@export var runDeccel : float 
@export var continiousRun : bool = false

@export_group("Jump variables")
@export var jumpHeight : float
@export var jumpTimeToPeak : float
@export var jumpTimeToFall : float
@onready var jumpVelocity : float = (2.0 * jumpHeight) / jumpTimeToPeak
@export var jumpCooldown : float
var jumpCooldownRef : float 
@export var nbJumpsInAirAllowed : int 
var nbJumpsInAirAllowedRef : int 
var jumpBuffOn : bool = false
var bufferedJump : bool = false
@export var coyoteJumpCooldown : float
var coyoteJumpCooldownRef : float
var coyoteJumpOn : bool = false
@export_range(0.1, 1.0, 0.05) var inAirInputMultiplier: float = 1.0

@export_group("Gravity variables")
@onready var jumpGravity : float = (-2.0 * jumpHeight) / (jumpTimeToPeak * jumpTimeToPeak)
@onready var fallGravity : float = (-2.0 * jumpHeight) / (jumpTimeToFall * jumpTimeToFall)

@export_group("Keybind variables")
@export var moveForwardAction : String = ""
@export var moveBackwardAction : String = ""
@export var moveLeftAction : String = ""
@export var moveRightAction : String = ""
@export var runAction : String = ""
@export var crouchAction : String = ""
@export var jumpAction : String = ""

@export_group("Health variables")
@export var max_health: int = 100
var health: int

@export_group("Sanity variables")
@export var max_sanity: int = 100
var sanity: int

@export_group("Regen variables")
@export var health_regen_enabled: bool = true
@export var health_regen_delay: float = 5.0     # seconds after last damage before regen starts
@export var health_regen_amount: int = 5        # amount per tick

@export var sanity_regen_enabled: bool = true
@export var sanity_regen_delay: float = 5.0     # seconds after last sanity loss before regen starts
@export var sanity_regen_amount: int = 5        # amount per tick

var _health_regen_cooldown: float = 0.0
var _sanity_regen_cooldown: float = 0.0

signal health_changed(current: int, max: int)
signal died
signal sanity_changed(current: int, max: int)

#references variables
@onready var camHolder : Node3D = $CameraHolder
@onready var model : MeshInstance3D = $Model
@onready var hitbox : CollisionShape3D = $Hitbox
@onready var stateMachine : Node = %StateMachine
@onready var ceilingCheck : RayCast3D = $Raycasts/CeilingCheck
@onready var floorCheck : RayCast3D = $Raycasts/FloorCheck

# HUD will be found by group at runtime (group "HUD" on the HUD root CanvasLayer)
var hud: CanvasLayer = null


func _ready():
	# capture mouse for looking
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	# set move variables, and value references
	moveSpeed = walkSpeed
	moveAccel = walkAccel
	moveDeccel = walkDeccel
	
	hitGroundCooldownRef = hitGroundCooldown
	jumpCooldownRef = jumpCooldown
	nbJumpsInAirAllowedRef = nbJumpsInAirAllowed
	coyoteJumpCooldownRef = coyoteJumpCooldown

	# init health
	health = max_health
	emit_signal("health_changed", health, max_health)

	# init sanity
	sanity = max_sanity
	emit_signal("sanity_changed", sanity, max_sanity)

	# init regen cooldowns
	_health_regen_cooldown = health_regen_delay
	_sanity_regen_cooldown = sanity_regen_delay

	# find HUD by group
	hud = get_tree().get_first_node_in_group("HUD") as CanvasLayer

	# update HUD if it supports these calls
	if hud != null:
		if hud.has_method("displayHealth"):
			hud.displayHealth(health, max_health)
		if hud.has_method("displaySanity"):
			hud.displaySanity(sanity, max_sanity)
	
func _process(_delta: float):
	displayProperties()
	
func _physics_process(delta: float) -> void:
	modifyPhysicsProperties() 
	_get_input()
	_handle_run_and_crouch()
	_handle_jump()
	_apply_movement(delta)
	gravityApply(delta)
	move_and_slide()
	_update_regen(delta)
	
func displayProperties():
	#display properties on the hud
	if hud != null:
		if hud.has_method("displayCurrentState"):
			hud.displayCurrentState(stateMachine.currStateName)
		if hud.has_method("displayCurrentDirection"):
			hud.displayCurrentDirection(moveDirection)
		if hud.has_method("displayDesiredMoveSpeed"):
			hud.displayDesiredMoveSpeed(desiredMoveSpeed)
		if hud.has_method("displayVelocity"):
			hud.displayVelocity(velocity.length())
		if hud.has_method("displayNbJumpsInAirAllowed"):
			hud.displayNbJumpsInAirAllowed(nbJumpsInAirAllowed)
		if hud.has_method("displaySanity"):
			hud.displaySanity(sanity, max_sanity)
		
func modifyPhysicsProperties():
	lastFramePosition = position
	lastFrameVelocity = velocity
	wasOnFloor = !is_on_floor()
	
func gravityApply(delta : float):
	if velocity.y >= 0.0:
		velocity.y += jumpGravity * delta
	elif velocity.y < 0.0:
		velocity.y += fallGravity * delta

func _get_input() -> void:
	inputDirection = Vector2(
		Input.get_action_strength(moveRightAction) - Input.get_action_strength(moveLeftAction),
		Input.get_action_strength(moveForwardAction) - Input.get_action_strength(moveBackwardAction)
	)

	if inputDirection.length() > 1.0:
		inputDirection = inputDirection.normalized()
	
	var forward: Vector3 = -camHolder.global_transform.basis.z
	var right: Vector3 = camHolder.global_transform.basis.x

	forward.y = 0.0
	right.y = 0.0
	forward = forward.normalized()
	right = right.normalized()

	moveDirection = (forward * inputDirection.y) + (right * inputDirection.x)

func _handle_run_and_crouch() -> void:
	if Input.is_action_pressed(crouchAction):
		moveSpeed = crouchSpeed
		moveAccel = crouchAccel
		moveDeccel = crouchDeccel
		walkOrRun = "CrouchState"
	elif Input.is_action_pressed(runAction) and inputDirection.y > 0.0:
		moveSpeed = runSpeed
		moveAccel = runAccel
		moveDeccel = runDeccel
		walkOrRun = "RunState"
	else:
		moveSpeed = walkSpeed
		moveAccel = walkAccel
		moveDeccel = walkDeccel
		walkOrRun = "WalkState"

func _handle_jump() -> void:
	if Input.is_action_just_pressed(jumpAction):
		if is_on_floor():
			velocity.y = jumpVelocity

func _apply_movement(delta: float) -> void:
	var target_velocity_xz: Vector3 = moveDirection * moveSpeed
	var current_velocity_xz: Vector3 = Vector3(velocity.x, 0.0, velocity.z)

	if moveDirection.length() > 0.0:
		current_velocity_xz = current_velocity_xz.lerp(target_velocity_xz, moveAccel * delta)
	else:
		current_velocity_xz = current_velocity_xz.lerp(Vector3.ZERO, moveDeccel * delta)

	velocity.x = current_velocity_xz.x
	velocity.z = current_velocity_xz.z
	
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("quit_game"):
		get_tree().quit()

	# TEMP sanity test: press ui_cancel to lose 5 sanity
	if event.is_action_pressed("ui_cancel"):
		lose_sanity(5)

# =========================
# HEALTH API
# =========================
func apply_damage(amount: int) -> void:
	if amount <= 0:
		return
	if health <= 0:
		return

	health = max(health - amount, 0)
	emit_signal("health_changed", health, max_health)

	# reset health regen timer
	_health_regen_cooldown = health_regen_delay

	if hud != null and hud.has_method("displayHealth"):
		hud.displayHealth(health, max_health)

	if health == 0:
		_die()


func heal(amount: int) -> void:
	if amount <= 0:
		return
	if health <= 0:
		return

	health = min(health + amount, max_health)
	emit_signal("health_changed", health, max_health)

	if hud != null and hud.has_method("displayHealth"):
		hud.displayHealth(health, max_health)

# =========================
# SANITY API
# =========================
func lose_sanity(amount: int) -> void:
	if amount <= 0:
		return
	if sanity <= 0:
		return

	sanity = max(sanity - amount, 0)
	emit_signal("sanity_changed", sanity, max_sanity)

	# reset sanity regen timer
	_sanity_regen_cooldown = sanity_regen_delay

	if hud != null and hud.has_method("displaySanity"):
		hud.displaySanity(sanity, max_sanity)

	if sanity == 0:
		print("All sanity lost!")


func restore_sanity(amount: int) -> void:
	if amount <= 0:
		return
	if sanity >= max_sanity:
		return

	sanity = min(sanity + amount, max_sanity)
	emit_signal("sanity_changed", sanity, max_sanity)

	if hud != null and hud.has_method("displaySanity"):
		hud.displaySanity(sanity, max_sanity)

# =========================
# REGEN TICK
# =========================
func _update_regen(delta: float) -> void:
	# HEALTH REGEN
	if health_regen_enabled and health > 0 and health < max_health:
		if _health_regen_cooldown > 0.0:
			_health_regen_cooldown = max(_health_regen_cooldown - delta, 0.0)
		else:
			heal(health_regen_amount)
			_health_regen_cooldown = health_regen_delay
	else:
		_health_regen_cooldown = health_regen_delay

	# SANITY REGEN
	if sanity_regen_enabled and sanity < max_sanity:
		if _sanity_regen_cooldown > 0.0:
			_sanity_regen_cooldown = max(_sanity_regen_cooldown - delta, 0.0)
		else:
			restore_sanity(sanity_regen_amount)
			_sanity_regen_cooldown = sanity_regen_delay
	else:
		_sanity_regen_cooldown = sanity_regen_delay


func _die() -> void:
	emit_signal("died")
	print("Player died")
	# later: trigger respawn / game over here
