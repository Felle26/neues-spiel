extends CharacterBody3D
@onready var hud: CanvasLayer = $"../Hud"
@onready var camera: Camera3D = $Head/Camera3D
@onready var hand: Marker3D = $Head/Camera3D/Hand

const NEWSPAPER_SCENE := preload("res://assets/props/newspaper/newsPaper.tscn")
const NEWSPAPER_GROUP := "newspaper"
const DEFAULT_MAILBOX_HOLD_TIME := 2.0

#walking system
var max_speed := 5.0
@export var walk_speed:= 5.0
@export var run_speed := 8.0
@export var acceleration := 12.0
@export var deceleration := 10.0

#jumping
@export var jump_force := 4.5

#mousesens
@export var mouse_sensitivity := 0.15

#stamina System
@export var max_stamina := 100.0
var stamina := max_stamina
var is_running := false
@export var stamina_drain := 15.0   # pro Sekunde
@export var stamina_regen := 10.0    # pro Sekunde
var current_speed := walk_speed

#health System
@export var max_health := 100.0
var health := max_health

#score system
var score := 0

#throwing system
@export var max_newspapers := 10
@export var min_throw_force := 3.0
@export var max_throw_force := 15.0
@export var throw_charge_speed := 9.0
@export var pickup_distance := 3.0
@export var mailbox_focus_distance := 6.0
var newspaper_count := max_newspapers
var is_aiming := false
var is_charging_throw := false
var throw_force := 0.0
var pending_pickup_request := false
var current_pickup_target: Node3D
var current_mailbox_zone: Area3D
var active_mailbox_zones: Array[Area3D] = []
var mailbox_hold_progress := 0.0

#hard coded gravity
var gravity := 9.8
var gravity_loaded := false
var head




func _ready():
	print("HUD:", hud)
	head = $Head
	newspaper_count = max_newspapers
	add_to_group("player")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	
func _physics_process(delta):
	# --- Gravity laden (Jolt-kompatibel) ---
	if not gravity_loaded:
		var world := get_world_3d()
		if world:
			gravity = PhysicsServer3D.area_get_param(
				world.space,
				PhysicsServer3D.AREA_PARAM_GRAVITY
			)
			gravity_loaded = true

	# --- Input Richtung ---
	var input_dir = Vector3.ZERO

	if Input.is_action_pressed("move_forward"):
		input_dir -= transform.basis.z
	if Input.is_action_pressed("move_backward"):
		input_dir += transform.basis.z
	if Input.is_action_pressed("move_left"):
		input_dir -= transform.basis.x
	if Input.is_action_pressed("move_right"):
		input_dir += transform.basis.x

	input_dir = input_dir.normalized()
	current_pickup_target = get_target_newspaper()
	update_mailbox_focus()

	update_run_state(input_dir)
	update_stamina(delta)
	update_Hud()
	update_throw_charge(delta)
	process_pickup_request()
	process_mailbox_delivery(delta)

	# --- Smooth Movement ---
	var target_velocity = input_dir * current_speed

	var horizontal_velocity = velocity
	horizontal_velocity.y = 0

	if input_dir != Vector3.ZERO:
		# Beschleunigen
		horizontal_velocity = horizontal_velocity.lerp(target_velocity, acceleration * delta)
	else:
		# Abbremsen
		horizontal_velocity = horizontal_velocity.lerp(Vector3.ZERO, deceleration * delta)

	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z

	# --- Gravity & Jump ---
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		if Input.is_action_just_pressed("jump"):
			velocity.y = jump_force

	move_and_slide()

