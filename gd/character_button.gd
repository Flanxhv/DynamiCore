extends TextureButton


# 定義單個對話群組的資料結構
# Resource 允許直接在 Inspector 中儲存與編輯
@export var dialogue_groups: Array[DialogueGroup] = []

@onready var bubble: PanelContainer = $Bubble
@onready var label: Label = $Bubble/MarginContainer/Label

var is_bubble_open: bool = false
var active_tween: Tween

# 播放狀態追蹤
var current_group: DialogueGroup = null
var current_line_index: int = 0

func _ready() -> void:
	bubble.hide()
	bubble.modulate.a = 0.0
	pressed.connect(_on_character_pressed)

func _on_character_pressed() -> void:
	if not is_bubble_open:
		_start_next_dialogue_group()
	else:
		_advance_or_close()

func _start_next_dialogue_group() -> void:
	if dialogue_groups.is_empty():
		return

	# 挑選一組對話（這裡示範隨機挑選；若有引導需求，也可以用佇列依序播放）
	current_group = dialogue_groups.pick_random()
	current_line_index = 0
	
	_show_current_line()
	_show_bubble()

func _advance_or_close() -> void:
	current_line_index += 1
	
	# 如果群組中還有下一句，推進文字
	if current_group and current_line_index < current_group.dialogue_keys.size():
		_show_current_line()
	else:
		# 群組對話已播完，關閉氣泡
		_finish_current_group()
		_hide_bubble()

func _show_current_line() -> void:
	var key: String = current_group.dialogue_keys[current_line_index]
	# tr() 會依據目前系統語言自動獲取對應譯文
	label.text = tr(key)

func _finish_current_group() -> void:
	if current_group and current_group.play_once:
		# 播完即移除，之後不會再被挑中
		dialogue_groups.erase(current_group)
	current_group = null
	current_line_index = 0

func _show_bubble() -> void:
	if is_bubble_open: return
	is_bubble_open = true
	
	if active_tween and active_tween.is_valid():
		active_tween.kill()
		
	bubble.show()
	active_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	active_tween.tween_property(bubble, "modulate:a", 1.0, 0.2)

func _hide_bubble() -> void:
	if not is_bubble_open: return
	is_bubble_open = false
	
	if active_tween and active_tween.is_valid():
		active_tween.kill()
		
	active_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	active_tween.tween_property(bubble, "modulate:a", 0.0, 0.15)
	active_tween.tween_callback(bubble.hide)
