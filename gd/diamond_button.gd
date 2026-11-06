extends Button

@onready var label = $Label

# 使用 @export 讓你可以直接在 Godot 編輯器裡設定每顆按鈕的字和顏色！
@export var btn_text: String = "BTN"
@export var active_color: Color = Color.WHITE

func _ready():
	label.text = btn_text
	update_visual(false) # 預設為未啟用狀態的半透明色

# 讓主腳本呼叫，用來切換按鈕的發光/暗淡狀態
func update_visual(is_active: bool):
	var style = StyleBoxFlat.new()
	
	if is_active:
		var active = active_color
		active.a = 0.85  # 啟用時降低一點透明度，例如 70%
		style.bg_color = active
		style.border_color = Color.WHITE
	else:
		var inactive = active_color
		inactive.a = 0.25 # 未啟用時，透明度降為 25%
		style.bg_color = inactive
		style.border_color = Color(0.6, 0.6, 0.6, 0.8)
		
	style.set_border_width_all(3)
	
	add_theme_stylebox_override("normal", style)
	add_theme_stylebox_override("hover", style)
	add_theme_stylebox_override("pressed", style)
	add_theme_stylebox_override("focus", style)
