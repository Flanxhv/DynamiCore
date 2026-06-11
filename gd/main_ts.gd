extends Node2D
@export var note_scene: PackedScene
@export var bg_brightness: float = 0.4 # 預設亮度 40% (避免背景太亮妨礙看譜)

var current_note_idx: int = 0
var spawn_lead_time: float = 2.0 
var game_time: float = 0.0 
var current_combo: int = 0
var active_touches: Dictionary = {}
var max_combo: int = 0
var speed: float = 1500
var has_touch_screen: bool = false
var is_ap_animating: bool = false
var total_expected_judgments: int = 0
var blur_effect_material: ShaderMaterial = null
var warning_events: Array[Dictionary] = []
var current_warning_idx: int = 0

@onready var offset_label = $HUD/PauseMenu/OffsetLabel
@onready var offset_minus_btn = $HUD/PauseMenu/OffsetMinusButton
@onready var offset_plus_btn = $HUD/PauseMenu/OffsetPlusButton
@onready var result_diff_line = $HUD/ResultMenu/SongNameRect2
@onready var ap_particles = $HUD/AP_Overlay/AP_Center/AP_Particles
@onready var song_label = $HUD/SongLabel
@onready var progress_bar = $HUD/SongProgressBar
@onready var background = $Background
@onready var downrect = $DownRect
@onready var result_menu = $HUD/ResultMenu
@onready var result_score_label = $HUD/ResultMenu/ScoreLabel
@onready var result_details_label = $HUD/ResultMenu/DetailsLabel
@onready var res_restart_btn = $HUD/ResultMenu/RestartButton
@onready var res_quit_btn = $HUD/ResultMenu/QuitButton
@onready var combo_label = $HUD/ComboLabel
@onready var audio_player = $AudioStreamPlayer
@onready var track_bottom = $BottomTrack
@onready var track_left = $LeftTrack
@onready var track_right = $RightTrack
@onready var judgement_label = $HUD/JudgmentLabel
@onready var stats_label = $HUD/StatsLabel
@onready var pause_button = $HUD/PauseButton
@onready var pause_menu = $HUD/PauseMenu
@onready var restart_button = $HUD/PauseMenu/RestartButton
@onready var quit_button = $HUD/PauseMenu/QuitButton
@onready var result_song_label = $HUD/ResultMenu/SongNameLabel
@onready var ap_overlay = $HUD/AP_Overlay
@onready var ap_dim_bg = $HUD/AP_Overlay/DimBackground
@onready var ap_center = $HUD/AP_Overlay/AP_Center
@onready var ap_top_line = $HUD/AP_Overlay/AP_Center/TopLine
@onready var ap_bottom_line = $HUD/AP_Overlay/AP_Center/BottomLine
@onready var ap_label = $HUD/AP_Overlay/AP_Center/AP_Label


# ★ 新增：用來記錄整局的判定數量
var judge_stats = {"PERFECT": 0, "GOOD": 0, "MISS": 0}
var tween_combo: Tween
var tween_judge: Tween
# 就像 Java 的 Class，我們建一個內部結構來裝單個音符的資料
class NoteData:
	var id: int
	var type: String     # NORMAL, CHAIN, HOLD
	var time: float
	var real_time: float # 頭部秒數
	var position: float
	var width: float
	var sub_id: int
	var side: String
	var tail_real_time: float = 0.0 # 專門給 HOLD 用的尾部秒數

# 存放所有音符的陣列
var all_notes: Array[NoteData] = []
var left_region: String = "PAD"
var right_region: String = "PAD"

# 用來存放接水果盤的實體節點
var left_paddle: Panel  
var right_paddle: Panel 

# 全域譜面參數
var bar_per_min: float = 0.0
var time_offset: float = 0.0

