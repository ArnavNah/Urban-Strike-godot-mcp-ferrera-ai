@tool
class_name MenuBrackets
extends Control

## Subtle tactical corner brackets underneath the menu buttons.

const COLOR_BRACKET := Color(1.0, 0.76, 0.16, 0.60) # Amber

func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	var arm: float = 12.0

	# Left bottom bracket: └
	draw_line(Vector2(0.0, h - arm), Vector2(0.0, h), COLOR_BRACKET, 1.5, true)
	draw_line(Vector2(0.0, h), Vector2(arm, h), COLOR_BRACKET, 1.5, true)

	# Right bottom bracket: ┘
	draw_line(Vector2(w, h - arm), Vector2(w, h), COLOR_BRACKET, 1.5, true)
	draw_line(Vector2(w - arm, h), Vector2(w, h), COLOR_BRACKET, 1.5, true)
