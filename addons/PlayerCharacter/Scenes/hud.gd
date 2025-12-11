extends CanvasLayer

@onready var health_label: Label = $HealthLabel
@onready var sanity_label: Label = $SanityLabel
@onready var darken_overlay: ColorRect = $DarkenOverlay


func displayHealth(current: int, max_health: int) -> void:
	health_label.text = "%d / %d" % [current, max_health]


func displaySanity(current: int, max_sanity: int) -> void:
	sanity_label.text = "%d / %d" % [current, max_sanity]

	# 0 sanity → fully dark (alpha 1)
	# 100 sanity → no darkening (alpha 0)
	var t := 1.0 - float(current) / float(max_sanity)

	var col := darken_overlay.modulate
	col.a = clamp(t, 0.0, 1.0)
	darken_overlay.modulate = col
