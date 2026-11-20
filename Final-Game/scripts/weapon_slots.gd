extends Node2D
## Weapon slots: keeps up to six weapon nodes in a ring around the player,
## rebuilt whenever the inventory changes.

@export var weapon_scene: PackedScene

const MAX_WEAPONS := 6
const RADIUS := 42.0

@onready var inventory: Node = $"../WeaponInventory"
@onready var player: Node2D = get_parent()

func _ready() -> void:
	if inventory == null:
		push_error("WeaponSlots: WeaponInventory node is missing.")
		return
	inventory.inventory_changed.connect(refresh_weapons)
	refresh_weapons()

func refresh_weapons() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()

	if weapon_scene == null:
		push_error("WeaponSlots: set the Weapon Scene in the Inspector.")
		return

	var count := mini(inventory.weapons.size(), MAX_WEAPONS)
	for i in count:
		var item: Dictionary = inventory.weapons[i]
		var weapon: Node2D = weapon_scene.instantiate()
		add_child(weapon)
		weapon.setup_weapon(item["id"], item["quality"], inventory, player)

		var angle := -PI / 2.0 + TAU * float(i) / float(MAX_WEAPONS)
		weapon.position = Vector2(cos(angle), sin(angle)) * RADIUS
