extends CanvasLayer

@onready var toast_box: Control = $ToastBox
@onready var toast_label: Label = $ToastBox/Label

# 訊息佇列：存放待顯示的 Dictionary 或字串
var _queue: Array[Dictionary] = []
var _is_displaying: bool = false
var _tween: Tween

func _ready() -> void:
	toast_box.visible = false
	toast_box.modulate.a = 0.0

func show_toast(msg: String, duration: float = 1.5) -> void:
	_queue.append({"msg": msg, "duration": duration})
	if not _is_displaying:
		_process_queue()

func _process_queue() -> void:
	if _queue.is_empty():
		_is_displaying = false
		return

	_is_displaying = true
	var current: Dictionary = _queue.pop_front()
	
	toast_label.text = current["msg"]
	toast_box.visible = true
	
	if _tween and _tween.is_valid():
		_tween.kill()

	_tween = create_tween()
	# 淡入
	_tween.tween_property(toast_box, "modulate:a", 1.0, 0.2)
	# 停留
	_tween.tween_interval(current["duration"])
	# 淡出
	_tween.tween_property(toast_box, "modulate:a", 0.0, 0.3)
	# 結束後隱藏並處理下一則
	_tween.tween_callback(func():
		toast_box.visible = false
		_process_queue()
	)
