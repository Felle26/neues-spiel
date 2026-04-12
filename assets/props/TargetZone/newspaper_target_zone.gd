extends Area3D

@export var score_value := 100


func _ready():
	body_entered.connect(_on_body_entered)


func _on_body_entered(body):
	if not is_valid_newspaper(body):
		return

	body.set_meta("is_scored_newspaper", true)
	body.remove_from_group("newspaper_pickups")

	var player = get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("add_score"):
		player.add_score(score_value)


func is_valid_newspaper(body):
	if not body is RigidBody3D:
		return false

	if body.name != "NewsPaper":
		return false

	if body.get_meta("is_scored_newspaper", false):
		return false

	return true