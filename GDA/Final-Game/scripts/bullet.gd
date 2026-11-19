extends Area2D
## Bullet: flies along its direction, damages enemies on hit, and destroys itself on timeout.

@export var speed: float = 420.0
@export var damage: int = 1

var direction: Vector2 = Vector2.RIGHT
var life: float = 2.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	life -= delta
	if life <= 0.0:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("mobs") and body.has_method("take_damage"):
		body.take_damage(damage)
		queue_free()