func _unhandled_input(event):
	if event is InputEventMouseMotion:
		rotate_y(deg_to_rad(-event.relative.x * mouse_sensitivity))
		head.rotate_x(deg_to_rad(-event.relative.y * mouse_sensitivity))
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-89), deg_to_rad(89))
	if event.is_action_pressed("aim"):
		is_aiming = true
	if event.is_action_released("aim"):
		is_aiming = false
		is_charging_throw = false
		throw_force = 0.0
	if event.is_action_pressed("fire"):
		if is_aiming and newspaper_count > 0:
			is_charging_throw = true
			throw_force = min_throw_force
	if event.is_action_pressed("interact"):
		if current_mailbox_zone == null:
			pending_pickup_request = true
	if event.is_action_released("fire"):
		if is_aiming and is_charging_throw:
			throw_newspaper()
		is_charging_throw = false
		throw_force = 0.0

func update_run_state(input_dir):
	is_running = Input.is_action_pressed("run") and input_dir != Vector3.ZERO and stamina > 0.0
	current_speed = run_speed if is_running else walk_speed

func update_stamina(delta):
	if is_running:
		stamina -= stamina_drain * delta
		if stamina <= 0.0:
			stamina = 0.0
			is_running = false
			current_speed = walk_speed
	else:
		stamina += stamina_regen * delta

	stamina = clamp(stamina, 0.0, max_stamina)

func update_Hud():
	hud.set_health(health)
	hud.set_stamina(stamina)
	hud.set_throw_charge(is_aiming, throw_force, max_throw_force)
	hud.set_newspaper_count(newspaper_count, max_newspapers)
	hud.set_score(score)

	var pickup_prompt_visible = current_pickup_target != null and newspaper_count < max_newspapers
	if current_mailbox_zone != null:
		if newspaper_count <= 0:
			hud.set_interact_prompt("Keine Zeitung zum Zustellen", true)
		else:
			var required_hold_time = get_mailbox_hold_time()
			var hold_percentage = 0.0
			if required_hold_time > 0.0:
				hold_percentage = clamp((mailbox_hold_progress / required_hold_time) * 100.0, 0.0, 100.0)
			hud.set_interact_prompt("Halte F zum Zustellen (%.0f%%)" % hold_percentage, true)
	elif not active_mailbox_zones.is_empty():
		hud.set_interact_prompt("Schaue einen Briefkasten an", true)
	else:
		hud.set_interact_prompt("Druecke F zum Aufsammeln", pickup_prompt_visible)


func update_mailbox_focus():
	var focused_mailbox = get_focused_mailbox_zone()
	update_mailbox_highlights(focused_mailbox)
	if focused_mailbox != current_mailbox_zone:
		mailbox_hold_progress = 0.0
	current_mailbox_zone = focused_mailbox


func update_mailbox_highlights(focused_mailbox):
	for zone in active_mailbox_zones:
		if not is_instance_valid(zone):
			continue

		if zone.has_method("set_highlighted"):
			zone.set_highlighted(zone == focused_mailbox)


func get_focused_mailbox_zone():
	if active_mailbox_zones.is_empty():
		return null

	var ray_origin = camera.global_position
	var ray_end = ray_origin + -camera.global_transform.basis.z * mailbox_focus_distance
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.exclude = [self]
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var space_state = get_world_3d().direct_space_state
	if space_state == null:
		return null

	var result = space_state.intersect_ray(query)
	if result.is_empty():
		return null

	var collider = result.get("collider")
	if not collider is Node:
		return null

	for zone in active_mailbox_zones:
		if not is_instance_valid(zone):
			continue

		if zone.has_method("is_focus_target") and zone.is_focus_target(collider):
			if zone.has_method("can_accept_delivery") and not zone.can_accept_delivery():
				active_mailbox_zones.erase(zone)
				return null
			return zone

	return null

func update_throw_charge(delta):
	if is_aiming and is_charging_throw:
		throw_force = min(throw_force + throw_charge_speed * delta, max_throw_force)

