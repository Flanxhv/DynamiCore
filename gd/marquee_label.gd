extends Label

@export var scroll_speed: float = 80.0 # 滑動速度
@export var wait_time: float = 1.5     # 停留在原點與終點的等待時間

var marquee_tween: Tween

func play_marquee(new_text: String):
	# 1. 徹底清除並終止上一首歌的跑馬燈
	if marquee_tween and marquee_tween.is_valid():
		marquee_tween.kill()
		
	# 重置文字與位置
	text = new_text
	position.x = 0
	
	# 2. 等待一個 Frame，讓 Godot 把新文字真正渲染上去
	await get_tree().process_frame
	
	var container_width = 0.0
	var parent = get_parent()
	if parent is Control:
		container_width = parent.size.x
		
	# ==========================================
	# ★ 終極防呆：直接取得文字「實際所需的最小寬度」
	# 完美支援 LabelSettings，也不受編輯器拉扯邊框的影響
	# ==========================================
	var real_text_width = get_minimum_size().x
	
	# 3. 只有當文字真實所需寬度 > 容器寬度，才啟動跑馬燈
	if real_text_width > container_width:
		_start_animation(container_width, real_text_width)

func _start_animation(container_width: float, real_text_width: float):
	marquee_tween = create_tween().set_loops()
	
	var distance = real_text_width - container_width + 30.0 
	var duration = distance / scroll_speed
	
	marquee_tween.tween_interval(wait_time)
	marquee_tween.tween_property(self, "position:x", -distance, duration).set_trans(Tween.TRANS_LINEAR)
	marquee_tween.tween_interval(wait_time)
	marquee_tween.tween_property(self, "position:x", 0.0, 0.0)
