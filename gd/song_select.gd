extends Control

@onready var song_vbox = $ScrollContainer/VBoxContainer
@onready var difficulty_box = $DifficultyBox
@onready var bg_cover = $BgCover
@onready var toast_label = $ToastLabel
@onready var settings_panel = $SettingsPanel
@onready var open_settings_btn = $OpenSettingsBotton
@onready var close_btn = $SettingsPanel/CloseBotton
@onready var delete_btn = $DeleteButton
@onready var custom_dialog = $CustomConfirmDialog
@onready var dialog_message = $CustomConfirmDialog/DialogBox/MessageLabel
@onready var confirm_btn = $CustomConfirmDialog/DialogBox/ConfirmBtn
@onready var cancel_btn = $CustomConfirmDialog/DialogBox/CancelBtn
@onready var speed_slider = $SettingsPanel/SpeedSlider
@onready var speed_label = $SettingsPanel/SpeedLabel
@onready var effect_style_toggle = $SettingsPanel/EffectStyleToggle
@onready var offset_slider = $SettingsPanel/OffsetSlider
@onready var offset_label = $SettingsPanel/OffsetLabel
@onready var brightness_slider = $SettingsPanel/BrightnessSlider
@onready var brightness_label = $SettingsPanel/BrightnessLabel
@onready var effect_slider = $SettingsPanel/EffectSlider
@onready var effect_label = $SettingsPanel/EffectLabel
@onready var high_score_label = $HighScoreLabel
@onready var settings_blocker = $BlockRect
@onready var search_box = $SearchBox

@onready var preview_player = $PreviewPlayer 

var local_songs: Array = []
var current_selected_song: Dictionary = {}
var current_diff_index: int = 0 
var current_search_query: String = ""

# ★ 新增：菱形選單的參考變數
var diamond_menu: Control
var btn_auto: Button
var btn_mirror: Button
var btn_love: Button
var btn_play: Button

# ==========================================
# ★ 篩選與排序狀態變數
# ==========================================
var filter_rank: String = "ALL" # 可選: "ALL", "RANKED", "UNRANKED"
var filter_love: bool = false   # 可選: false (全部顯示), true (只顯示有 LOVE 的)

# 排序模式與對應的 UI 文字
var sort_modes = ["DEFAULT_ASC", "DEFAULT_DESC", "TITLE_ASC", "TITLE_DESC", "DIFF_ASC", "DIFF_DESC"]
var sort_labels = ["Default ↓", "Default ↑", "A-Z", "Z-A", "Diffculty ↑", "Diffculty ↓"]
var current_sort_index: int = 0
var current_sort: String = sort_modes[0]

# UI 按鈕參考
var btn_filter_rank: Button
var btn_filter_love: Button
var btn_sort: Button

