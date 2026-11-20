extends Control
## Boss health bar at the top of the screen: shows up while a boss is alive.

const BAR_WIDTH := 470.0

@onready var hp_label: Label = $HpLabel
@onready var fill: ColorRect = $BarFill

var _boss: Node = null

func _ready() -> void:
	hide()

func _process(_delta: float) -> void:
	if _boss == null or not is_instance_valid(_boss):
		_boss = _find_boss()
		if _boss == null:
			if visible:
				hide()
			return
		show()

	_update_bar()

func _find_boss() -> Node:
	var bosses := get_tree().get_nodes_in_group("boss")
	if bosses.is_empty():
		return null
	return bosses[0]

func _update_bar() -> void:
	var current: int = int(_boss.get("hp"))
	var maximum: int = int(_boss.get("max_hp"))
	var ratio: float = 1.0
	if maximum > 0:
		ratio = clampf(float(current) / float(maximum), 0.0, 1.0)

	fill.size = Vector2(BAR_WIDTH * ratio, fill.size.y)
	hp_label.text = "%d / %d HP" % [current, maximum]
	# Enrage phase (below 40%) turns the bar orange.
	var phase: int = int(_boss.get("phase"))
	fill.color = Color(1.0, 0.45, 0.1) if phase >= 3 else Color(0.9, 0.2, 0.25)
