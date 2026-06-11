extends Area2D

var target_time: float = 0.0
var tail_time: float = 0.0
var speed: float = 2000.0
var audio_player: AudioStreamPlayer
var type: String = "NORMAL"

var current_time_diff: float = 999.0
var hit_width: float = 0.0
var is_head_hit: bool = false
var is_tail_hit: bool = false
var is_holding: bool = false 
var is_missed: bool = false

var spawn_distance: float = 850.0 
var body_rect: ColorRect

func _ready():
	add_to_group("notes")
	speed = 2000.0 * Global.note_speed_mult

func setup_visual(pixel_width: float, is_side_track: bool, note_type: String):
	type = note_type
	var visual = $Visual
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	if is_side_track:
		spawn_distance = 850.0
	else:
		spawn_distance = 940.0
	
	visual.anchor_left = 0
	visual.anchor_top = 0
	visual.anchor_right = 0
	visual.anchor_bottom = 0
	
	visual.size.x = pixel_width
	hit_width = pixel_width
	visual.size.y = 20
	visual.position.x = -pixel_width / 2.0
	visual.position.y = -10.0
	
	# ==========================================
	# ★ 核心修正：分配 Z-Index 渲染層級
	# ==========================================
	if type == "CHAIN":
		# 1. 提昇渲染層級
		z_index = 2
		
		# 2. 將原本的方形 ColorRect 設為「完全透明」，讓它退居幕後當隱形容器
		visual.color = Color(0.46, 0.847, 1.0, 0.0) 
		
		# 3. 動態建立一個多邊形節點來畫出「削尖角」
		var poly = Polygon2D.new()
		var w = (pixel_width) / 2.0
		var shave = 4.0 # 
		
		# 4. 依照順時針定義六個頂點，畫出帶有尖端的對稱形狀 (以中心點 0,0 為基準)
		poly.polygon = PackedVector2Array([
			Vector2(-w, 0),            # 左側最尖端 (垂直置中)
			Vector2(-w + shave, -9),  # 左上角折點
			Vector2(w - shave, -9),   # 右上角折點
			Vector2(w, 0),             # 右側最尖端 (垂直置中)
			Vector2(w - shave, 9),    # 右下角折點
			Vector2(-w + shave, 9)    # 左下角折點
		])
		
		# 填上原本 NORMAL 音符的顏色
		poly.color = Color(1.0, 0.234, 0.223, 1.0)
		
		# 5. 把多邊形加進 Visual 裡
		# 因為 Visual 自己已經位移到左上角了，我們要把多邊形的中心點推回來
		poly.position = Vector2(w, 10.0)
		visual.add_child(poly)
		
	elif type == "NORMAL":
		# 1. 提昇渲染層級
		z_index = 1
		
		# 2. 將原本的方形 ColorRect 設為「完全透明」，讓它退居幕後當隱形容器
		visual.color = Color(0.46, 0.847, 1.0, 0.0) 
		
		# 3. 動態建立一個多邊形節點來畫出「削尖角」
		var poly = Polygon2D.new()
		var w = pixel_width / 2.0
		var shave = 4.0
		
		# 4. 依照順時針定義六個頂點，畫出帶有尖端的對稱形狀 (以中心點 0,0 為基準)
		poly.polygon = PackedVector2Array([
			Vector2(-w, 0),            # 左側最尖端 (垂直置中)
			Vector2(-w + shave, -10),  # 左上角折點
			Vector2(w - shave, -10),   # 右上角折點
			Vector2(w, 0),             # 右側最尖端 (垂直置中)
			Vector2(w - shave, 10),    # 右下角折點
			Vector2(-w + shave, 10)    # 左下角折點
		])
		
		# 填上原本 NORMAL 音符的顏色
		poly.color = Color(0.681, 0.918, 1.0, 1.0)
		
		# 5. 把多邊形加進 Visual 裡
		# 因為 Visual 自己已經位移到左上角了，我們要把多邊形的中心點推回來
		poly.position = Vector2(w, 10.0)
		visual.add_child(poly)
	elif type == "HOLD":
		visual.color = Color(1.0, 0.8, 0.2)
		z_index = 0 # 乖乖待在底層
		
		body_rect = ColorRect.new()
		body_rect.size.x = pixel_width - 10
		body_rect.position.x = -(pixel_width - 10) / 2.0
		body_rect.color = Color(1.0, 0.8, 0.2, 0.0) 
		
		# ★ 取代原本的 move_child，這個屬性直接指示引擎將它畫在父節點(音符頭部)的後方
		body_rect.show_behind_parent = true 
		
		add_child(body_rect)