func _ready():
	UiSoundManager.bind_buttons(self)
	BgmManager.fade_out_and_stop(1.0)
	await get_tree().create_timer(0.1).timeout

	for child in difficulty_box.get_children():
		child.queue_free()
		
	# ★ 呼叫生成菱形選單
	_create_filter_sort_ui()
	_create_diamond_menu()
	
	move_child(settings_blocker, -1)
	move_child(settings_panel, -1)
	move_child(custom_dialog, -1)
	
	_scan_local_songs()
	_update_song_list_ui()
	
	if search_box:
		search_box.text_changed.connect(_on_search_text_changed)
		
	open_settings_btn.pressed.connect(func(): 
		settings_panel.visible = true
		settings_blocker.visible = true
	)
	
	close_btn.pressed.connect(func(): 
		settings_panel.visible = false
		settings_blocker.visible = false
	)
	
	delete_btn.pressed.connect(_on_delete_btn_pressed)
	confirm_btn.pressed.connect(_on_confirm_btn_pressed)
	cancel_btn.pressed.connect(_on_cancel_btn_pressed)
	# 給自製按鈕加上音效 (如果有使用 UiSoundManager)
	UiSoundManager.bind_buttons(custom_dialog)
	
	# ★ 新增：當使用者在彈出視窗點擊「確定 (OK)」時觸發
	
	speed_slider.value = Global.note_speed_mult
	offset_slider.value = Global.device_offset
	brightness_slider.value = Global.bg_brightness
	effect_slider.value = Global.effect_height_ratio
	if effect_style_toggle:
		effect_style_toggle.button_pressed = Global.hit_effect_style
		# 連接 Toggled 信號
		effect_style_toggle.toggled.connect(_on_effect_style_toggled)
	_update_setting_labels()
	
	speed_slider.value_changed.connect(_on_speed_changed)
	offset_slider.value_changed.connect(_on_offset_changed)
	brightness_slider.value_changed.connect(_on_brightness_changed)
	effect_slider.value_changed.connect(_on_effect_changed)
	
	var scrollbar = $ScrollContainer.get_v_scroll_bar()
	# 強制設定寬度為 50 像素 (原本預設極細，可依需求調整到 60 或 80)
	# ==========================================
	# ★ 優化：加寬滾動條，並防止它覆蓋到歌曲按鈕
	# ==========================================
	scrollbar.custom_minimum_size.x = 50 
	
	var sb_style = StyleBoxFlat.new()
	sb_style.bg_color = Color(1.0, 1.0, 1.0, 0.4) # 半透明白色
	sb_style.corner_radius_top_left = 10
	sb_style.corner_radius_top_right = 10
	sb_style.corner_radius_bottom_left = 10
	sb_style.corner_radius_bottom_right = 10
	
	scrollbar.add_theme_stylebox_override("grabber", sb_style)
	scrollbar.add_theme_stylebox_override("grabber_highlight", sb_style)
	scrollbar.add_theme_stylebox_override("grabber_pressed", sb_style)
	
	
	_restore_last_selection()

func _create_diamond_menu():
	diamond_menu = Control.new()
	diamond_menu.position = Vector2(1500, 500) 
	diamond_menu.visible = false 
	add_child(diamond_menu)
	
	var grid = GridContainer.new()
	grid.columns = 2
	# ★ 放大 1：按鈕間距調大一點點
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	
	# ★ 放大 2：按鈕變成 150x150，加上間距 10，總寬高為 310。一半就是 155
	grid.position = Vector2(-155, -155) 
	grid.pivot_offset = Vector2(155, 155)
	grid.rotation = PI / 4 
	diamond_menu.add_child(grid)
	
	# ★ 透明底色修正：在生成按鈕時，就直接傳入它們的「專屬主題色」
	btn_auto = _create_diamond_btn("AUTO", Color(0.2, 0.6, 1.0))
	btn_love = _create_diamond_btn("LOVE", Color(1.0, 0.3, 0.5))
	btn_mirror = _create_diamond_btn("MIRROR", Color(0.8, 0.4, 1.0))
	btn_play = _create_diamond_btn("PLAY", Color(0.2, 0.8, 0.3))
	
	grid.add_child(btn_auto)
	grid.add_child(btn_love)
	grid.add_child(btn_mirror)
	grid.add_child(btn_play)
	
	btn_auto.pressed.connect(func():
		Global.auto_play = !Global.auto_play
		_update_diamond_btn_visual(btn_auto, Global.auto_play, Color(0.2, 0.6, 1.0))
	)
	
	btn_mirror.pressed.connect(func():
		Global.mirror_mode = !Global.mirror_mode
		_update_diamond_btn_visual(btn_mirror, Global.mirror_mode, Color(0.8, 0.4, 1.0))
	)
	
	btn_love.pressed.connect(_toggle_love)
	
	btn_play.pressed.connect(func():
		if preview_player.playing:
			preview_player.stop()
		Global.current_song_data = current_selected_song
		Transition.change_scene("uid://3faac22k1tal")
	)
	
	# PLAY 按鈕給予常駐的高亮綠色
	_update_diamond_btn_visual(btn_play, true, Color(0.2, 0.8, 0.3))

