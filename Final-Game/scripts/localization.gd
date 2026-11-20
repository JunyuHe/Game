extends Node
## Runtime localization service for the game.
## Source strings are English. Chinese and Spanish are provided as translations;
## every language keeps the same key set so switching never leaves a string untranslated.

signal language_changed(code: String)

const SETTINGS_PATH := "user://settings.cfg"

## Languages offered in the settings menu. Labels stay in English on purpose.
const SUPPORTED := [
	{"code": "en", "label": "English"},
	{"code": "es", "label": "Spanish"},
	{"code": "zh", "label": "Chinese"}
]

const STRINGS := {
	"en": {
		"app_title": "Final Project",
		"menu_start": "Start",
		"menu_settings": "Settings",
		"menu_quit": "Quit",
		"settings_title": "Settings",
		"settings_language": "Language",
		"settings_back": "Back",
		"hud_health": "Health: %d / %d",
		"hud_kills": "Kills: %d",
		"hud_level_exp": "Lv %d    %d / %d EXP",
		"hud_time": "Time: %02d:%02d",
		"hud_wave": "Wave: %d",
		"hud_gold": "Gold: %d",
		"weapon_pistol": "Pistol",
		"weapon_smg": "SMG",
		"weapon_shotgun": "Shotgun",
		"weapon_ak": "AK Rifle",
		"weapon_sniper": "Sniper",
		"weapon_rocket": "Rocket Launcher",
		"shop_title": "WEAPON SHOP",
		"shop_gold": "Gold: %d",
		"shop_weapons": "Weapons: %d / %d",
		"shop_item": "%s %s   DMG %d   %d G",
		"shop_sold_item": "%s %s   SOLD",
		"shop_hint": "B / Tab open · Esc close · R refresh · Click a weapon to sell",
		"shop_close": "Close",
		"shop_refresh": "Refresh  %d G",
		"shop_refresh_tip": "Reroll these four offers for gold — the price rises with each refresh.",
		"shop_tip_damage": "Damage: %d",
		"shop_tip_interval": "Attack interval: %.2fs",
		"shop_tip_dps": "DPS: %.1f",
		"shop_sell_confirm": "Sell %s %s\nfor %d G?",
		"shop_sell_do": "Sell",
		"shop_sell_cancel": "Cancel",
		"shop_sell_title": "Weapons %d / %d — click a weapon, then confirm the half-price sale",
		"shop_sell_item": "%s %s   +%d G",
		"shop_merge_toast": "Auto-merged: %s %s → %s",
		"shop_merge_hint": "Buying this merges it into %s",
		"stats_title": "Attributes",
		"stats_level": "Level: %d",
		"stats_exp": "EXP: %d / %d",
		"stats_hp": "HP: %d / %d",
		"stats_speed": "Speed: %d",
		"stats_interval": "Attack interval: %.2fs",
		"stats_damage": "Damage: %d",
		"stats_luck": "Luck: %d%%",
		"stats_lifesteal": "Lifesteal: %d%%",
		"stats_dodge": "Dodge: %d%%",
		"stat_luck": "Luck",
		"stat_lifesteal": "Lifesteal",
		"stat_dodge": "Dodge",
		"unit_luck": "%",
		"unit_lifesteal": "%",
		"unit_dodge": "%",
		"stats_kills": "Kills: %d",
		"game_over": "GAME OVER",
		"game_over_restart": "Restart",
		"game_over_retry": "Retry",
		"game_over_menu": "Main Menu",
		"upgrade_title": "LEVEL UP!",
		"upgrade_subtitle": "Choose one upgrade",
		"stat_hp": "Max Health",
		"stat_attack": "Attack",
		"stat_defense": "Defense",
		"unit_hp": "HP",
		"unit_attack": "ATK",
		"unit_defense": "DEF",
		"quality_base": "Base",
		"quality_common": "Common",
		"quality_fine": "Fine",
		"quality_epic": "Epic",
		"quality_mythic": "Mythic",
		"quality_legendary": "Legendary",
		"stats_defense": "Defense: %d",
		"pause_title": "PAUSED",
		"pause_resume": "Resume",
		"pause_settings": "Settings",
		"pause_quit": "Quit to Menu"
	},
	"es": {
		"app_title": "Final Project",
		"menu_start": "Jugar",
		"menu_settings": "Ajustes",
		"menu_quit": "Salir",
		"settings_title": "Ajustes",
		"settings_language": "Idioma",
		"settings_back": "Volver",
		"hud_health": "Salud: %d / %d",
		"hud_kills": "Bajas: %d",
		"hud_level_exp": "Nv %d    %d / %d EXP",
		"hud_time": "Tiempo: %02d:%02d",
		"hud_wave": "Oleada: %d",
		"hud_gold": "Oro: %d",
		"weapon_pistol": "Pistola",
		"weapon_smg": "Subfusil",
		"weapon_shotgun": "Escopeta",
		"weapon_ak": "Rifle AK",
		"weapon_sniper": "Francotirador",
		"weapon_rocket": "Lanzacohetes",
		"shop_title": "TIENDA DE ARMAS",
		"shop_gold": "Oro: %d",
		"shop_weapons": "Armas: %d / %d",
		"shop_item": "%s %s   DAN %d   %d O",
		"shop_sold_item": "%s %s   VENDIDO",
		"shop_hint": "B / Tab abrir · Esc cerrar · R renovar · Pulsa un arma para vender",
		"shop_close": "Cerrar",
		"shop_refresh": "Renovar  %d O",
		"shop_refresh_tip": "Vuelve a tirar las cuatro ofertas pagando oro — sube de precio en cada renovación.",
		"shop_tip_damage": "Daño: %d",
		"shop_tip_interval": "Intervalo de disparo: %.2fs",
		"shop_tip_dps": "DPS: %.1f",
		"shop_sell_confirm": "Vender %s %s\npor %d O?",
		"shop_sell_do": "Vender",
		"shop_sell_cancel": "Cancelar",
		"shop_sell_title": "Armas %d / %d — pulsa un arma y confirma la venta por la mitad",
		"shop_sell_item": "%s %s   +%d O",
		"shop_merge_toast": "Fusionado: %s %s → %s",
		"shop_merge_hint": "Al comprarlo se fusiona en %s",
		"stats_title": "Atributos",
		"stats_level": "Nivel: %d",
		"stats_exp": "EXP: %d / %d",
		"stats_hp": "Salud: %d / %d",
		"stats_speed": "Velocidad: %d",
		"stats_interval": "Intervalo de disparo: %.2f s",
		"stats_damage": "Dano: %d",
		"stats_luck": "Suerte: %d%%",
		"stats_lifesteal": "Robo de vida: %d%%",
		"stats_dodge": "Esquiva: %d%%",
		"stat_luck": "Suerte",
		"stat_lifesteal": "Robo de vida",
		"stat_dodge": "Esquiva",
		"unit_luck": "%",
		"unit_lifesteal": "%",
		"unit_dodge": "%",
		"stats_kills": "Bajas: %d",
		"game_over": "FIN DEL JUEGO",
		"game_over_restart": "Reiniciar",
		"game_over_retry": "Reintentar",
		"game_over_menu": "Menu principal",
		"upgrade_title": "SUBIDA DE NIVEL",
		"upgrade_subtitle": "Elige una mejora",
		"stat_hp": "Vida maxima",
		"stat_attack": "Ataque",
		"stat_defense": "Defensa",
		"unit_hp": "HP",
		"unit_attack": "ATQ",
		"unit_defense": "DEF",
		"quality_base": "Base",
		"quality_common": "Comun",
		"quality_fine": "Fino",
		"quality_epic": "Epico",
		"quality_mythic": "Mitico",
		"quality_legendary": "Legendario",
		"stats_defense": "Defensa: %d",
		"pause_title": "PAUSA",
		"pause_resume": "Continuar",
		"pause_settings": "Ajustes",
		"pause_quit": "Salir al menu"
	},
	"zh": {
		"app_title": "Final Project",
		"menu_start": "开始游戏",
		"menu_settings": "设置",
		"menu_quit": "退出",
		"settings_title": "设置",
		"settings_language": "语言",
		"settings_back": "返回",
		"hud_health": "生命：%d / %d",
		"hud_kills": "击杀：%d",
		"hud_level_exp": "等级 %d    %d / %d 经验",
		"hud_time": "时间：%02d:%02d",
		"hud_wave": "波数：%d",
		"hud_gold": "金币：%d",
		"weapon_pistol": "手枪",
		"weapon_smg": "冲锋枪",
		"weapon_shotgun": "霰弹枪",
		"weapon_ak": "AK 步枪",
		"weapon_sniper": "狙击枪",
		"weapon_rocket": "火箭发射器",
		"shop_title": "武器商店",
		"shop_gold": "金币：%d",
		"shop_weapons": "武器：%d / %d",
		"shop_item": "%s %s   伤害 %d   %d 金",
		"shop_sold_item": "%s %s   已售出",
		"shop_hint": "B / Tab 打开 · Esc 关闭 · R 刷新 · 点武器可卖出",
		"shop_close": "关闭",
		"shop_refresh": "刷新  %d 金",
		"shop_refresh_tip": "花金币重新随机这四件商品 —— 每刷新一次价格会上涨。",
		"shop_tip_damage": "伤害：%d",
		"shop_tip_interval": "攻击间隔：%.2f 秒",
		"shop_tip_dps": "每秒伤害：%.1f",
		"shop_sell_confirm": "卖出 %s %s\n回收 %d 金？",
		"shop_sell_do": "卖出",
		"shop_sell_cancel": "取消",
		"shop_sell_title": "武器 %d / %d —— 点武器后确认，半价卖出",
		"shop_sell_item": "%s %s   回收 +%d 金",
		"shop_merge_toast": "自动合成：%s %s → %s",
		"shop_merge_hint": "购买后会合成：%s",
		"stats_title": "属性",
		"stats_level": "等级：%d",
		"stats_exp": "经验：%d / %d",
		"stats_hp": "生命：%d / %d",
		"stats_speed": "移速：%d",
		"stats_interval": "攻击间隔：%.2f 秒",
		"stats_damage": "伤害：%d",
		"stats_luck": "幸运：%d%%",
		"stats_lifesteal": "吸血：%d%%",
		"stats_dodge": "闪避：%d%%",
		"stat_luck": "幸运",
		"stat_lifesteal": "吸血",
		"stat_dodge": "闪避",
		"unit_luck": "%",
		"unit_lifesteal": "%",
		"unit_dodge": "%",
		"stats_kills": "击杀：%d",
		"game_over": "游戏结束",
		"game_over_restart": "重新开始",
		"game_over_retry": "再来一次",
		"game_over_menu": "返回菜单",
		"upgrade_title": "升级！",
		"upgrade_subtitle": "选择一项强化",
		"stat_hp": "最大生命",
		"stat_attack": "攻击力",
		"stat_defense": "防御力",
		"unit_hp": "生命",
		"unit_attack": "攻击",
		"unit_defense": "防御",
		"quality_base": "原始",
		"quality_common": "普通",
		"quality_fine": "精致",
		"quality_epic": "史诗",
		"quality_mythic": "神话",
		"quality_legendary": "传说",
		"stats_defense": "防御：%d",
		"pause_title": "已暂停",
		"pause_resume": "继续游戏",
		"pause_settings": "设置",
		"pause_quit": "退出到主菜单"
	}
}

var language: String = "en"

func _ready() -> void:
	_load_preference()

## Languages available for the language picker, in display order.
func languages() -> Array:
	return SUPPORTED

## Translated string for a key, falling back to English and then to the key itself.
func t(key: String) -> String:
	var table: Dictionary = STRINGS.get(language, STRINGS["en"])
	if table.has(key):
		return table[key]
	return STRINGS["en"].get(key, key)

## Translated string with printf-style arguments.
func format_tr(key: String, args: Array) -> String:
	return t(key) % args

## Index of the current language inside SUPPORTED.
func current_index() -> int:
	for i in SUPPORTED.size():
		if SUPPORTED[i]["code"] == language:
			return i
	return 0

## Switch language, persist it and notify listeners.
func set_language(code: String) -> void:
	if not STRINGS.has(code) or code == language:
		return
	language = code
	_save_preference()
	language_changed.emit(code)

func _load_preference() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	var saved: String = config.get_value("general", "language", "en")
	if STRINGS.has(saved):
		language = saved

func _save_preference() -> void:
	var config := ConfigFile.new()
	config.set_value("general", "language", language)
	config.save(SETTINGS_PATH)