func _ready():
	# 1. 確保有拿到歌曲資料 (防呆機制)
	speed = 1900.0 + 100.0 * Global.note_speed_mult
	var required_lead_time = 1200.0 / speed
	
	# 我們取 2.0 秒或是 required_lead_time 兩者之間比較大的那個
	# 這樣就算玩家速度調超快 (只需 0.5 秒就掉下來)，系統依然會提早 2 秒生成，保留緩衝效能
	spawn_lead_time = max(2.0, required_lead_time)
	if Global.current_song_data.is_empty():
		print("沒有歌曲資料！退回主選單...")
		get_tree().change_scene_to_file("uid://dnda82ibqdnuq")
		return
	
	var song_id = Global.current_song_data.get("id", Global.current_song_data.get("title", "unknown_song"))
	Global.current_song_data["song_offset"] = Global.get_song_offset(song_id)

	# ★ 新增：綁定暫停選單中的校準按鈕事件，並更新文字
	if offset_minus_btn and offset_plus_btn:
		offset_minus_btn.pressed.connect(_on_offset_minus_pressed)
		offset_plus_btn.pressed.connect(_on_offset_plus_pressed)
		_update_offset_label()
	# ★ 處理背景圖與亮度
	# 留下接口：只要改變 bg_brightness (0.0 暗 ~ 1.0 亮)，就能控制背景明暗
	background.modulate = Color(Global.bg_brightness, Global.bg_brightness, Global.bg_brightness, 1.0)
	if Global.current_song_data.has("cover_path"):
		background.texture = load_external_image(Global.current_song_data["cover_path"])
		background.size = get_viewport_rect().size
		background.position = Vector2(0, 0) # 確保圖片對齊螢幕左上角
	var chart_path = Global.current_chart_path
	var audio_path = Global.current_song_data["audio_path"]
	song_label.text = Global.current_song_data["title"]
	print("即將遊玩: ", Global.current_song_data["title"])
	
	# 2. 動態載入音樂檔案並放進 AudioStreamPlayer
	var audio_stream = load_external_audio(audio_path)
	if audio_stream:
		audio_player.stream = audio_stream
	else:
		print("找不到音樂檔案！請檢查路徑：", audio_path)
		
	# 3. 解析對應的 XML 譜面
	parse_dynamix_xml(chart_path)
	if left_region == "MIXER":
		left_paddle = Panel.new()
		left_paddle.size = Vector2(195, 45)
		left_paddle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		var style = StyleBoxFlat.new()
		style.bg_color = Color.BLACK
		style.border_color = Color.WHITE
		style.set_border_width_all(5)
		left_paddle.add_theme_stylebox_override("panel", style)
		
		# ★ 座標取決於它加在哪個軌道上
		if Global.mirror_mode:
			track_right.add_child(left_paddle)
			left_paddle.position = Vector2(-159, -22.5) # 右軌道的專屬位置
		else:
			track_left.add_child(left_paddle)
			left_paddle.position = Vector2(-36, -22.5)  # 左軌道的專屬位置

	if right_region == "MIXER":
		right_paddle = Panel.new()
		right_paddle.size = Vector2(195, 45)
		right_paddle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		var style = StyleBoxFlat.new()
		style.bg_color = Color.BLACK
		style.border_color = Color.WHITE
		style.set_border_width_all(5)
		right_paddle.add_theme_stylebox_override("panel", style)
		
		# ★ 同理，判斷它最終去了哪裡
		if Global.mirror_mode:
			track_left.add_child(right_paddle)
			right_paddle.position = Vector2(-36, -22.5)  # 左軌道的專屬位置
		else:
			track_right.add_child(right_paddle)
			right_paddle.position = Vector2(-159, -22.5) # 右軌道的專屬位置
	await get_tree().create_timer(0.75).timeout
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0, 0, 0, 0.8)       # 80% 不透明的黑底
	btn_style.border_color = Color(1, 1, 1, 1)     # 純白外框
	btn_style.set_border_width_all(4)              # 外框粗細 4px
	btn_style.set_corner_radius_all(8)             # 圓角 8px
	
	# 將這個樣式強制套用到「重新開始」和「退出」按鈕的所有狀態
	var target_buttons = [restart_button, quit_button,res_quit_btn,res_restart_btn]
	
	for btn in target_buttons:
		if btn != null:
			btn.add_theme_stylebox_override("normal", btn_style)
			btn.add_theme_stylebox_override("hover", btn_style)
			btn.add_theme_stylebox_override("pressed", btn_style)
			btn.add_theme_stylebox_override("focus", btn_style)
			
			# 順便強制把字體改成白色，確保黑底上絕對看得清楚
			btn.add_theme_color_override("font_color", Color.WHITE)
			btn.add_theme_color_override("font_hover_color", Color.WHITE)
			btn.add_theme_color_override("font_pressed_color", Color.GRAY) # 按下時字體稍微變暗
	# ==========================================
	if audio_player.stream:
		progress_bar.max_value = audio_player.stream.get_length()
	
	audio_player.play()
	pause_button.pressed.connect(_on_pause_button_pressed)
	restart_button.pressed.connect(_on_restart_button_pressed) #
	quit_button.pressed.connect(_on_quit_button_pressed)
	res_restart_btn.pressed.connect(_on_restart_button_pressed)
	res_quit_btn.pressed.connect(_on_quit_button_pressed)
	audio_player.finished.connect(_on_audio_finished)
	_init_blur_material()

func _on_audio_finished():
	if is_ap_animating:
		# 如果正在播 AP 動畫，這裡什麼都不做 (Return)
		# 結算畫面會交給 AP 動畫播完後自己去呼叫
		return 
	else:
		# 如果沒有 AP 動畫 (例如一般通關或斷 Combo)，直接進結算
		_show_result_screen()
		
func _prepare_track_warnings():
	warning_events.clear()
	current_warning_idx = 0
	
	# 設定初始值為極小值，確保該軌道的第一顆音符一定會觸發提示
	var last_time_left: float = -999.0
	var last_time_right: float = -999.0
	
	for n in all_notes:
		if n.side == "left":
			# 條件：距離上一個左側音符大於 5 秒
			if n.real_time - last_time_left > 4.5:
				warning_events.append({"time": n.real_time - 1.7, "side": "left"})
			last_time_left = n.real_time
			
		elif n.side == "right":
			# 條件：距離上一個右側音符大於 5 秒
			if n.real_time - last_time_right > 4.5:
				warning_events.append({"time": n.real_time - 1.7, "side": "right"})
			last_time_right = n.real_time

	# 依照觸發時間排序，確保 _process 依序讀取
	warning_events.sort_custom(func(a, b): return a["time"] < b["time"])