# ★ 新增 theme_color 參數
func _create_diamond_btn(text: String, theme_color: Color) -> Button:
	var btn = Button.new()
	btn.pressed.connect(UiSoundManager.play_click)
	btn.mouse_entered.connect(UiSoundManager.play_hover)
	# ★ 放大 3：按鈕尺寸改為 150x150
	btn.custom_minimum_size = Vector2(150, 150)
	
	# 初始化時就使用專屬顏色 (預設為未啟動 false)
	_update_diamond_btn_visual(btn, false, theme_color) 
	
	var lbl = Label.new()
	lbl.text = text
	# ★ 放大 4：文字標籤尺寸同步改為 150x150
	lbl.size = Vector2(150, 150)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# ★ 放大 5：旋轉中心點改為 150 的一半 (75, 75)
	lbl.pivot_offset = Vector2(75, 75)
	lbl.rotation = -PI / 4 
	
	# ★ 放大 6：字體可以稍微調大一點
	lbl.add_theme_font_size_override("font_size", 32)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.add_theme_constant_override("outline_size", 4)
	
	btn.add_child(lbl)
	return btn

func _update_diamond_btn_visual(btn: Button, is_active: bool, active_color: Color):
	var style = StyleBoxFlat.new()
	
	# ==========================================
	# ★ 透明底色魔法：計算出同一顏色的「半透明版本」
	# ==========================================
	var inactive_color = active_color
	inactive_color.a = 0.25 # 設定透明度為 25% (數值範圍 0.0 ~ 1.0，覺得太暗或太亮可以調這個)
	
	# 如果啟動就用實心色，未啟動就用半透明色
	style.bg_color = active_color if is_active else inactive_color
	
	# 可以讓未啟動的邊框也變暗一點，更有層次感
	style.border_color = Color.WHITE if is_active else Color(0.6, 0.6, 0.6, 0.8)
	style.set_border_width_all(3)
	
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)
	btn.add_theme_stylebox_override("focus", style)

func _toggle_love():
	var is_loved = current_selected_song.get("loved", false)
	current_selected_song["loved"] = not is_loved
	
	# 同步寫回 meta.json 永久保存
	var meta_path = current_selected_song.get("folder_path", "") + "meta.json"
	if FileAccess.file_exists(meta_path):
		var file = FileAccess.open(meta_path, FileAccess.WRITE)
		file.store_string(JSON.stringify(current_selected_song))
		file.close()
		
	# 更新愛心按鈕視覺 (粉紅色)
	_update_diamond_btn_visual(btn_love, current_selected_song["loved"], Color(1.0, 0.3, 0.5))

# ==========================================

