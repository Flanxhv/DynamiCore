extends TextureButton

@export var texts: Array[String] = [
	"很久很久以前，有一顆紫色的半球...",
	"占位符2",
	"占位符3"
]

@onready var bubble: PanelContainer = $Bubble
@onready var label: Label = $Bubble/MarginContainer/Label

var is_bubble_open: bool = false

func _ready() -> void:
	# 確保初始狀態是隱藏且透明的
	bubble.hide()
	bubble.modulate.a = 0.0
	
	# 綁定立繪的點擊信號
	pressed.connect(_on_character_pressed)

func _on_character_pressed() -> void:
	if is_bubble_open:
		_hide_bubble()
	else:
		_show_bubble()

func _show_bubble() -> void:
	if is_bubble_open: return
	is_bubble_open = true
	
	# 隨機挑選一句話顯示 (如果你只想固定一句，可以把這行改掉)
	label.text = texts.pick_random()
	
	# 顯示節點，並加入淡入動畫
	bubble.show()
	var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(bubble, "modulate:a", 1.0, 0.2)

func _hide_bubble() -> void:
	if not is_bubble_open: return
	is_bubble_open = false
	
	# 淡出動畫，結束後隱藏節點
	var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(bubble, "modulate:a", 0.0, 0.15)
	tween.tween_callback(bubble.hide)
