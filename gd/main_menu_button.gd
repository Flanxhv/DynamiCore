extends Button

@export_group("Touch Feedback")
@export var pressed_offset_y: float = 4.0      # 按下時下沉距離
@export var pressed_scale: Vector2 = Vector2(0.98, 0.98) # 輕微等比壓低
@export var pressed_bg_color: Color = Color(0.08, 0.09, 0.11, 0.9) # 按下變深

var style_box: StyleBoxFlat
var _original_bg_color: Color
var _original_shadow_offset: Vector2
var _original_shadow_size: int
var _tween: Tween

func _ready() -> void:
	# 抓取 Inspector 裡設定好的 StyleBox 並獨立化 (避免共用污染)
	var current_style = get_theme_stylebox("normal")
	if current_style is StyleBoxFlat:
		style_box = current_style.duplicate() as StyleBoxFlat
		add_theme_stylebox_override("normal", style_box)
		add_theme_stylebox_override("pressed", style_box)
		add_theme_stylebox_override("hover", style_box)
		add_theme_stylebox_override("focus", style_box)
		
		# 自動讀取 Inspector 調好的參數做為待機還原值
		_original_bg_color = style_box.bg_color
		_original_shadow_offset = style_box.shadow_offset
		_original_shadow_size = style_box.shadow_size

	# 設定縮放中心
	pivot_offset = size / 2.0
	resized.connect(func(): pivot_offset = size / 2.0)
	
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)


func _on_button_down() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
		
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# 漂浮減弱：陰影收小、貼緊、顏色加深
	if style_box:
		_tween.tween_property(style_box, "shadow_offset", Vector2(2, 2), 0.08)
		_tween.tween_property(style_box, "shadow_size", 2, 0.08)
		_tween.tween_property(style_box, "bg_color", pressed_bg_color, 0.08)
	
	# 下沉與微縮
	_tween.tween_property(self, "position:y", position.y + pressed_offset_y, 0.08)
	_tween.tween_property(self, "scale", pressed_scale, 0.08)


func _on_button_up() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
		
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# 恢復 Inspector 原本設定的漂浮狀態
	if style_box:
		_tween.tween_property(style_box, "shadow_offset", _original_shadow_offset, 0.15)
		_tween.tween_property(style_box, "shadow_size", _original_shadow_size, 0.15)
		_tween.tween_property(style_box, "bg_color", _original_bg_color, 0.15)
	
	# 回彈
	_tween.tween_property(self, "position:y", position.y - pressed_offset_y, 0.15)
	_tween.tween_property(self, "scale", Vector2.ONE, 0.15)