#xml file
func parse_dynamix_xml(file_path: String):
	var parser = XMLParser.new()
	if parser.open(file_path) != OK:
		print("無法開啟譜面檔案！")
		return

	var current_side = "bottom"
	var current_note: NoteData = null
	var current_element = ""
	
	# 我們先用一個暫存陣列把所有東西(包含SUB)存起來
	var temp_all_notes: Array[NoteData] = []

	while parser.read() == OK:
		var node_type = parser.get_node_type()
		var node_name = "" # 先預設為空字串
		
		# ★ 核心修正：只有在它是「標籤開頭」或「標籤結尾」時，才可以去問名字！
		if node_type == XMLParser.NODE_ELEMENT or node_type == XMLParser.NODE_ELEMENT_END:
			node_name = parser.get_node_name()

		if node_type == XMLParser.NODE_ELEMENT:
			current_element = node_name
			if node_name == "m_notesLeft":
				current_side = "left"
			elif node_name == "m_notesRight":
				current_side = "right"
			elif node_name == "CMapNoteAsset":
				current_note = NoteData.new()
				current_note.side = current_side

		elif node_type == XMLParser.NODE_TEXT:
			var text = parser.get_node_data().strip_edges()
			if text == "": continue

			if current_element == "m_barPerMin":
				bar_per_min = text.to_float()
			elif current_element == "m_timeOffset":
				time_offset = text.to_float()
			elif current_element == "m_leftRegion":
				left_region = text
			elif current_element == "m_rightRegion":
				right_region = text
			elif current_note != null:
				match current_element:
					"m_id": current_note.id = text.to_int()
					"m_type": current_note.type = text
					"m_time": current_note.time = text.to_float()
					"m_position": current_note.position = text.to_float()
					"m_width": current_note.width = text.to_float()
					"m_subId": current_note.sub_id = text.to_int()

		elif node_type == XMLParser.NODE_ELEMENT_END:
			if node_name == "CMapNoteAsset" and current_note != null:
				temp_all_notes.append(current_note)
				current_note = null 
			elif node_name == "m_notesLeft" or node_name == "m_notesRight":
				current_side = "bottom"

	# ==========================================
	# ★ MIRROR 模式：左右交換與底部鏡像翻轉
	# ==========================================
	if Global.mirror_mode:
		for n in temp_all_notes:
			# 1. 左右軌道音符對調
			if n.side == "left":
				n.side = "right"
			elif n.side == "right":
				n.side = "left"
			# 2. 底部軌道左右翻轉 (假設 Dynamix 預設底部軌道寬度是 5，即 0~5)
			elif n.side == "bottom":
				n.position = 5.0 - n.position - n.width
	# ==========================================

	# === 核心修正邏輯開始 ===
	# === 核心修正邏輯開始 ===
	var sec_per_bar = 60.0 / bar_per_min if bar_per_min > 0 else 0
	var id_dict = {}
	
	var current_song_offset = Global.current_song_data.get("song_offset", 0.0)
	
	# 步驟 1：計算所有音符的真實時間，並存入字典方便搜尋
	for n in temp_all_notes:
		# 【修正錯位】將 + time_offset 改為 - time_offset
		# ★ 新增：將 current_song_offset 加上去
		n.real_time = (n.time * sec_per_bar) - time_offset + Global.device_offset + current_song_offset
		
		# ★ 修正：將 ID 加上軌道標籤 (side)，避免左中右三條軌道的 ID 互相覆蓋！
		var unique_id = str(n.side) + "_" + str(n.id)
		id_dict[unique_id] = n
		
	# 步驟 2：過濾掉 SUB，並把 SUB 的時間綁定給它的 HOLD 老大
	for n in temp_all_notes:
		if n.type == "SUB":
			continue
			
		if n.type == "HOLD":
			# ★ 修正：尋找尾巴時，一樣要加上自己所在的軌道標籤
			var target_sub_key = str(n.side) + "_" + str(n.sub_id)
			
			if id_dict.has(target_sub_key):
				n.tail_real_time = id_dict[target_sub_key].real_time
			else:
				n.tail_real_time = n.real_time + 0.5 # 防呆機制
			if n.tail_real_time - n.real_time < 0.02:
				# 強制把它拉長到 0.02 秒。
				# 這樣在 speed = 2000 的情況下，它的身體至少會有 40 像素的長度，足以被玩家看見！
				n.tail_real_time = n.real_time + 0.04
		all_notes.append(n)

	# 依照發生時間重新排序
	all_notes.sort_custom(func(a, b): return a.real_time < b.real_time)
	total_expected_judgments = 0
	for n in all_notes:
		if n.type == "HOLD":
			total_expected_judgments += 2
		else:
			total_expected_judgments += 1
	print("===== 修正版譜面讀取完成 =====")
	print("原始載入數: ", temp_all_notes.size(), " | 過濾掉 SUB 後的實際音符數: ", all_notes.size())
	print("BPM (BarPerMin): ", bar_per_min, " | Offset: ", time_offset)
	print("總共載入音符數: ", all_notes.size())
	
	##側邊閃爍預警事件
	_prepare_track_warnings()
	
func _process(delta):
	if not audio_player.playing:
		return
	# 正常情況下，用每一幀的平滑時間(delta)來推進
	game_time += delta 
	
	# 獲取音訊真實時間
	var actual_audio_time = audio_player.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency() 
	if progress_bar:
		progress_bar.value = actual_audio_time
	# 如果我們的平滑時間跟真實音樂時間差超過 20 毫秒 (0.02秒)，才輕微地拉回來同步
	if abs(game_time - actual_audio_time) > 0.02:
		game_time = lerp(game_time, actual_audio_time, 0.5)
	
	var current_time = game_time
	
	# 預警事件判斷
	while current_warning_idx < warning_events.size():
		var w = warning_events[current_warning_idx]
		if current_time >= w["time"]:
			_play_track_warning(w["side"])
			current_warning_idx += 1
		else:
			break
	# ★ 每一幀都要掃描 CHAIN 和 HOLD 的狀態
	check_chain_notes()
	
	# ==========================================
	# ★ AUTO 模式：由電腦攔截所有點擊時間 (不處理滑塊移動)
	# ==========================================
	if Global.auto_play:
		var active_notes = get_tree().get_nodes_in_group("notes")
		for note in active_notes:
			# 1. 處理所有未點擊的音符頭部 (NORMAL, CHAIN, HOLD)
			if not note.is_head_hit:
				if note.current_time_diff <= 0.01:
					spawn_hit_effect(note, Color(1.0, 1.0, 1.0, 0.8)) # 永遠是 PERFECT 白光
					note.hit_head()
					current_combo += 1
					_show_feedback("PERFECT")
			
			# 2. 處理正在按壓的 HOLD 尾部
			elif note.type == "HOLD" and note.is_holding:
				var t_diff_tail = note.tail_time - current_time
				if t_diff_tail <= 0.0:
					spawn_hit_effect(note, Color(1.0, 1.0, 1.0, 0.8))
					note.hit_tail()
					current_combo += 1
					_show_feedback("PERFECT")
	else:
		# 非 AUTO 模式下，才去移動盤子位置
		if left_paddle != null or right_paddle != null:
			var screen_width = get_viewport_rect().size.x
			
			for touch_pos in active_touches.values():
				# ==========================================
				# 1. 處理螢幕「左半邊」的滑動 (對應實體的 track_left)
				# ==========================================
				if touch_pos.x < screen_width * 0.15: # 加大觸控判定區間，手感更好
					var local_pos = track_left.to_local(touch_pos)
					
					# 找出現在是哪個盤子掛在左軌道上 (解決 MIRROR 模式觸控錯亂的問題)
					var paddle_on_left = right_paddle if Global.mirror_mode else left_paddle
					
					if paddle_on_left != null:
						# ★ 左軌道精準數學極限：總長 750 像素
						paddle_on_left.position.x = clamp(local_pos.x - 97.5, -422.5, 327.5) #-402.5 347.5 750
						
				# ==========================================
				# 2. 處理螢幕「右半邊」的滑動 (對應實體的 track_right)
				# ==========================================
				elif touch_pos.x > screen_width * 0.85:
					var local_pos = track_right.to_local(touch_pos)
					
					# 找出現在是哪個盤子掛在右軌道上
					var paddle_on_right = left_paddle if Global.mirror_mode else right_paddle
					
					if paddle_on_right != null:
						# ★ 右軌道精準數學極限：總長 750 像素
						paddle_on_right.position.x = clamp(local_pos.x - 97.5, -522.5, 227.5) #-542.5 207.5 750
		check_hold_notes()
	
	# 持續檢查是否該生成下一個音符
	while current_note_idx < all_notes.size():
		var n = all_notes[current_note_idx]
		
		if current_time + spawn_lead_time >= n.real_time:
			if n.type == "NORMAL" or n.type == "CHAIN" or n.type == "HOLD": 
				spawn_note(n,current_time)
			current_note_idx += 1
		else:
			break 
	
