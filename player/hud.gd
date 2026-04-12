extends CanvasLayer

@onready var stamina_bar: ProgressBar = $MarginContainer/VBoxContainer/StaminaBar
@onready var health_bar: ProgressBar = $MarginContainer/VBoxContainer/HealthBar
@onready var throw_bar: ProgressBar = $MarginContainer/VBoxContainer/ThrowBar
@onready var newspaper_label: Label = $MarginContainer/VBoxContainer/newspaper
@onready var score_label: Label = $MarginContainer/VBoxContainer/ScoreLabel
@onready var pickup_prompt: Label = $PickupPrompt

func _ready():
	print("HealthBar:", $MarginContainer/VBoxContainer/HealthBar)
	print("StaminaBar:", $MarginContainer/VBoxContainer/StaminaBar)
	throw_bar.visible = false
	pickup_prompt.visible = false

func set_health(value):
	health_bar.value = value

func set_stamina(value):
	stamina_bar.value = value

func set_throw_charge(visible_state, value, max_value):
	throw_bar.visible = visible_state
	throw_bar.max_value = max_value
	throw_bar.value = value

func set_newspaper_count(current_value, max_value):
	newspaper_label.text = "Newspapers %d / %d" % [current_value, max_value]

func set_score(value):
	score_label.text = "Score: %d" % value

func set_pickup_prompt(visible_state):
	pickup_prompt.visible = visible_state
