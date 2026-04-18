extends Area3D

@export var score_value := 100
const NEWSPAPER_GROUP := "newspaper"
var has_triggered := false


func _ready():
	body_entered.connect(_on_body_entered)


func _on_body_entered(body):
	if has_triggered:
		return

	if not is_valid_newspaper(body):
		return

	has_triggered = true
	set_deferred("monitoring", false)

	body.set_meta("is_scored_newspaper", true)
	body.remove_from_group("newspaper_pickups")

	var player = get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("add_score"):
		player.add_score(score_value)


func is_valid_newspaper(body):
	if not body is RigidBody3D:
		return false

	if not body.is_in_group(NEWSPAPER_GROUP):
		return false

	if body.get_meta("is_scored_newspaper", false):
		return false

	return true