func _play_track_warning(side: String):
	# 決定要掛在哪個軌道上
	var target_track = track_left if side == "left" else track_right
	
	# 動態建立一個警告用的長條光暈 (或者你也可以直接指定你場景裡原本就做好的發光節點)
	var warning_light = ColorRect.new()
	warning_light.color = Color(0.0, 0.0, 0.0, 0.0) # 預設透明紅色
	
	# 尺寸與定位 (需依據你遊戲內的軌道實際長寬微調)
	# ★ 修正：將長度設定在 X 軸 (750)，厚度設定在 Y 軸 (暫設為 20 像素)
	warning_light.size = Vector2(2000, 200) 

	warning_light.position = Vector2(-470.0, -10.0)

	target_track.add_child(warning_light)
	
	# 使用 Tween 製作連續閃爍 3 次的動畫
	var tween = create_tween()
	var blink_duration = 0.15
	
	for i in range(2):
		tween.tween_property(warning_light, "color:a", 0.6, blink_duration).set_ease(Tween.EASE_OUT)
		tween.tween_property(warning_light, "color:a", 0.0, blink_duration).set_ease(Tween.EASE_IN)
		
	# 動畫播完後自動刪除該節點，釋放記憶體
	tween.tween_callback(warning_light.queue_free)
var track_center_pos = 2.5 

func spawn_note(n, current_time):
	var new_note = note_scene.instantiate()
	new_note.target_time = n.real_time
	new_note.audio_player = audio_player
	new_note.tail_time = n.tail_real_time 
	
	var time_diff = n.real_time - current_time
	new_note.position.y = -(time_diff * 2000.0 * Global.note_speed_mult)
	
	# 將 XML 的「左邊緣座標」轉換回「真正的中心點座標」
	var actual_center_pos = n.position + (n.width / 2.0)
	
	var side_up_offset = -70.0 
	
	if n.side == "bottom":
		new_note.position.x = (actual_center_pos - track_center_pos) * 300.0
		var pixel_w = max(n.width * 300.0 - 30.0, 20.0)
		new_note.setup_visual(pixel_w, false, n.type)
		track_bottom.add_child(new_note)
		
	elif n.side == "left":
		new_note.position.x = -(actual_center_pos - track_center_pos) * 150.0 - side_up_offset
		var pixel_w = max(n.width * 150.0 - 30.0, 20.0)
		new_note.setup_visual(pixel_w, true, n.type)
		track_left.add_child(new_note)
		
	elif n.side == "right":
		new_note.position.x = (actual_center_pos - track_center_pos) * 150.0 + side_up_offset
		var pixel_w = max(n.width * 150.0 - 30.0, 20.0)
		new_note.setup_visual(pixel_w, true, n.type)
		track_right.add_child(new_note)

func _unhandled_input(event):
	# ==========================================
	# ★ AUTO 模式：絕對禁止人類干預！
	# ==========================================
	if Global.auto_play:
		return

	# 1. 處理真實的手指觸控
	if event is InputEventScreenTouch:
		has_touch_screen = true # ★ 只要摸過螢幕，就標記這台裝置有觸控功能！
		if event.pressed:
			active_touches[event.index] = event.position
			try_hit_note(event.position) 
		else:
			active_touches.erase(event.index) 
			
	elif event is InputEventScreenDrag:
		active_touches[event.index] = event.position
		
	# 2. 處理滑鼠點擊 (加入過濾機制)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if has_touch_screen:
			return # ★ 核心防呆：既然是用手指玩的，就直接無視引擎偷偷模擬出來的滑鼠點擊！
			
		if event.pressed:
			var mouse_pos = get_global_mouse_position()
			active_touches[-1] = mouse_pos 
			try_hit_note(mouse_pos)
		else:
			active_touches.erase(-1)
			
	elif event is InputEventMouseMotion:
		if has_touch_screen:
			return # ★ 同理，無視模擬出來的滑鼠移動
			
		if active_touches.has(-1):
			active_touches[-1] = get_global_mouse_position()
		