func throw_newspaper():
	if newspaper_count <= 0:
		return

	var newspaper = NEWSPAPER_SCENE.instantiate()
	var spawn_parent = get_tree().current_scene if get_tree().current_scene != null else get_parent()
	var throw_direction = (-camera.global_transform.basis.z + camera.global_transform.basis.y * 0.08).normalized()
	var spawn_position = hand.global_position + throw_direction * 0.75

	spawn_parent.add_child(newspaper)
	newspaper.global_transform = Transform3D(Basis.looking_at(throw_direction, Vector3.UP), spawn_position)
	if not newspaper.is_in_group(NEWSPAPER_GROUP):
		newspaper.add_to_group(NEWSPAPER_GROUP)
	newspaper.add_to_group("newspaper_pickups")
	newspaper_count -= 1

	if newspaper is RigidBody3D:
		newspaper.linear_velocity = velocity + throw_direction * throw_force

func try_pickup_newspaper():
	if newspaper_count >= max_newspapers:
		return

	var collider = current_pickup_target
	if collider is Node3D and is_newspaper_pickup(collider):
		newspaper_count += 1
		current_pickup_target = null
		collider.queue_free()

func is_newspaper_pickup(collider):
	return (collider.is_in_group("newspaper_pickups") or collider.is_in_group(NEWSPAPER_GROUP)) and not collider.get_meta("is_scored_newspaper", false)

func process_pickup_request():
	if not pending_pickup_request:
		return

	pending_pickup_request = false
	try_pickup_newspaper()

func process_mailbox_delivery(delta):
	if current_mailbox_zone == null:
		mailbox_hold_progress = 0.0
		return

	if newspaper_count <= 0:
		mailbox_hold_progress = 0.0
		return

	if Input.is_action_pressed("interact"):
		mailbox_hold_progress += delta
		if mailbox_hold_progress >= get_mailbox_hold_time():
			complete_mailbox_delivery()
			mailbox_hold_progress = 0.0
	else:
		mailbox_hold_progress = 0.0

func get_mailbox_hold_time():
	if current_mailbox_zone != null and current_mailbox_zone.has_method("get_required_hold_time"):
		return max(current_mailbox_zone.get_required_hold_time(), 0.01)

	return DEFAULT_MAILBOX_HOLD_TIME

func complete_mailbox_delivery():
	if current_mailbox_zone == null:
		return

	if newspaper_count <= 0:
		return

	if current_mailbox_zone.has_method("can_accept_delivery") and not current_mailbox_zone.can_accept_delivery():
		active_mailbox_zones.erase(current_mailbox_zone)
		current_mailbox_zone = null
		mailbox_hold_progress = 0.0
		return

	if current_mailbox_zone.has_method("mark_delivered") and not current_mailbox_zone.mark_delivered():
		active_mailbox_zones.erase(current_mailbox_zone)
		current_mailbox_zone = null
		mailbox_hold_progress = 0.0
		return

	newspaper_count -= 1
	var delivery_points = 0
	if current_mailbox_zone.has_method("get_delivery_score"):
		delivery_points = current_mailbox_zone.get_delivery_score()
	add_score(delivery_points)
	active_mailbox_zones.erase(current_mailbox_zone)
	if current_mailbox_zone.has_method("set_highlighted"):
		current_mailbox_zone.set_highlighted(false)

	current_mailbox_zone = null
	mailbox_hold_progress = 0.0

func enter_mailbox_zone(zone):
	if zone == null:
		return

	if not zone is Area3D:
		return

	if not active_mailbox_zones.has(zone):
		active_mailbox_zones.append(zone)

func exit_mailbox_zone(zone):
	active_mailbox_zones.erase(zone)
	if zone != null and zone.has_method("set_highlighted"):
		zone.set_highlighted(false)

	if zone == current_mailbox_zone:
		current_mailbox_zone = null
		mailbox_hold_progress = 0.0

func get_target_newspaper():
	var ray_origin = camera.global_position
	var ray_end = ray_origin + -camera.global_transform.basis.z * pickup_distance
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.exclude = [self]
	var space_state = get_world_3d().direct_space_state
	if space_state == null:
		return null
	var result = space_state.intersect_ray(query)

	if result.is_empty():
		return null

	var collider = result.get("collider")
	if collider is Node3D and is_newspaper_pickup(collider):
		return collider

	return null

func add_score(points):
	score += points
