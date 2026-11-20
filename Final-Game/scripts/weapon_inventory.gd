extends Node
## Weapon inventory: gold, the six equipped slots and the weapon/quality tables.
## A slot entry is {"id": "ak", "quality": "epic"}.

signal inventory_changed
## Emitted each time two identical weapons auto-combine into the next quality tier.
signal weapon_merged(weapon_id: String, from_quality: String, to_quality: String)

const MAX_WEAPONS := 6
## Two identical weapons merge one tier up, but never past this quality.
const MERGE_MAX_QUALITY := "mythic"

var gold: int = 250
## Global fire-rate multiplier from level-ups, so rebuilding the weapon slots
## never resets the speed the player has already earned.
var fire_rate_mult: float = 1.0
## Starting loadout: one base-quality pistol.
var weapons: Array = [{"id": "pistol", "quality": "base"}]

## Base weapon table: damage, price, cooldown and projectile behaviour.
const WEAPON_DATA := {
	"pistol": {"name_key": "weapon_pistol", "damage": 5, "price": 40, "cooldown": 0.6, "speed": 420.0, "range": 480.0, "pellets": 1, "spread": 0.0},
	"smg": {"name_key": "weapon_smg", "damage": 3, "price": 80, "cooldown": 0.15, "speed": 400.0, "range": 420.0, "pellets": 1, "spread": 0.0},
	"shotgun": {"name_key": "weapon_shotgun", "damage": 4, "price": 150, "cooldown": 1.2, "speed": 360.0, "range": 360.0, "pellets": 3, "spread": 0.12},
	"ak": {"name_key": "weapon_ak", "damage": 9, "price": 220, "cooldown": 0.25, "speed": 460.0, "range": 520.0, "pellets": 1, "spread": 0.0},
	"sniper": {"name_key": "weapon_sniper", "damage": 45, "price": 350, "cooldown": 2.0, "speed": 900.0, "range": 900.0, "pellets": 1, "spread": 0.0},
	"rocket": {"name_key": "weapon_rocket", "damage": 60, "price": 500, "cooldown": 3.0, "speed": 300.0, "range": 700.0, "pellets": 1, "spread": 0.0}
}

## Quality tiers: damage multiplier, price multiplier, UI color. Keys match the upgrade cards.
const QUALITY_DATA := {
	"base": {"damage_mult": 1.0, "price_mult": 1.0, "color": "#BDBDBD"},
	"common": {"damage_mult": 1.2, "price_mult": 1.3, "color": "#36B76A"},
	"fine": {"damage_mult": 1.5, "price_mult": 1.8, "color": "#378DE8"},
	"epic": {"damage_mult": 2.0, "price_mult": 2.7, "color": "#A35ADC"},
	"mythic": {"damage_mult": 2.7, "price_mult": 4.0, "color": "#D5A000"},
	"legendary": {"damage_mult": 3.5, "price_mult": 6.0, "color": "#E0454B"}
}

const QUALITY_KEYS := ["base", "common", "fine", "epic", "mythic", "legendary"]

func get_weapon_price(id: String, quality: String) -> int:
	if not WEAPON_DATA.has(id) or not QUALITY_DATA.has(quality):
		return 0
	return ceili(float(WEAPON_DATA[id]["price"]) * float(QUALITY_DATA[quality]["price_mult"]))

func get_weapon_damage(id: String, quality: String) -> int:
	if not WEAPON_DATA.has(id) or not QUALITY_DATA.has(quality):
		return 0
	return ceili(float(WEAPON_DATA[id]["damage"]) * float(QUALITY_DATA[quality]["damage_mult"]))

## Final bullet damage: ceil(base * quality) + character attack.
func get_final_damage(id: String, quality: String, attack: int) -> int:
	return get_weapon_damage(id, quality) + attack

func get_weapon_name(id: String) -> String:
	if not WEAPON_DATA.has(id):
		return id
	return Loc.t(WEAPON_DATA[id]["name_key"])

func buy_weapon(id: String, quality: String) -> bool:
	if not WEAPON_DATA.has(id) or not QUALITY_DATA.has(quality):
		return false
	# A full loadout can still buy when the purchase merges into an existing weapon.
	if weapons.size() >= MAX_WEAPONS and not has_merge_partner(id, quality):
		return false

	var price := get_weapon_price(id, quality)
	if gold < price:
		return false

	gold -= price
	weapons.append({"id": id, "quality": quality})
	merge_duplicates()
	inventory_changed.emit()
	return true

## Quality gained by two copies of `quality`, or "" when the cap is already reached.
func next_quality(quality: String) -> String:
	var index := QUALITY_KEYS.find(quality)
	if index < 0 or index >= QUALITY_KEYS.size() - 1:
		return ""
	return String(QUALITY_KEYS[index + 1])

## True while this quality is allowed to be consumed by a merge.
func can_merge(quality: String) -> bool:
	var index := QUALITY_KEYS.find(quality)
	var cap := QUALITY_KEYS.find(MERGE_MAX_QUALITY)
	return index >= 0 and cap >= 0 and index < cap

## True when an identical weapon of the same quality is already equipped.
func has_merge_partner(id: String, quality: String) -> bool:
	if not can_merge(quality):
		return false
	for item in weapons:
		if item["id"] == id and item["quality"] == quality:
			return true
	return false

## Auto-combine: two identical weapons of the same quality become one of the next tier.
func merge_duplicates() -> int:
	var merged := 0
	while true:
		var pair: Array = _find_merge_pair()
		if pair.is_empty():
			break
		var keep: int = int(pair[0])
		var drop: int = int(pair[1])
		var item: Dictionary = weapons[keep]
		var target := next_quality(item["quality"])
		weapons.remove_at(drop)
		weapons[keep] = {"id": item["id"], "quality": target}
		merged += 1
		weapon_merged.emit(item["id"], String(item["quality"]), target)
	if merged > 0:
		inventory_changed.emit()
	return merged

## Index pair [a, b] of the first two mergeable duplicates, or [] when none exist.
func _find_merge_pair() -> Array:
	var seen := {}
	for i in weapons.size():
		var item: Dictionary = weapons[i]
		if not can_merge(String(item["quality"])):
			continue
		var key := "%s|%s" % [item["id"], item["quality"]]
		if seen.has(key):
			return [int(seen[key]), i]
		seen[key] = i
	return []

func sell_weapon(index: int) -> bool:
	if index < 0 or index >= weapons.size():
		return false
	# Keep at least one weapon so the player is never unarmed.
	if weapons.size() <= 1:
		return false

	var item: Dictionary = weapons[index]
	gold += floori(float(get_weapon_price(item["id"], item["quality"])) * 0.5)
	weapons.remove_at(index)
	inventory_changed.emit()
	return true

func add_gold(amount: int) -> void:
	gold += amount
	inventory_changed.emit()