func _update_song_list_ui():
	# 清除舊按鈕
	for child in song_vbox.get_children():
		child.queue_free()
		
	var all_songs = []
	all_songs.append_array(Global.song_list)
	all_songs.append_array(local_songs)
	
	# ==========================================
	# ★ 1. 執行雙重篩選 (Filtering)
	# ==========================================
	var processed_songs = []
	for song in all_songs:
		
		# --- 安全轉換 LOVED 狀態 ---
		var raw_loved = song.get("loved", false)
		var is_loved = false
		if typeof(raw_loved) == TYPE_BOOL:
			is_loved = raw_loved
		elif typeof(raw_loved) == TYPE_STRING:
			is_loved = (raw_loved.strip_edges().to_lower() == "true")
		elif typeof(raw_loved) in [TYPE_INT, TYPE_FLOAT]:
			is_loved = (raw_loved > 0)
			
		# --- 安全轉換 RANKED 狀態 ---
		var raw_ranked = song.get("ranked", false)
		var is_ranked = false
		if typeof(raw_ranked) == TYPE_BOOL:
			is_ranked = raw_ranked
		elif typeof(raw_ranked) == TYPE_STRING:
			is_ranked = (raw_ranked.strip_edges().to_lower() == "true")
		elif typeof(raw_ranked) in [TYPE_INT, TYPE_FLOAT]:
			is_ranked = (raw_ranked > 0)


		# 篩選 A：LOVE 獨立判斷
		if filter_love and not is_loved:
			continue
			
		# 篩選 B：RANK 狀態判斷 ("ALL", "RANKED", "UNRANKED")
		if filter_rank == "RANKED" and not is_ranked:
			continue
		if filter_rank == "UNRANKED" and is_ranked:
			continue
		if current_search_query != "":
			var s_title = song.get("title", "").to_lower()
			var s_artist = song.get("artist", "").to_lower()
			var s_charter = song.get("charter", "").to_lower()
			
			# 如果搜尋字串不在標題、作者或譜師名字裡，就跳過這首歌
			if not (current_search_query in s_title):
				continue
			
		# ★ 順手把乾淨的布林值寫回 song 字典裡，方便下方生成按鈕文字時使用
		song["loved"] = is_loved
		song["ranked"] = is_ranked
		
		# 通過所有篩選的歌曲，加入候選名單
		processed_songs.append(song)
		
	# ==========================================
	# ★ 2. 執行排序 (Sorting)
	# ==========================================
	match current_sort:
		"DEFAULT_ASC":
			processed_songs.reverse() # 維持載入時的順序
		"DEFAULT_DESC":
			pass
		"TITLE_ASC":
			# nocasecmp_to 比較字串時忽略大小寫，回傳 < 0 代表 a 在 b 前面
			processed_songs.sort_custom(func(a, b): return a.get("title", "").nocasecmp_to(b.get("title", "")) < 0)
		"TITLE_DESC":
			processed_songs.sort_custom(func(a, b): return a.get("title", "").nocasecmp_to(b.get("title", "")) > 0)
		"DIFF_ASC":
			processed_songs.sort_custom(func(a, b): return _get_max_diff(a) < _get_max_diff(b))
		"DIFF_DESC":
			processed_songs.sort_custom(func(a, b): return _get_max_diff(a) > _get_max_diff(b))

	# ==========================================
	# ★ 3. 實體化 UI 按鈕
	# ==========================================
	for song in processed_songs:
		var margin_wrapper = MarginContainer.new()
		margin_wrapper.add_theme_constant_override("margin_right", 65) 
		margin_wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var btn = Button.new()
		btn.set_meta("song_data", song)
		# ★ 修正：前面加上 6 個空白字元，把文字往右推，避免跟色條重疊
		btn.text = "      " + song.get("title", "Unknown Title") 
			
		btn.custom_minimum_size = Vector2(0, 100) 
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 40)
		
		# ==========================================
		# ★ 核心修正：設定靠左對齊與過長裁切
		# ==========================================
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		
		# ==========================================
		# ★ 繪製左側的縱向窄條 (RANKED 與 LOVE)
		# ==========================================
		var current_bar_x = 0 
		
		if song.get("ranked", false):
			var ranked_bar = ColorRect.new()
			ranked_bar.color = Color(1.0, 0.84, 0.0) 
			ranked_bar.set_anchors_preset(Control.PRESET_LEFT_WIDE) 
			ranked_bar.offset_left = current_bar_x
			ranked_bar.offset_right = current_bar_x + 10 
			ranked_bar.offset_top = 0
			ranked_bar.offset_bottom = 0
			ranked_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE 
			btn.add_child(ranked_bar)
			
			current_bar_x += 16 
			
		if song.get("loved", false):
			var love_bar = ColorRect.new()
			love_bar.color = Color(1.0, 0.15, 0.5) 
			love_bar.set_anchors_preset(Control.PRESET_LEFT_WIDE)
			love_bar.offset_left = current_bar_x
			love_bar.offset_right = current_bar_x + 10 
			love_bar.offset_top = 0
			love_bar.offset_bottom = 0
			love_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
			btn.add_child(love_bar)
			
		btn.pressed.connect(_on_song_button_pressed.bind(song, btn))
		
		margin_wrapper.add_child(btn)
		song_vbox.add_child(margin_wrapper)

func _update_setting_labels():
	speed_label.text = "%.2fx" % Global.note_speed_mult
	offset_label.text = "%d ms" % int(Global.device_offset * 1000)
	brightness_label.text = "%d%%" % int(Global.bg_brightness * 100)
	effect_label.text = "%.1fx" % Global.effect_height_ratio
	
func _on_speed_changed(value: float):
	Global.note_speed_mult = value
	_update_setting_labels()
	Global.save_settings()

func _on_offset_changed(value: float):
	# ... (維持原樣) ...
	Global.device_offset = value
	_update_setting_labels()
	Global.save_settings()

