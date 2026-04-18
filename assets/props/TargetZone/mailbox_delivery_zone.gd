extends Area3D

const PLAYER_GROUP := "player"
const MAILBOX_ZONE_GROUP := "mailbox_delivery_zone"

@export var score_value := 150
@export var required_hold_time := 2.0
var has_been_delivered := false


func _ready():
	add_to_group(MAILBOX_ZONE_GROUP)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


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
	return true


func can_accept_delivery():
	return not has_been_delivered
