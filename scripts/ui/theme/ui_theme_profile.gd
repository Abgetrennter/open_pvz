class_name UIThemeProfile
extends Resource

@export var theme_id: StringName = &"default"

@export_group("SunCounter")
@export var sun_icon_color: Color = Color("f2d25c")
@export var sun_counter_text_color: Color = Color("ffffff")
@export var sun_counter_font_size: int = 24

@export_group("CardBar")
@export var card_cooldown_overlay_color: Color = Color(0.0, 0.0, 0.0, 0.5)
@export var card_unselected_modulate: Color = Color(0.8, 0.8, 0.8, 1.0)
@export var card_affordable_text_color: Color = Color("ffffff")
@export var card_unaffordable_text_color: Color = Color("e06060")
@export var card_font_size: int = 16
@export var card_type_colors: Dictionary = {
	&"sunflower": Color("ffd700"),
	&"shooter": Color("4caf50"),
	&"wall": Color("8d6e63"),
	&"repeater": Color("2e7d32"),
	&"lobber": Color("66bb6a"),
	&"default": Color("78909c"),
}

@export_group("BoardOverlay")
@export var cell_normal_color: Color = Color(0.3, 0.5, 0.2, 0.3)
@export var cell_hover_color: Color = Color(0.4, 0.7, 0.3, 0.5)
@export var cell_occupied_color: Color = Color(0.5, 0.3, 0.2, 0.3)
@export var cell_invalid_color: Color = Color(0.7, 0.2, 0.2, 0.3)

@export_group("PhaseScreen")
@export var phase_overlay_initial_color: Color = Color(0.0, 0.0, 0.0, 0.0)
@export var victory_text_color: Color = Color("4caf50")
@export var defeat_text_color: Color = Color("e06060")

@export_group("WaveProgress")
@export var wave_normal_color: Color = Color("ffffff")
@export var wave_final_color: Color = Color("e06060")
@export var wave_font_size: int = 18


static func default() -> UIThemeProfile:
	var loaded: UIThemeProfile = load("res://scripts/ui/theme/default_theme.tres") as UIThemeProfile
	if loaded != null:
		return loaded
	# Fallback: create a minimal profile with script defaults
	return UIThemeProfile.new()