func _process(delta):
	if audio_player == null or not audio_player.playing:
		return
	if (is_head_hit and type != "HOLD") or is_tail_hit:
		return
	
	# ==========================================
	# ★ 絕對時間核心：直接讀取主場景經過平滑處理的遊戲時間
	# ==========================================
	var main_scene = get_tree().current_scene
	var current_master_time = main_scene.game_time
	
	# 用這個統一的時間來計算時間差
	current_time_diff = target_time - current_master_time
	
	# 處理 HOLD 漏接並斷 Combo
	if current_time_diff < -0.158 and not is_head_hit and not is_missed:
		if type == "NORMAL" or type == "CHAIN" or type == "HOLD": 
			is_missed = true 
			if main_scene.has_method("reset_combo_from_miss"):
				main_scene.reset_combo_from_miss()


	var head_y = 0.0
	
	if current_time_diff >= 0 or is_holding or is_head_hit:
		# 吸附魔法：如果長條正在被按著，強制將頭部座標鎖死在 0.0 (判定線)
		if is_holding and type == "HOLD":
			head_y = 0.0
		else:
			# 正常根據絕對時間差往下掉
			head_y = -(current_time_diff * speed)
		
		# 如果是玩家中途手滑放開，導致長條斷掉
		if is_head_hit and not is_holding and type == "HOLD":
			modulate.a = lerp(modulate.a, 0.4, 0.1) 
		else:
			modulate.a = 1.0 
			
	else:
		# 進入 Miss 減速淡出階段
		var past_time = -current_time_diff
		var fade_duration = 0.25 
		var progress = clamp(past_time / fade_duration, 0.0, 1.0)
		var max_drop_distance = 150.0 
		var ease_out = 1.0 - pow(1.0 - progress, 3.0) 
		head_y = ease_out * max_drop_distance
		
		modulate.a = 1.0 - progress
		if progress >= 1.0:
			queue_free()
			return
			
	position.y = head_y
	
	# 只要頭被打中了，就強制隱藏
	if head_y < -spawn_distance or is_head_hit:
		$Visual.visible = false
	else:
		$Visual.visible = true
		
	# 處理 HOLD 長條的身體繪製
	if type == "HOLD" and body_rect != null:
		# ★ 修正：這裡的尾巴時間差也必須使用統一的 master time
		var tail_diff = tail_time - current_master_time
		var tail_y = -(tail_diff * speed)
		
		var vis_tail_y = max(tail_y, -spawn_distance)
		var vis_tail_local = vis_tail_y - head_y
		
		if vis_tail_local < 0: 
			body_rect.visible = true
			body_rect.size.y = -vis_tail_local
			body_rect.position.y = vis_tail_local
			body_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var emerged_length = head_y + spawn_distance
			var target_alpha = clamp(emerged_length / 400.0, 0.0, 0.4)
			
			if is_holding:
				target_alpha = 0.6
				
			body_rect.color = Color(1.0, 0.8, 0.2, target_alpha)
		else:
			body_rect.visible = false
	
	# 清除過期的音符
	var end_time = tail_time if type == "HOLD" else target_time
	if current_master_time > end_time + 0.5:
		queue_free()
	
func hit_head():
	if is_head_hit: return
	is_head_hit = true
	
	if type == "HOLD":
		is_holding = true
		$Visual.visible = false 
	else:
		queue_free() 

func hit_tail():
	if is_tail_hit: return
	is_tail_hit = true
	is_holding = false
	queue_free() 

func break_hold():
	if not is_holding: return
	is_holding = false
	is_missed = true 
	
	var main_scene = get_tree().current_scene
	if main_scene.has_method("reset_combo_from_miss"):
		main_scene.reset_combo_from_miss()
		
	if body_rect != null:
		# 斷掉的瞬間變成失去光澤的暗灰色
		body_rect.color = Color(0.5, 0.5, 0.5, 0.2)