func _on_brightness_changed(value: float):
	# ... (維持原樣) ...
	Global.bg_brightness = value
	_update_setting_labels()
	Global.save_settings()

func _on_effect_changed(value: float):
	# ... (維持原樣) ...
	Global.effect_height_ratio = value
	_update_setting_labels()
	Global.save_settings()
func _on_effect_style_toggled(toggled_on: bool):
	Global.hit_effect_style = toggled_on
	Global.save_settings()
	if Global.has_method("play_click"):
		UiSoundManager.play_click()
		
func _on_song_button_pressed(song_data: Dictionary, clicked_btn: Button):
	if current_selected_song == song_data:
		return
		
	current_selected_song = song_data
	var target_song_id = _get_song_id(song_data)
	
	if Global.last_selected_song_id == target_song_id:
		# 如果是還原同一首歌，讀取上次的難度
		current_diff_index = Global.last_selected_diff_index
	else:
		# 如果是點擊不同的新歌，難度歸零，並更新 Global 紀錄
		current_diff_index = 0
		Global.last_selected_diff_index = 0
		
	# 記錄這首歌為「最後選中的歌」
	Global.last_selected_song_id = target_song_id
	
	# ★ 顯示菱形選單，並更新開關狀態
	diamond_menu.visible = true
	_update_diamond_btn_visual(btn_auto, Global.auto_play, Color(0.2, 0.6, 1.0))
	_update_diamond_btn_visual(btn_mirror, Global.mirror_mode, Color(0.8, 0.4, 1.0))
	_update_diamond_btn_visual(btn_love, song_data.get("loved", false), Color(1.0, 0.3, 0.5))
	
	# 播放預覽音樂
	var audio_to_play = song_data.get("preview_path", "")
	if audio_to_play == "":
		audio_to_play = song_data.get("audio_path", "")
		
	if audio_to_play != "":
		var stream = load_external_audio(audio_to_play)
		if stream:
			preview_player.stream = stream
			preview_player.play()
	
	# UI 按鈕變色
	for wrapper in song_vbox.get_children():
		if wrapper is MarginContainer:
			var btn = wrapper.get_child(0) # 從包裝盒裡取出真正的按鈕
			if btn is Button:
				var t_reset = create_tween()
				t_reset.tween_property(btn, "custom_minimum_size:y", 100, 0.2)
				btn.modulate = Color(1.0, 1.0, 1.0, 1.0)
	
	var t_focus = create_tween()
	t_focus.tween_property(clicked_btn, "custom_minimum_size:y", 130, 0.2)
	clicked_btn.modulate = Color(0.6, 0.9, 1.2, 1.0)
	
	# 替換背景圖片
	var tex: Texture2D = null
	if song_data.has("cover_path") and song_data["cover_path"] != "":
		if song_data["cover_path"].begins_with("res://"):
			tex = load(song_data["cover_path"])
		else:
			var img = Image.load_from_file(song_data["cover_path"])
			if img != null: tex = ImageTexture.create_from_image(img)
				
	if tex != null:
		bg_cover.texture = tex
		var tween = create_tween()
		tween.tween_property(bg_cover, "modulate:a", 1.0, 0.3)
		
	_update_difficulty_ui(song_data)

func _update_difficulty_ui(song_data: Dictionary):
	# ... (維持原樣) ...
	for child in difficulty_box.get_children():
		child.queue_free()
		
	if not song_data.has("difficulty") or song_data["difficulty"].is_empty():
		high_score_label.text = "" 
		return
		
	var diffs = song_data["difficulty"]
	
	var current_diff_raw = diffs[current_diff_index]
	var current_diff_type = current_diff_raw.split(" ")[0]
	Global.current_chart_path = song_data.get("folder_path", "") + current_diff_type + ".xml"
	
	var song_id = song_data.get("id", song_data.get("title", "unknown_song"))
	var high_score = 0
	
	if Global.player_scores.has(song_id) and Global.player_scores[song_id].has(current_diff_type):
		high_score = Global.player_scores[song_id][current_diff_type]

	high_score_label.text = "%07d" % high_score
	
	var overlap_container = Control.new()
	overlap_container.custom_minimum_size = Vector2(350,120) 
	difficulty_box.add_child(overlap_container)
	
	if diffs.size() > 1:
		var next_idx = (current_diff_index + 1) % diffs.size()
		var back_btn = _create_single_diff_btn(diffs[next_idx])
		
		back_btn.position = Vector2(50, -50) 
		back_btn.modulate.a = 1.0
		back_btn.disabled = true 
		
		overlap_container.add_child(back_btn)
		
	var front_btn = _create_single_diff_btn(current_diff_raw)
	front_btn.position = Vector2(0, 0)
	front_btn.modulate.a = 1.0
	
	front_btn.pressed.connect(func():
		current_diff_index = (current_diff_index + 1) % diffs.size()
		Global.last_selected_diff_index = current_diff_index
		_update_difficulty_ui(song_data)
	)
	
	overlap_container.add_child(front_btn)