func try_hit_note(touch_pos: Vector2):
	var active_notes = get_tree().get_nodes_in_group("notes")
	
	var early_miss_window = 0.234  
	var late_good_window = -0.152  
	
	var best_time_diff = 999.0
	var has_tap_target = false # ★ 新增：用來標記是否已經鎖定了 NORMAL 或 HOLD
	var valid_notes_under_finger = [] 
	
	for note in active_notes:
		if note.is_head_hit or (note.type != "NORMAL" and note.type != "HOLD" and note.type != "CHAIN"):
			continue
			
		var t_diff = note.current_time_diff 
		
		if t_diff >= late_good_window and t_diff <= early_miss_window:
			var track = note.get_parent()
			var local_touch = track.to_local(touch_pos)
			
			var dist_x = abs(local_touch.x - note.position.x)
			var valid_x = (dist_x <= (note.hit_width / 2.0) + 60.0)
			
			if not valid_x:
				continue
				
			var valid_y = false
			if track.name == "BottomTrack":
				var abs_x = abs(local_touch.x)
				var max_up_reach = -700.0 
				if abs_x > 450.0:
					var drop_off = clamp((abs_x - 450.0) / 450.0, 0.0, 1.0)
					max_up_reach = lerp(-700.0, -350.0, drop_off)
				if local_touch.y >= max_up_reach and local_touch.y <= 200.0:
					valid_y = true
			else:
				if abs(local_touch.y) <= 200.0:
					valid_y = true
					
			if valid_y:
				valid_notes_under_finger.append(note)
				
				# ==========================================
				# ★ 優先級判定系統
				# ==========================================
				var is_tap_note = (note.type == "NORMAL" or note.type == "HOLD")
				
				if is_tap_note:
					if not has_tap_target:
						# 【防誤觸機制】
						# 如果系統已經暫時鎖定了一顆 CHAIN，且玩家點擊時間對 CHAIN 來說「極度完美」 (誤差 <= 0.059 秒)
						# 但這顆 NORMAL 其實還有點距離 (誤差 > 0.08 秒)
						# 那我們就放棄鎖定這顆 NORMAL，把這次點擊還給 CHAIN。
						if best_time_diff != 999.0 and abs(best_time_diff) <= 0.059 and abs(t_diff) > 0.08:
							continue 
							
						best_time_diff = t_diff
						has_tap_target = true
					elif abs(t_diff) < abs(best_time_diff):
						best_time_diff = t_diff
				else:
					# 如果是 CHAIN，只有在還沒鎖定 NORMAL 的情況下才能競爭最佳時間
					if not has_tap_target and abs(t_diff) < abs(best_time_diff):
						best_time_diff = t_diff
	
	if valid_notes_under_finger.is_empty():
		return
		
	# ... (後面的計算 ms_diff、hit_color、以及第二階段的判定邏輯都不用變，維持上一版的即可)
	
	# ==========================================
	var ms_diff = round(best_time_diff * 1000)
	var hit_color = Color(1.0, 1.0, 1.0, 0.8) # 預設 PERFECT 純白光
	
	if ms_diff > 152 and ms_diff <= 234:
		hit_color = Color(1.0, 0.2, 0.2, 0.8) # EARLY MISS：危險的紅光
	elif abs(ms_diff) > 59 and abs(ms_diff) <= 152:
		hit_color = Color(0.2, 1.0, 0.2, 0.8) # GOOD：清脆的綠光
	# ==========================================
		
	var normal_hit_count = 0
	
	# ★ 修正 2：在點擊結算階段，分流 CHAIN 與 NORMAL/HOLD 的邏輯
	for note in valid_notes_under_finger:
		if abs(note.current_time_diff - best_time_diff) <= 0.005:
			
			if note.type == "CHAIN":
				# 如果玩家點到的是 CHAIN，手動觸發它的判定
				# 確保只在 CHAIN 的合法區間 (<=0.059) 才產生擊中效果
				if note.current_time_diff <= 0.059 and note.current_time_diff > -0.158:
					var chain_color = Color(1.0, 1.0, 1.0, 0.8)
					if note.current_time_diff < -0.059:
						chain_color = Color(0.2, 1.0, 0.2, 0.8) # LATE GOOD
						
					spawn_hit_effect(note, chain_color)
					note.hit_head()
					current_combo += 1
					
					if note.current_time_diff >= -0.059:
						_show_feedback("PERFECT")
					else:
						_show_feedback("GOOD")
				# 註：如果玩家提早點擊 (>0.059)，此處不做任何事。
				# 它完美「吸收」了這次提早點擊，不會產生 EARLY MISS，符合原遊戲邏輯。
				
			else:
				# NORMAL / HOLD 判定
				spawn_hit_effect(note, hit_color)
				note.hit_head()
				normal_hit_count += 1
			
	# ★ 修正 3：只有當真的打到 NORMAL 或 HOLD 時，才觸發整體的判定狀態
	if normal_hit_count > 0:
		if ms_diff > 152 and ms_diff <= 234:
			current_combo = 0
			_show_feedback("MISS")
		elif abs(ms_diff) <= 59:
			current_combo += normal_hit_count
			_show_feedback("PERFECT")
		elif abs(ms_diff) <= 152:
			current_combo += normal_hit_count
			_show_feedback("GOOD")


func check_chain_notes():
	# (注意：這裡移除了原本 active_touches.is_empty() 就 return 的設定，因為盤子放著也能接！)
	var active_notes = get_tree().get_nodes_in_group("notes")
	
	for note in active_notes:
		if note.is_head_hit or note.type != "CHAIN":
			continue
			
		var t_diff = note.current_time_diff
		
		# 只要進入 Early 區間到漏接邊緣，都可以被觸發
		if t_diff <= 0.059 and t_diff > -0.158:
			var track = note.get_parent()
			var is_caught = false
			
			# ==========================================
			# ★ AUTO 模式攔截：自動在 PERFECT 時間接住 CHAIN
			# ==========================================
			if Global.auto_play:
				if t_diff <= 0.07:
					is_caught = true
					
				var is_mixer = false
				var current_paddle: Panel = null
				
				if track.name == "LeftTrack" and left_region == "MIXER":
					is_mixer = true
					current_paddle = left_paddle
				elif track.name == "RightTrack" and right_region == "MIXER":
					is_mixer = true
					current_paddle = right_paddle
					
				if is_mixer and current_paddle != null:
					# 讓盤子的中心對齊 CHAIN 音符的 X 座標
					# 注意：盤子的 position.x 是左上角，所以要減去半寬 (97.5) 來置中
					current_paddle.position.x = note.position.x - 97.5
			else:
				# 1. 判斷這顆音符所在的軌道，是不是 MIXER 模式？
				var is_mixer = false
				var current_paddle: Panel = null
				
				if track.name == "LeftTrack" and left_region == "MIXER":
					is_mixer = true
					current_paddle = left_paddle
				elif track.name == "RightTrack" and right_region == "MIXER":
					is_mixer = true
					current_paddle = right_paddle
					
				# ==========================================
				if is_mixer and current_paddle != null:
					# ★ MIXER 模式：檢查音符是否與盤子「重疊」
					var paddle_center_x = current_paddle.position.x + 97.5
					var dist_x = abs(paddle_center_x - note.position.x)
					
					if dist_x <= (note.hit_width / 2.0) + 97.5:
						is_caught = true
				# ==========================================
				else:
					# ★ PAD 模式：維持原本的「手指追蹤」邏輯
					if active_touches.is_empty():
						continue 
						
					for touch_pos in active_touches.values():
						var local_touch = track.to_local(touch_pos)
						var dist_x = abs(local_touch.x - note.position.x)
						
						if dist_x > (note.hit_width / 2.0) + 60.0:
							continue
							
						var valid_y = false
						if track.name == "BottomTrack":
							var abs_x = abs(local_touch.x)
							var max_up_reach = -580.0
							if abs_x > 450.0:
								var drop_off = clamp((abs_x - 450.0) / 450.0, 0.0, 1.0)
								max_up_reach = lerp(-580.0, -150.0, drop_off)
							if local_touch.y >= max_up_reach and local_touch.y <= 150.0:
								valid_y = true
						else:
							if abs(local_touch.y) <= 150.0:
								valid_y = true
								
						if valid_y:
							is_caught = true
							break 
			
			# 2. 結算擊中邏輯
			if is_caught:
				# 根據時間差給顏色 (遲到給綠光，其他給白光)
				var chain_color = Color(1.0, 1.0, 1.0, 0.8)
				if t_diff < -0.059 and not Global.auto_play:
					chain_color = Color(0.2, 1.0, 0.2, 0.8) # LATE GOOD 綠光
					
				spawn_hit_effect(note, chain_color)
				note.hit_head()
				current_combo += 1
				
				if t_diff >= -0.059 or Global.auto_play:
					_show_feedback("PERFECT")
				else:
					_show_feedback("GOOD")

