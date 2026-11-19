extends Area2D
## EXP orb: gets pulled toward the player when close, then adds EXP on pickup.

@export var exp_value: int = 1
@export var magnet_radius: float = 120.0
@export var pickup_radius: float = 22.0
@export var move_speed: float = 260.0
@export var lifetime: float = 12.0

var _player: Node2D
var _life: float

func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")
	_life = lifetime

func _physics_process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")
		return

	var distance := global_position.distance_to(_player.global_position)
	if distance < magnet_radius:
		global_position = global_position.move_toward(
			_player.global_position, move_speed * delta)

	if distance < pickup_radius:
		if _player.has_method("gain_exp"):
			_player.gain_exp(exp_value)
		queue_free()
