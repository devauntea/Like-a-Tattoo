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
@export var hitGroundCooldown : float #amount of time the character keep his accumulated speed before losing it (while being on ground)
var hitGroundCooldownRef : float 
@export var bunnyHopDmsIncre : float #bunny hopping desired move speed incrementer
@export var autoBunnyHop : bool = false
var lastFramePosition : Vector3 
var lastFrameVelocity : Vector3
var wasOnFloor : bool
var walkOrRun : String = "WalkState" #keep in memory if play char was walking or running before being in the air
#for crouch visible changes
@export var baseHitboxHeight : float
@export var baseModelHeight : float
@export var heightChangeSpeed : float

@export_group("Crouch variables")
@export var crouchSpeed : float
@export var crouchAccel : float
@export var crouchDeccel : float
@export var continiousCrouch : bool = false #if true, doesn't need to keep crouch button on to crouch
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
@export var continiousRun : bool = false #if true, doesn't need to keep run button on to run

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

#references variables
@onready var camHolder : Node3D = $CameraHolder
@onready var model : MeshInstance3D = $Model
@onready var hitbox : CollisionShape3D = $Hitbox
@onready var stateMachine : Node = %StateMachine
@onready var hud : CanvasLayer = $HUD
@onready var ceilingCheck : RayCast3D = $Raycasts/CeilingCheck
@onready var floorCheck : RayCast3D = $Raycasts/FloorCheck

func _ready():
	#set move variables, and value references
	moveSpeed = walkSpeed
	moveAccel = walkAccel
	moveDeccel = walkDeccel
	
	hitGroundCooldownRef = hitGroundCooldown
	jumpCooldownRef = jumpCooldown
	nbJumpsInAirAllowedRef = nbJumpsInAirAllowed
	coyoteJumpCooldownRef = coyoteJumpCooldown
	
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
	
func displayProperties():
	#display properties on the hud
	if hud != null:
		hud.displayCurrentState(stateMachine.currStateName)
		hud.displayCurrentDirection(moveDirection)
		hud.displayDesiredMoveSpeed(desiredMoveSpeed)
		hud.displayVelocity(velocity.length())
		hud.displayNbJumpsInAirAllowed(nbJumpsInAirAllowed)
		
func modifyPhysicsProperties():
	lastFramePosition = position #get play char position every frame
	lastFrameVelocity = velocity #get play char velocity every frame
	wasOnFloor = !is_on_floor() #check if play char was on floor every frame
	
func gravityApply(delta : float):
	#if play char goes up, apply jump gravity
	#otherwise, apply fall gravity
	if velocity.y >= 0.0: velocity.y += jumpGravity * delta
	elif velocity.y < 0.0: velocity.y += fallGravity * delta

func _get_input() -> void:
	# Read WASD (or whatever you bound) into a 2D vector
	inputDirection = Vector2(
		Input.get_action_strength(moveRightAction) - Input.get_action_strength(moveLeftAction),
		Input.get_action_strength(moveForwardAction) - Input.get_action_strength(moveBackwardAction)
	)

	if inputDirection.length() > 1.0:
		inputDirection = inputDirection.normalized()
	
	# Convert that into a 3D world-space direction based on the camera
	var forward: Vector3 = -camHolder.global_transform.basis.z
	var right: Vector3 = camHolder.global_transform.basis.x

	# Stay on the XZ plane
	forward.y = 0.0
	right.y = 0.0
	forward = forward.normalized()
	right = right.normalized()

	moveDirection = (forward * inputDirection.y) + (right * inputDirection.x)

func _handle_run_and_crouch() -> void:
	# Decide which movement mode we're in and set speed/accel/deccel
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
	# Target horizontal velocity based on moveDirection and moveSpeed
	var target_velocity_xz: Vector3 = moveDirection * moveSpeed

	# Current horizontal velocity (ignore Y for accel/deccel)
	var current_velocity_xz: Vector3 = Vector3(velocity.x, 0.0, velocity.z)

	if moveDirection.length() > 0.0:
		# Accelerate towards target
		current_velocity_xz = current_velocity_xz.lerp(target_velocity_xz, moveAccel * delta)
	else:
		# No input: decelerate to stop
		current_velocity_xz = current_velocity_xz.lerp(Vector3.ZERO, moveDeccel * delta)

	velocity.x = current_velocity_xz.x
	velocity.z = current_velocity_xz.z
	
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("quit_game"):
		get_tree().quit()
