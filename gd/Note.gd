extends Area2D

const NOTE_TEXTURE = preload("res://pic/note_base.png")
const HOLD_BODY_TEXTURE = preload("res://pic/hold_body.png")
const ARROW_SHADER = preload("res://tscn/ProceduralArrow.gdshader")
static var BASE_HOLD_MATERIAL: ShaderMaterial = null
var arrow_material: ShaderMaterial
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

var visual: NinePatchRect

func _ready():
	add_to_group("notes")
	speed = 1800.0 * Global.note_speed_mult

func setup_visual(pixel_width: float, is_side_track: bool, note_type: String):
	type = note_type

	# 安全獲取節點（若叫 Visual 則抓取，若還是找不到印出警告）
	visual = get_node_or_null("Visual") as NinePatchRect
	if visual == null:
		push_error("Note.tscn 找不到名為 'Visual' 的 NinePatchRect 節點！請檢查節點名稱。")
		return

	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visual.texture = NOTE_TEXTURE

	spawn_distance = 850.0 if is_side_track else 940.0

	visual.size.x = pixel_width
	hit_width = pixel_width
	visual.position.x = -pixel_width / 2.0

	if type == "CHAIN":
		z_index = 2
		visual.size.y = 18.0
		visual.position.y = -9.0
		visual.self_modulate = Color(1.0, 0.234, 0.223, 1.0)

	elif type == "NORMAL":
		z_index = 1
		visual.size.y = 20.0
		visual.position.y = -10.0
		visual.self_modulate = Color(0.681, 0.918, 1.0, 1.0)

	elif type == "HOLD":
		z_index = 0
		visual.size.y = 20.0
		visual.position.y = -10.0
		visual.self_modulate = Color(1.0, 0.8, 0.2, 1.0)
	
		if body_rect == null:
			body_rect = ColorRect.new()
			body_rect.show_behind_parent = true
			body_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			
			if BASE_HOLD_MATERIAL == null:
				BASE_HOLD_MATERIAL = ShaderMaterial.new()
				BASE_HOLD_MATERIAL.shader = ARROW_SHADER
			
			# ★ 使用 duplicate() 複製已編譯的材質管線，參數各自獨立且不觸發 GPU 編譯阻塞
			arrow_material = BASE_HOLD_MATERIAL.duplicate()
			body_rect.material = arrow_material
			add_child(body_rect)
		
		body_rect.size.x = pixel_width - 10.0
		body_rect.position.x = -(pixel_width - 10.0) / 2.0
		body_rect.color = Color(1.0, 1.0, 1.0, 1.0)
		
			
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


	# ==========================================
	# 修正後的座標與長條維持邏輯
	# ==========================================
	var head_y = 0.0

	if is_holding and type == "HOLD":
		head_y = 0.0
		modulate.a = 1.0
	elif is_head_hit and type == "HOLD":
		head_y = -(current_time_diff * speed)
		# ★ 修正 1：不要在這裡壓成 0.4，交給 Shader 的灰色透明度控制即可
		modulate.a = 1.0
	elif current_time_diff >= 0:
		head_y = -(current_time_diff * speed)
		modulate.a = 1.0
	else:
		# 未擊中的 Miss 減速淡出流程 (只有一開始完全沒打中頭部時才觸發)
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

	if head_y < -spawn_distance or is_head_hit:
		$Visual.visible = false
	else:
		$Visual.visible = true

	# 處理 HOLD 長條的身體繪製
	if type == "HOLD" and body_rect != null:
		var tail_diff = tail_time - current_master_time
		var tail_y = -(tail_diff * speed)
		var vis_tail_y = max(tail_y, -spawn_distance)
		
		var effective_head_y = max(head_y, 0.0) if is_head_hit else head_y
		var vis_tail_local = vis_tail_y - effective_head_y
		
		if tail_diff >= 0.0:
			body_rect.visible = true
			var current_height = abs(vis_tail_local)
			body_rect.size.y = current_height
			body_rect.position.y = -current_height
			
			if arrow_material:
				# 僅需傳入尺寸與狀態，不再需要計算 repeat_count
				arrow_material.set_shader_parameter("rect_size", body_rect.size)
				arrow_material.set_shader_parameter("is_holding_active", 1.0 if is_holding else 0.0)
				arrow_material.set_shader_parameter("is_missed", 1.0 if is_missed else 0.0)
			
			var emerged_length = head_y + spawn_distance
			var spawn_fade = clamp(emerged_length / 400.0, 0.0, 1.0)
			body_rect.color = Color(1.0, 1.0, 1.0, spawn_fade)
		else:
			body_rect.visible = false

	var end_time = tail_time if type == "HOLD" else target_time
	if current_master_time > end_time + 0.5:
		queue_free()

func hit_head():
	if is_head_hit: return
	is_head_hit = true

	if type == "HOLD":
		is_holding = true
		$Visual.visible = false
		
		# ★ 向主場景請求啟動池化長條粒子
		var main_scene = get_tree().current_scene
		if main_scene.has_method("start_hold_effect"):
			main_scene.start_hold_effect(self)
	else:
		queue_free()

func hit_tail():
	if is_tail_hit: return
	is_tail_hit = true
	is_holding = false
	
	# ★ 通知主場景停止發射
	var main_scene = get_tree().current_scene
	if main_scene.has_method("stop_hold_effect"):
		main_scene.stop_hold_effect(self)
		
	# 不用等待，直接銷毀實體
	queue_free()

func break_hold():
	if not is_holding: return
	is_holding = false
	is_missed = true

	# ★ 斷押：通知主場景停止發射
	var main_scene = get_tree().current_scene
	if main_scene.has_method("stop_hold_effect"):
		main_scene.stop_hold_effect(self)
		
	if main_scene.has_method("reset_combo_from_miss"):
		main_scene.reset_combo_from_miss()

	if body_rect != null:
		body_rect.color = Color(0.4, 0.4, 0.4, 1)

# ★ 確保音符中途因任何原因被 queue_free 時（例如 Miss 掉落或超時）也能安全關閉粒子
func _exit_tree():
	var main_scene = get_tree().current_scene
	if main_scene and main_scene.has_method("stop_hold_effect"):
		main_scene.stop_hold_effect(self)