func _create_single_diff_btn(diff_raw: String) -> Button:
	# ... (維持原樣) ...
	var btn = Button.new()
	btn.text = diff_raw
	btn.custom_minimum_size = Vector2(300, 100)
	
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_outline_color", Color.BLACK)
	btn.add_theme_constant_override("outline_size", 6)
	btn.add_theme_font_size_override("font_size", 28)
	
	var bg_color = Color(0.4, 0.4, 0.4)
	if "NORMAL" in diff_raw: bg_color = Color(0, 0.55, 0.65)
	elif "HARD" in diff_raw: bg_color = Color(0.95, 0.2, 0.25) 
	elif "MEGA" in diff_raw: bg_color = Color(0.6, 0.2, 0.8)
	elif "GIGA" in diff_raw: bg_color = Color(0.4, 0.4, 0.4)
	elif "CASUAL" in diff_raw: bg_color = Color(0, 0.8, 0.5)
	elif "TERA" in diff_raw: bg_color = Color(0, 0, 0)
		
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = Color.WHITE
	style.set_border_width_all(2)
	style.corner_radius_top_left = 8
	style.corner_radius_bottom_right = 8
	
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)
	btn.add_theme_stylebox_override("focus", style)
	
	return btn

func _on_back_button_pressed():
	if preview_player.playing:
		preview_player.stop()
	Transition.change_scene("uid://dnda82ibqdnuq")

func _scan_local_songs():
	# ... (維持原樣) ...
	local_songs.clear()
	var songs_dir = "user://songs/"
	
	if not DirAccess.dir_exists_absolute(songs_dir):
		DirAccess.make_dir_recursive_absolute(songs_dir)
		return
		
	var dir = DirAccess.open(songs_dir)
	if dir:
		dir.list_dir_begin()
		var folder_name = dir.get_next()
		
		while folder_name != "":
			if dir.current_is_dir() and folder_name != "." and folder_name != "..":
				var folder_path = songs_dir + folder_name + "/"
				var meta_path = folder_path + "meta.json"
				
				if FileAccess.file_exists(meta_path):
					var file = FileAccess.open(meta_path, FileAccess.READ)
					var data = JSON.parse_string(file.get_as_text())
					
					if data != null:
						data["folder_path"] = folder_path
						var inner_dir = DirAccess.open(folder_path)
						if inner_dir:
							inner_dir.list_dir_begin()
							var file_name = inner_dir.get_next()
							while file_name != "":
								if not inner_dir.current_is_dir():
									var ext = file_name.get_extension().to_lower()
									
									if (ext == "ogg" or ext == "mp3"):
										if file_name.begins_with("preview"):
											data["preview_path"] = folder_path + file_name
										else:
											data["audio_path"] = folder_path + file_name
											
									elif ext in ["png", "jpg", "jpeg"]:
										data["cover_path"] = folder_path + file_name
								file_name = inner_dir.get_next()
							inner_dir.list_dir_end()
							
						local_songs.append(data)
						
			folder_name = dir.get_next()
		dir.list_dir_end()

func load_external_audio(path: String) -> AudioStream:
	# ... (維持原樣) ...
	if path.begins_with("res://"):
		return load(path)
		
	if not FileAccess.file_exists(path):
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
	return null