func check_hold_notes():
	var active_notes = get_tree().get_nodes_in_group("notes")
	
	for note in active_notes:
		if not note.is_holding or note.type != "HOLD":
			continue
			
		var track = note.get_parent()
		var is_finger_still_on_it = false
		
		# 檢查有沒有任何一根手指，還踩在這個長條的 X 寬度範圍內
		for touch_pos in active_touches.values():
			var local_touch = track.to_local(touch_pos)
			var dist_x = abs(local_touch.x - note.position.x)
			
			if dist_x <= (note.hit_width / 2.0) + 60.0:
				if local_touch.y >= -800.0 and local_touch.y <= 250.0:
					is_finger_still_on_it = true
					break
					
		var current_time = game_time
		var t_diff_tail = note.tail_time - current_time
		
		# 狀況 A：玩家手指離開了！
		# 狀況 A：玩家手指離開了！
		if not is_finger_still_on_it:
			# ★ 核心修正：移除 > 0.0 的限制
			# 只要距離尾巴小於 60ms（包含尾巴已經過線的負數時間）
			# 且因為程式走到這代表 grace_timer 還沒破 0.15s，就該直接給予成功！
			if t_diff_tail <= 0.060:
				spawn_hit_effect(note, Color(1.0, 1.0, 1.0, 0.8))
				note.hit_tail()
				current_combo += 1
				_show_feedback("PERFECT")
			else:
				var grace_time = note.get_meta("grace_timer") if note.has_meta("grace_timer") else 0.0
				grace_time += get_process_delta_time() # 累加玩家鬆開螢幕的時間
				
				if grace_time > 0.150: 
					note.break_hold()
				else:
					note.set_meta("grace_timer", grace_time)
				
		# 狀況 B：玩家手指還在上面
		else:
			if note.has_meta("grace_timer"):
				note.set_meta("grace_timer", 0.0)
				
			if t_diff_tail <= 0.0:
				spawn_hit_effect(note, Color(1.0, 1.0, 1.0, 0.8)) 
				note.hit_tail()
				current_combo += 1
				_show_feedback("PERFECT")


func _show_feedback(judge_text: String):
	if current_combo > max_combo:
		max_combo = current_combo
		
	# ==========================================
	# ★ 優先更新統計表！這樣我們才能立刻知道現在是不是 All Perfect
	judge_stats[judge_text] += 1
	# ==========================================
	
	# 1. 安全清除舊動畫
	if tween_combo and tween_combo.is_valid():
		tween_combo.kill()
	if tween_judge and tween_judge.is_valid():
		tween_judge.kill()
		

	# ★ 2. 動態決定 Combo 的顏色 (AP金 / FC綠 / 斷連白)
	if judge_stats["MISS"] == 0 and judge_stats["GOOD"] == 0:
		combo_label.modulate = Color(1.0, 0.8, 0.2, 1.0) # 金色 (目前是 All Perfect)
	elif judge_stats["MISS"] == 0:
		combo_label.modulate = Color(0.2, 1.0, 0.2, 1.0) # 綠色 (有 Good，但維持 Full Combo)
	else:
		combo_label.modulate = Color(1.0, 1.0, 1.0, 1.0) # 白色 (斷過了)
	
	# 刷新 Combo 動畫
	combo_label.text = "COMBO " + str(current_combo)
	combo_label.scale = Vector2(1.1, 1.1)
	tween_combo = create_tween()
	tween_combo.tween_property(combo_label, "scale", Vector2.ONE, 0.1)
	
	# 3. 顯示動態判定文字
	judgement_label.text = judge_text
	judgement_label.scale = Vector2(1.5, 1.5)
	
	if judge_text == "PERFECT":
		judgement_label.modulate = Color(1.0, 1.0, 1.0, 1.0) 
	elif judge_text == "GOOD":
		judgement_label.modulate = Color(0.2, 1.0, 0.2, 1.0)
	else:
		judgement_label.modulate = Color(1.0, 0.2, 0.2, 1.0)
		
	tween_judge = create_tween().set_parallel(true)
	tween_judge.tween_property(judgement_label, "scale", Vector2.ONE, 0.15)
	tween_judge.chain().tween_property(judgement_label, "modulate:a", 0.0, 0.1).set_delay(0.1)
	
	# 4. 更新底部的統計表 UI
	stats_label.text = "%d/%d/%d" % [
		judge_stats["PERFECT"], 
		judge_stats["GOOD"], 
		judge_stats["MISS"]
	]
	
	var total_notes_judged = judge_stats["PERFECT"] + judge_stats["GOOD"] + judge_stats["MISS"]
	if total_notes_judged == total_expected_judgments and total_expected_judgments > 0:
		if judge_stats["MISS"] == 0 and judge_stats["GOOD"] == 0:
			# 達成 ALL PERFECT 時，先開啟無敵狀態鎖定結算
			is_ap_animating = true 
			_play_ap_animation()

func _init_blur_material():
	var shader = Shader.new()
	shader.code = """
	shader_type canvas_item;
	
	void fragment() {
		// 取得 ColorRect 傳進來的顏色 (包含 hit_color)
		vec4 base_color = COLOR;
		
		// ==========================================
		// 1. X 軸的平滑邊緣 (模擬高斯模糊)
		// ==========================================
		// UV.x 範圍 0.0 ~ 1.0，0.5 是中心點。
		// dist_x 算出來後，中心點是 0.0，最外緣是 1.0
		float dist_x = abs(UV.x - 0.5) * 2.0; 
		
		// smoothstep(0.5, 1.0) 代表：內部 50% 是純色，外部的 50% 進行平滑羽化淡出
		float alpha_x = 1.0 - smoothstep(0.8, 1.0, dist_x);
		
		// ==========================================
		// 2. Y 軸的弱漸淡
		// ==========================================
		// UV.y 範圍 0.0(頂部) ~ 1.0(底部)
		// smoothstep(0.0, 0.7) 代表：底部 30% 保持實心，往上慢慢變淡
		float alpha_y = smoothstep(0.0, 0.7, UV.y);
		float fade_out_bottom = 1.0 - smoothstep(0.98, 1.0, UV.y);
		alpha_y = max(alpha_y, 0.10); 
		
		// 合併透明度計算
		base_color.a *= (alpha_x * alpha_y);
		COLOR = base_color;
	}
	"""
	
	blur_effect_material = ShaderMaterial.new()
	blur_effect_material.shader = shader
	
