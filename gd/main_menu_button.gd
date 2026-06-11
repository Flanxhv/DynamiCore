extends Button

@export var base_style: StyleBoxFlat 
@export var glow_color: Color = Color("4de6ff9d") 
@export var glow_size: int = 24 # 建議把點擊時的光暈調大一點，比如 24，才能跟待機的 12px 產生對比

var style_box: StyleBoxFlat
var original_shadow_color: Color
var original_offset: Vector2
var original_shadow_size: int # 新增：用來記錄你設定的 12px

func _ready() -> void:
	if base_style == null:
		if has_theme_stylebox_override("normal"):
			var override_style = get_theme_stylebox("normal")
			if override_style is StyleBoxFlat:
				base_style = override_style as StyleBoxFlat
				
	if base_style == null:
		push_error("【錯誤】找不到 StyleBoxFlat！請將材質拖入右側腳本屬性的 Base Style 中。")
		return

	style_box = base_style.duplicate() as StyleBoxFlat
	
	# 完整讀取你在編輯器裡設定的所有參數
	original_shadow_color = style_box.shadow_color
	original_offset = style_box.shadow_offset
	original_shadow_size = style_box.shadow_size # 成功抓到你的 12px
	
	add_theme_stylebox_override("normal", style_box)
	add_theme_stylebox_override("hover", style_box)
	add_theme_stylebox_override("pressed", style_box)
	add_theme_stylebox_override("focus", style_box)
	
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)


func _on_button_down() -> void:
	if style_box == null: return
	var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.set_parallel(true)
	# 按下：陰影回到正中央 (0,0)，尺寸放大變成光暈，顏色變亮
	tween.tween_property(style_box, "shadow_offset", Vector2.ZERO, 0.1)
	tween.tween_property(style_box, "shadow_size", glow_size, 0.1)
	tween.tween_property(style_box, "shadow_color", glow_color, 0.1)


func _on_button_up() -> void:
	if style_box == null: return
	var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.set_parallel(true)
	# 放開：恢復成你在編輯器設定的位移 (12,10) 和尺寸 (12)
	tween.tween_property(style_box, "shadow_offset", original_offset, 0.3)
	tween.tween_property(style_box, "shadow_size", original_shadow_size, 0.3) 
	tween.tween_property(style_box, "shadow_color", original_shadow_color, 0.3)