func _create_filter_sort_ui():
	var top_bar = HBoxContainer.new()
	# ★ 注意：這裡的座標與大小請依照你實際的畫面配置微調
	# 假設你的 ScrollContainer 在左側，我們可以把它放在 ScrollContainer 的正上方
	top_bar.position = Vector2(500, 950) 
	top_bar.size = Vector2(800, 70) 
	top_bar.add_theme_constant_override("separation", 20) # 按鈕之間的間距
	add_child(top_bar)
	
	# 1. RANK 篩選按鈕
	btn_filter_rank = Button.new()
	btn_filter_rank.pressed.connect(UiSoundManager.play_click)
	btn_filter_rank.mouse_entered.connect(UiSoundManager.play_hover)
	btn_filter_rank.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_filter_rank.text = "ALL"
	btn_filter_rank.add_theme_font_size_override("font_size", 30)
	btn_filter_rank.pressed.connect(_on_filter_rank_pressed)
	top_bar.add_child(btn_filter_rank)
	
	# 2. LOVE 篩選按鈕
	btn_filter_love = Button.new()
	btn_filter_love.pressed.connect(UiSoundManager.play_click)
	btn_filter_love.mouse_entered.connect(UiSoundManager.play_hover)
	btn_filter_love.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_filter_love.text = "♡"
	btn_filter_love.add_theme_font_size_override("font_size", 30)
	btn_filter_love.pressed.connect(_on_filter_love_pressed)
	top_bar.add_child(btn_filter_love)
	
	# 3. 排序切換按鈕
	btn_sort = Button.new()
	btn_sort.pressed.connect(UiSoundManager.play_click)
	btn_sort.mouse_entered.connect(UiSoundManager.play_hover)
	btn_sort.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_sort.text = sort_labels[current_sort_index]
	btn_sort.add_theme_font_size_override("font_size", 30)
	btn_sort.pressed.connect(_on_sort_pressed)
	top_bar.add_child(btn_sort)

# --- 按鈕點擊事件 ---

func _on_filter_rank_pressed():
	# 循環切換狀態：ALL -> RANKED -> UNRANKED -> ALL...
	if filter_rank == "ALL":
		filter_rank = "RANKED"
		btn_filter_rank.text = "RANKED"
	elif filter_rank == "RANKED":
		filter_rank = "UNRANKED"
		btn_filter_rank.text = "UNRANKED"
	else:
		filter_rank = "ALL"
		btn_filter_rank.text = "ALL"
		
	_update_song_list_ui() # 刷新清單

func _on_filter_love_pressed():
	filter_love = not filter_love
	if filter_love:
		btn_filter_love.text = "♥"
		btn_filter_love.modulate = Color(1.0, 0.3, 0.5) # 變成粉紅色
	else:
		btn_filter_love.text = "♡"
		btn_filter_love.modulate = Color(1.0, 1.0, 1.0) # 恢復白色
		
	_update_song_list_ui() # 刷新清單

func _on_sort_pressed():
	# 索引加 1，如果超過陣列長度就回到 0 (循環)
	current_sort_index = (current_sort_index + 1) % sort_modes.size()
	current_sort = sort_modes[current_sort_index]
	btn_sort.text = sort_labels[current_sort_index]
	
	_update_song_list_ui() # 刷新清單

func _get_max_diff(song: Dictionary) -> int:
	var max_val = 0
	if song.has("difficulty"):
		for d in song["difficulty"]:
			var parts = d.split(" ") # 依照空格切開，例如 ["MEGA", "13"]
			if parts.size() > 1 and parts[1].is_valid_int():
				var val = parts[1].to_int()
				if val > max_val:
					max_val = val
	return max_val
	
func _on_search_text_changed(query: String):
	current_search_query = query.strip_edges().to_lower()
	_update_song_list_ui() # 重新執行篩選與生成 UI