func spawn_hit_effect(note: Node2D, hit_color: Color):
	# 假設 0 = 原版 (TextureRect), 1 = 新版收縮版 (Line2D)
	var effect_style = Global.get("hit_effect_style")
	if effect_style == null: effect_style = 1 # 防呆預設
	
	var effect_height = 350.0 * Global.effect_height_ratio
	
	if !effect_style:
		# ==========================================
		# [模式 0] 舊版 TextureRect 實作
		# ==========================================
		var effect = TextureRect.new()
		effect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		var grad_tex = GradientTexture2D.new()
		grad_tex.fill_from = Vector2(0, 1)
		grad_tex.fill_to = Vector2(0, 0)
		
		var grad = Gradient.new()
		grad.set_color(0, hit_color) 
		grad.set_color(1, Color(hit_color.r, hit_color.g, hit_color.b, 0.0)) 
		grad_tex.gradient = grad
		effect.texture = grad_tex
		
		effect.size = Vector2(note.hit_width, effect_height)
		effect.position = Vector2(note.position.x - (note.hit_width / 2.0), -effect_height + 10.0)
		
		note.get_parent().add_child(effect)
		
		var t = create_tween().set_parallel(true)
		t.tween_property(effect, "position:y", effect.position.y - 30.0, 0.2)
		t.tween_property(effect, "modulate:a", 0.0, 0.2)
		t.chain().tween_callback(effect.queue_free)
		
	else:
		var effect = ColorRect.new()
		effect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		# 1. 略寬一點 (比音符判定範圍多出 30 像素，讓邊緣羽化有空間發揮)
		var wider_width = note.hit_width + 50.0
		effect.size = Vector2(wider_width, effect_height)
		
		# 2. 定位 (X 軸需要扣掉加寬的一半來維持中心對齊)
		effect.position = Vector2(note.position.x - (wider_width / 2.0), -effect_height + 25.0)
		
		# 3. 套用 Shader 與顏色
		effect.material = blur_effect_material
		effect.color = hit_color # 直接給予顏色，Shader 的 COLOR 會自動接收
		
		note.get_parent().add_child(effect)
		
		# 4. 動畫 (與你原本的邏輯相同，往上飄並整體淡出)
		var t = create_tween().set_parallel(true)
		t.tween_property(effect, "position:y", effect.position.y - 30.0, 0.2)
		t.tween_property(effect, "modulate:a", 0.0, 0.2)
		t.chain().tween_callback(effect.queue_free)
	
func reset_combo_from_miss():
	current_combo = 0
	_show_feedback("MISS")

# ==========================================
# ★ 暫停系統
# ==========================================

func _on_pause_button_pressed():
	if get_tree().paused:
		get_tree().paused = false
		audio_player.stream_paused = false
		pause_menu.visible = false
		pause_button.text = "||" 
	else:
		get_tree().paused = true
		audio_player.stream_paused = true
		pause_menu.visible = true
		pause_button.text = "▶" 

func _on_restart_button_pressed():
	Transition.reload_scene()

func _on_quit_button_pressed():
	#back to Song Select
	Transition.change_scene("uid://dcrdq7tlb21h")

