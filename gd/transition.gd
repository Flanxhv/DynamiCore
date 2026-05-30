extends CanvasLayer

@onready var color_rect = $ColorRect

func _ready():
	color_rect.material.set_shader_parameter("progress", 0.0)
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

func reload_scene():
	color_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# 1. 畫面開始蔓延 (此時背景遊戲依然是凍結暫停的)
	var tween_in = create_tween()
	tween_in.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS) # ★ 強制讓動畫無視引擎暫停
	tween_in.tween_property(color_rect.material, "shader_parameter/progress", 1.0, 0.4)
	await tween_in.finished
	
	# 2. ★ 畫面全黑了！現在解凍引擎，玩家絕對聽不到也看不到！
	get_tree().paused = false
	get_tree().reload_current_scene()
	
	# 3. 畫面開始流出
	var tween_out = create_tween()
	tween_out.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS) # ★ 一樣強制無視暫停
	tween_out.tween_property(color_rect.material, "shader_parameter/progress", 2.0, 0.4)
	await tween_out.finished
	
	# 4. 完美收尾
	color_rect.material.set_shader_parameter("progress", 0.0)
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

# ==========================================
# ★ 順便把切換場景 (退出) 也升級一下
# ==========================================
func change_scene(target_path: String):
	color_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var tween_in = create_tween()
	tween_in.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween_in.tween_property(color_rect.material, "shader_parameter/progress", 1.0, 0.4)
	await tween_in.finished
	
	# ★ 畫面全黑瞬間解凍並換場
	get_tree().paused = false
	get_tree().change_scene_to_file(target_path)
	
	var tween_out = create_tween()
	tween_out.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween_out.tween_property(color_rect.material, "shader_parameter/progress", 2.0, 0.4)
	await tween_out.finished
	
	color_rect.material.set_shader_parameter("progress", 0.0)
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