func _on_delete_btn_pressed():
	if current_selected_song.is_empty():
		print("❌ 請先選擇一首歌曲")
		return
		
	var folder_path = current_selected_song.get("folder_path", "")
	
	# ★ 新增防呆：如果是 res:// 開頭的內建歌曲，直接阻擋並跳出提示
	if folder_path.begins_with("res://"):
		show_toast("the base song cannot be deleted！")
		return
		
	if folder_path == "":
		print("❌ 找不到資料夾路徑")
		return
		
	# 更新標籤文字並顯示自製視窗
	var song_title = current_selected_song.get("title", "Unknown")
	dialog_message.text = "Delete %s?" % song_title
	custom_dialog.visible = true
		
	# 動態組合提示文字，例如：Delete 樂曲名?
	var delete_title = current_selected_song.get("title", "Unknown")
	dialog_message.text = "Delete %s?" % delete_title
	
	# 彈出中央確認視窗
	custom_dialog.visible = true


func _on_cancel_btn_pressed():
	custom_dialog.visible = false


# ★ 當點擊自製視窗的「確定刪除」時
func _on_confirm_btn_pressed():
	# 1. 先把視窗關掉
	custom_dialog.visible = false
	
	var folder_path = current_selected_song.get("folder_path", "")
	if folder_path == "" or not DirAccess.dir_exists_absolute(folder_path):
		print("❌ 找不到該歌曲的資料夾路徑")
		return
		
	print("🗑️ 正在刪除歌曲資料夾: ", folder_path)
	
	# 執行之前寫好的遞迴刪除
	var result = _delete_folder_recursive(folder_path)
	
	if result == OK:
		print("✅ 歌曲刪除成功")
		
		# 復原未選取狀態
		current_selected_song = {}
		diamond_menu.visible = false 
		
		if preview_player.playing:
			preview_player.stop() 
		
		if bg_cover:
			bg_cover.texture = null
			bg_cover.modulate.a = 0.0 
			
		_update_difficulty_ui({}) 
		
		# 重新掃描並更新清單
		_scan_local_songs()
		_update_song_list_ui()
	else:
		print("❌ 刪除失敗，錯誤碼: ", result)

# (記得保留之前寫好的 _delete_folder_recursive 函數)
		
# ★ 新增：遞迴刪除資料夾與內含所有檔案的實用工具
func _delete_folder_recursive(path: String) -> int:
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name != "." and file_name != "..":
				var full_path = path + file_name
				if dir.current_is_dir():
					# 如果是子資料夾，繼續進去刪除
					_delete_folder_recursive(full_path + "/")
				else:
					# 如果是檔案，直接移除
					DirAccess.remove_absolute(full_path)
			file_name = dir.get_next()
		dir.list_dir_end()
		
		# 清空內部後，刪除這個資料夾本體
		return DirAccess.remove_absolute(path)
	return ERR_CANT_OPEN

func _restore_last_selection():
	var target_id = Global.last_selected_song_id
	if target_id == "":
		return # 如果沒有紀錄，什麼都不做
		
	# 遍歷清單，尋找符合紀錄的按鈕
	for wrapper in song_vbox.get_children():
		if wrapper is MarginContainer:
			var btn = wrapper.get_child(0)
			if btn is Button and btn.has_meta("song_data"):
				var song = btn.get_meta("song_data")
				if _get_song_id(song) == target_id:
					# 找到了！模擬玩家點擊這顆按鈕
					_on_song_button_pressed(song, btn)
					
					# 等待一小段時間讓 UI 排版完成，然後自動將捲動條對齊到該歌曲
					await get_tree().process_frame
					var scroll = $ScrollContainer
					# 計算按鈕的位置，使其盡量置中
					scroll.scroll_vertical = wrapper.position.y - (scroll.size.y / 2.0) + (wrapper.size.y / 2.0)
					return
					
func _get_song_id(song: Dictionary) -> String:
	return song.get("id", song.get("title", "unknown_song"))

func show_toast(msg: String):
	toast_label.text = msg
	toast_label.visible = true
	toast_label.modulate.a = 1.0 # 瞬間顯示
	
	# 建立動畫來控制淡出
	var tween = create_tween()
	tween.tween_interval(1.5) # 停留 1.5 秒
	tween.tween_property(toast_label, "modulate:a", 0.0, 0.5) # 花 0.5 秒透明度變 0
	tween.tween_callback(func(): toast_label.visible = false) # 完全透明後關閉顯示