func _play_ap_animation():
	# 1. 初始化狀態
	ap_overlay.visible = true
	ap_overlay.modulate.a = 1.0
	ap_dim_bg.modulate.a = 0.0 
	ap_label.modulate.a = 0.0
	ap_label.scale = Vector2(1.5, 1.5) 
	ap_top_line.scale.x = 0.0
	ap_bottom_line.scale.x = 0.0
	
	# ★ 確保粒子一開始處於重置狀態
	ap_particles.emitting = false

	# 2. 開始建立連續動畫
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS) 
	
	# [階段 1] 整個畫面稍微暗一點
	tween.tween_property(ap_dim_bg, "modulate:a", 0.6, 0.2)
	
	# [階段 2] 上下兩條線從中間快速向外展開
	tween.parallel().tween_property(ap_top_line, "scale:x", 1.0, 0.10).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(ap_bottom_line, "scale:x", 1.0, 0.10).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_callback(func(): ap_particles.emitting = true)
	# [階段 3] 字體閃出並伴隨打擊感的縮放
	tween.chain().tween_property(ap_label, "modulate:a", 1.0, 0.1)
	tween.parallel().tween_property(ap_label, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# ★ 核心加入：在字體縮放「砸」到畫面上的同一瞬間，用 tween_callback 觸發粒子爆發！
	
	
	# [階段 4] 短暫延遲停留
	tween.tween_interval(2.0)
	
	# [階段 5] 漸出並回到正常亮度
	tween.tween_property(ap_overlay, "modulate:a", 0.0, 0.3)
	
	# [階段 6] 動畫結束，處理後續流程
	tween.tween_callback(func():
		ap_overlay.visible = false
		is_ap_animating = false
		
		if not audio_player.playing:
			_show_result_screen()
	)
# ==========================================
# ★ 結算畫面核心邏輯
# ==========================================
func _show_result_screen():
	get_tree().paused = true
	pause_button.visible = false
	track_bottom.visible = false
	track_left.visible = false
	track_right.visible = false
	combo_label.visible = false
	judgement_label.visible = false
	stats_label.visible = false
	downrect.visible = false
	song_label.visible = false
	
	var total_notes_judged = judge_stats["PERFECT"] + judge_stats["GOOD"] + judge_stats["MISS"]
	var final_score = 0
	var rank = "F"
	var rank_color = "#FFFFFF" 
	
	var song_id = Global.current_song_data.get("id", Global.current_song_data.get("title", "unknown_song"))
	var diff_type = Global.current_chart_path.get_file().get_basename()
	if result_diff_line != null:
		var diff_color = _get_diff_color(diff_type)
		result_diff_line.color = diff_color
	# ==========================================
	# ★ AUTO 模式結算攔截：顯示 AUTO 且不儲存分數
	# ==========================================
	if Global.auto_play:
		final_score = 0
		rank = "AUTO"
		rank_color = "#00FFFF" # 青藍色專屬標籤
		result_details_label.text = "AUTO PLAY\n\nPERFECT: %d\nGOOD: 0\nMISS: 0" %total_notes_judged
	else:
		# 正常遊玩模式計分與存檔
		if total_notes_judged > 0:
			var raw_score = (judge_stats["PERFECT"] * 1.0 + judge_stats["GOOD"] * 0.65) / total_notes_judged
			final_score = int(raw_score * 1000000)
			
		if Global.has_method("save_new_score"):
			Global.save_new_score(song_id, diff_type, final_score)
			
		if final_score >= 1000000:
			rank = "Ω"
			rank_color = "#4DFFFF"
		elif final_score >= 990000:
			rank = "Ψ"
			rank_color = "#FFFF37" 
		elif final_score >= 980000:
			rank = "Χ"
			rank_color = "#FF0000" 
		elif final_score >= 960000:
			rank = "A"
			rank_color = "#FFDC35"
		elif final_score >= 900000:
			rank = "B"
			rank_color = "#73BF00"
		elif final_score >= 800000:
			rank = "C"
			rank_color = "#0066CC"
		elif final_score >= 700000:
			rank = "D"
			rank_color = "#8B4513"
		elif final_score >= 600000:
			rank = "E"
			rank_color = "#A9A9A9"
		else:
			rank = "F"
			rank_color = "#000000"
		
		result_details_label.text = "MAX COMBO: %d\n\nPERFECT: %d\nGOOD: %d\nMISS: %d" % [
			max_combo,
			judge_stats["PERFECT"],
			judge_stats["GOOD"],
			judge_stats["MISS"]
		]
		
		if judge_stats["MISS"] == 0 and total_notes_judged > 0:
			if judge_stats["GOOD"] == 0:
				result_details_label.text = "ALL PERFECT\n\nMAX COMBO: %d\n\nPERFECT: %d\nGOOD: %d\nMISS: %d" % [
					max_combo,
					judge_stats["PERFECT"],
					judge_stats["GOOD"],
					judge_stats["MISS"]
				]
			else:
				result_details_label.text = "FULL COMBO\n\nMAX COMBO: %d\n\nPERFECT: %d\nGOOD: %d\nMISS: %d" % [
					max_combo,
					judge_stats["PERFECT"],
					judge_stats["GOOD"],
					judge_stats["MISS"]
				]
				
		
	# ==========================================

	result_song_label.text = Global.current_song_data["title"]
	result_score_label.text = "[left]SCORE: %07d\nRANK : [color=%s]%s[/color][/left]" % [final_score, rank_color, rank]
	
	result_menu.modulate.a = 0.0 
	result_menu.scale = Vector2(0.8, 0.8) 
	result_menu.pivot_offset = result_menu.size / 2.0 
	result_menu.process_mode = Node.PROCESS_MODE_ALWAYS 
	result_menu.visible = true
	
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS) 
	tween.set_parallel(true) 
	tween.tween_property(result_menu, "modulate:a", 1.0, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(result_menu, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func load_external_audio(path: String) -> AudioStream:
	if path.begins_with("res://"):
		return load(path)
		
	if not FileAccess.file_exists(path):
		print("❌ 找不到音樂檔案：", path)
		return null
		
	var ext = path.get_extension().to_lower()
	
	if ext == "ogg":
		return AudioStreamOggVorbis.load_from_file(path)
	elif ext == "mp3":
		var file = FileAccess.open(path, FileAccess.READ)
		if file:
			var buffer = file.get_buffer(file.get_length())
			var mp3_stream = AudioStreamMP3.new()
			mp3_stream.data = buffer
			return mp3_stream
			
	print("❌ 不支援的音樂格式：", ext)
	return null

func load_external_image(path: String) -> Texture2D:
	if path == null or path == "":
		return null
		
	if path.begins_with("res://"):
		return load(path)
		
	if FileAccess.file_exists(path):
		var img = Image.load_from_file(path)
		if img != null:
			return ImageTexture.create_from_image(img)
			
	print("找不到圖片檔案或讀取失敗：", path)
	return null

func _get_diff_color(diff_raw: String) -> Color:
	var upper_diff = diff_raw.to_upper() # 防呆：強制轉大寫比對
	if "NORMAL" in upper_diff: return Color(0, 0.55, 0.65)
	elif "HARD" in upper_diff: return Color(0.95, 0.2, 0.25) 
	elif "MEGA" in upper_diff: return Color(0.6, 0.2, 0.8)
	elif "GIGA" in upper_diff: return Color(0.4, 0.4, 0.4)
	elif "CASUAL" in upper_diff: return Color(0, 0.8, 0.5)
	elif "TERA" in upper_diff: return Color(0, 0, 0)
	
	# 如果都沒配對到，給一個預設的灰色
	return Color(0.5, 0.5, 0.5)

# ==========================================
# ★ 單曲專屬校準系統
# ==========================================
func _on_offset_minus_pressed():
	var current_offset = Global.current_song_data.get("song_offset", 0.0)
	var new_offset = current_offset - 0.01 # 每次減少 10 毫秒
	
	# 更新當前記憶體
	Global.current_song_data["song_offset"] = new_offset
	
	# 觸發 Global 實體存檔
	var song_id = Global.current_song_data.get("id", Global.current_song_data.get("title", "unknown_song"))
	Global.save_song_offset(song_id, new_offset)
	
	_update_offset_label()

func _on_offset_plus_pressed():
	var current_offset = Global.current_song_data.get("song_offset", 0.0)
	var new_offset = current_offset + 0.01 # 每次增加 10 毫秒
	
	# 更新當前記憶體
	Global.current_song_data["song_offset"] = new_offset
	
	# 觸發 Global 實體存檔
	var song_id = Global.current_song_data.get("id", Global.current_song_data.get("title", "unknown_song"))
	Global.save_song_offset(song_id, new_offset)
	
	_update_offset_label()

func _update_offset_label():
	if offset_label:
		var current_offset = Global.current_song_data.get("song_offset", 0.0)
		# 顯示到小數點後 3 位 (毫秒)
		offset_label.text = "Offset\n%+.2fs" % current_offset
