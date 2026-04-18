extends Area3D

const PLAYER_GROUP := "player"
const MAILBOX_ZONE_GROUP := "mailbox_delivery_zone"
const MAILBOX_FOCUS_TARGET_GROUP := "mailbox_focus_target"
const HIGHLIGHT_EMISSION := Color(1.0, 0.92, 0.45)
const HIGHLIGHT_ENERGY := 0.7

@export var score_value := 150
@export var required_hold_time := 2.0
var has_been_delivered := false
var highlight_meshes: Array[MeshInstance3D] = []

@onready var mailbox_visual: Node3D = $MailboxVisual
@onready var mailbox_focus_target: StaticBody3D = $MailboxVisual/MailboxFocusTarget


func _ready():
	add_to_group(MAILBOX_ZONE_GROUP)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	setup_focus_target()
	setup_highlight_materials()
	set_highlighted(false)


func setup_focus_target():
	if mailbox_focus_target == null:
		return

	mailbox_focus_target.add_to_group(MAILBOX_FOCUS_TARGET_GROUP)
	mailbox_focus_target.set_meta("mailbox_zone", self)


func setup_highlight_materials():
	highlight_meshes.clear()
	if mailbox_visual == null:
		return

	for child in mailbox_visual.get_children():
		if not child is MeshInstance3D:
			continue

		var mesh_instance = child as MeshInstance3D
		if mesh_instance.material_override == null:
			continue

		mesh_instance.material_override = mesh_instance.material_override.duplicate()
		highlight_meshes.append(mesh_instance)


func _on_body_entered(body):
	if has_been_delivered:
		return

	if body != null and body.is_in_group(PLAYER_GROUP) and body.has_method("enter_mailbox_zone"):
		body.enter_mailbox_zone(self)


func _on_body_exited(body):
	if body != null and body.is_in_group(PLAYER_GROUP) and body.has_method("exit_mailbox_zone"):
		body.exit_mailbox_zone(self)


func get_delivery_score():
	return score_value


func get_required_hold_time():
	return required_hold_time


func mark_delivered():
	if has_been_delivered:
		return false

	has_been_delivered = true
	set_deferred("monitoring", false)
	set_highlighted(false)
	return true


func can_accept_delivery():
	return not has_been_delivered


func is_focus_target(collider):
	if collider == null:
		return false

	if not collider is Node:
		return false

	var node = collider as Node
	if not node.is_in_group(MAILBOX_FOCUS_TARGET_GROUP):
		return false

	return node.get_meta("mailbox_zone", null) == self


func set_highlighted(is_highlighted):
	var should_highlight = is_highlighted and can_accept_delivery()

	for mesh_instance in highlight_meshes:
		if not is_instance_valid(mesh_instance):
			continue

		var material = mesh_instance.material_override
		if material == null or not material is StandardMaterial3D:
			continue

		var standard_material = material as StandardMaterial3D
		standard_material.emission_enabled = should_highlight
		standard_material.emission = HIGHLIGHT_EMISSION
		standard_material.emission_energy_multiplier = HIGHLIGHT_ENERGY if should_highlight else 0.0
