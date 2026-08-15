extends Control

# ==========================================
# ★ 1. 場景預載 (UI 實體化)
# ==========================================
# 請確保你有建立這個場景，稍後我們會用它來生成歌曲按鈕
const SongListItemScene = preload("res://tscn/SongListItem.tscn")

# ==========================================
# ★ 2. 節點參考 (依畫面區塊分類)
# ==========================================
@onready var toast_label = $ToastLabel
@onready var bg_a = $BgCover/BgCoverA
@onready var bg_b = $BgCover/BgCoverB
@onready var brightness_mask = $BgCover/ColorRect
var bg_showing_a: bool = true
# --- 列表與捲動區 ---
@onready var scroll_container = $ScrollContainer
@onready var song_vbox = $ScrollContainer/VBoxContainer
# --- 下拉篩選選單 ---
@onready var filter_menu_btn = $FilterMenuBtn
@onready var filter_panel = $FilterPanel
@onready var rank_toggle_btn = $FilterPanel/VBoxContainer/RankToggleBtn
@onready var love_toggle_btn = $FilterPanel/VBoxContainer/LoveToggleBtn
@onready var sort_toggle_btn = $FilterPanel/VBoxContainer/SortToggleBtn
@onready var search_box = $SearchBox

var current_search_query: String = ""
var is_filter_open: bool = false
var is_filtering: bool = false
var filter_panel_base_y: float = 0.0
@onready var bg_image = $BgCover
# --- 右側資訊板塊 (選定模式) ---
# --- 左下角資訊區 ---
@onready var bottom_info_container = $BottomInfoContainer
@onready var title_label = $BottomInfoContainer/MarqueeContainer/TitleLabel
@onready var artist_label = $BottomInfoContainer/ArtistLabel
@onready var charter_label = $BottomInfoContainer/CharterLabel

@onready var preview_player = $PreviewPlayer
# --- 右側操作面板 (選定模式) ---
@onready var song_info_panel = $SongInfoPanel
@onready var btn_auto = $SongInfoPanel/GridContainer/DiamondButton1
@onready var btn_love = $SongInfoPanel/GridContainer/DiamondButton2
@onready var btn_mirror = $SongInfoPanel/GridContainer/DiamondButton3
@onready var btn_play = $SongInfoPanel/GridContainer/DiamondButton4
@onready var difficulty_triangle = $SongInfoPanel/DifficultyTriangle
# --- 左側返回觸控區 ---
@onready var left_touch_area = $LeftTouchArea
# --- 左側清單漸層遮罩 ---
@onready var list_bg_mask = $ListBgMask

@onready var delete_btn = $FilterPanel/VBoxContainer/DeleteBtn

# --- 刪除確認視窗 (請依據你實際的節點路徑調整) ---
@onready var custom_dialog = $CustomConfirmDialog
@onready var dialog_message = $CustomConfirmDialog/DialogBox/MessageLabel
@onready var confirm_btn = $CustomConfirmDialog/DialogBox/ConfirmBtn
@onready var cancel_btn = $CustomConfirmDialog/DialogBox/CancelBtn

@onready var back_btn = $BackButton 
@onready var open_settings_btn = $OpenSettingsBotton

@onready var settings_panel = $SettingsPanel
@onready var settings_blocker = $BlockRect
@onready var close_btn = $SettingsPanel/CloseBotton

#------------settings------------
@onready var speed_slider = $SettingsPanel/SpeedSlider
@onready var speed_label = $SettingsPanel/SpeedLabel
@onready var effect_style_toggle = $SettingsPanel/EffectStyleToggle
@onready var offset_slider = $SettingsPanel/OffsetSlider
@onready var offset_label = $SettingsPanel/OffsetLabel
@onready var brightness_slider = $SettingsPanel/BrightnessSlider
@onready var brightness_label = $SettingsPanel/BrightnessLabel
@onready var effect_slider = $SettingsPanel/EffectSlider
@onready var effect_label = $SettingsPanel/EffectLabel
# ==========================================
# ★ 3. 狀態與全域變數
# ==========================================
var local_songs: Array = []
var current_selected_song: Dictionary = {}
var current_diff_index: int = 0

# 雙模式與吸附狀態
var is_in_selected_mode: bool = false
var is_snapping: bool = false
var scroll_stop_timer: Timer
var auto_expand_timer: Timer

var current_bg_path: String = ""
var _bg_texture_cache: Dictionary = {}

var current_centered_item = null

var filter_rank: String = "ALL" # 可選: "ALL", "RANKED", "UNRANKED"
var filter_love: bool = false   # 可選: false (全部顯示), true (只顯示有 LOVE 的)
var current_playing_audio_path: String = ""
# 排序模式與對應的 UI 文字
var sort_modes = ["DEFAULT_ASC", "DEFAULT_DESC", "TITLE_ASC", "TITLE_DESC", "DIFF_ASC", "DIFF_DESC"]
var sort_labels = ["Default ↓", "Default ↑", "A-Z", "Z-A", "Diffculty ↑", "Diffculty ↓"]
var current_sort_index: int = 0
var current_sort: String = sort_modes[0]
# ==========================================
# ★ 4. 初始化 (_ready)
# ==========================================
func _ready():
	# 1. 初始狀態設定：隱藏資訊板與返回區
	song_info_panel.visible = false
	song_info_panel.modulate.a = 0.0
	left_touch_area.visible = false
	filter_panel_base_y = filter_panel.position.y
	if search_box:
		search_box.text_changed.connect(_on_search_text_changed)
	# 2. 設定「捲動停止」偵測計時器
	scroll_stop_timer = Timer.new()
	scroll_stop_timer.wait_time = 0.3
	scroll_stop_timer.one_shot = true
	scroll_stop_timer.timeout.connect(_on_scroll_stopped)
	add_child(scroll_stop_timer)
	
	# 2. 負責「自動展開」的計時器 (吸附後給予玩家猶豫時間)
	auto_expand_timer = Timer.new()
	auto_expand_timer.wait_time = 0.7
	auto_expand_timer.one_shot = true
	auto_expand_timer.timeout.connect(_on_auto_expand_timeout)
	add_child(auto_expand_timer)
	
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
	# 3. 綁定信號
	var scrollbar = scroll_container.get_v_scroll_bar()
	scrollbar.value_changed.connect(_on_scroll_value_changed)
	left_touch_area.pressed.connect(_return_to_browse_mode)
	
	filter_menu_btn.pressed.connect(_toggle_filter_panel)
	rank_toggle_btn.pressed.connect(_on_filter_rank_pressed)
	love_toggle_btn.pressed.connect(_on_filter_love_pressed)
	sort_toggle_btn.pressed.connect(_on_sort_pressed)
	
	delete_btn.pressed.connect(_on_delete_btn_pressed)
	if confirm_btn and cancel_btn:
		confirm_btn.pressed.connect(_on_confirm_btn_pressed)
		cancel_btn.pressed.connect(_on_cancel_btn_pressed)
		
	# 確保一開始視窗是隱藏的
	if custom_dialog:
		custom_dialog.visible = false
	
	if back_btn:
		pass
		
	# 2. 綁定 SETTINGS 按鈕與面板開關
	if open_settings_btn:
		open_settings_btn.pressed.connect(func(): 
			# 如果當下篩選選單還開著，先強制關閉它，避免干擾
			if is_filter_open:
				_toggle_filter_panel()
				
			settings_panel.visible = true
			settings_blocker.visible = true
			
			# ★ 確保開啟設定時，滑鼠點擊被遮罩完全攔截
			settings_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
			settings_panel.mouse_filter = Control.MOUSE_FILTER_STOP
		)
		
	if close_btn:
		close_btn.pressed.connect(func(): 
			settings_panel.visible = false
			settings_blocker.visible = false
			
			# 關閉時恢復忽略滑鼠，讓背後的東西可以點
			settings_blocker.mouse_filter = Control.MOUSE_FILTER_IGNORE
			settings_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		)
	
	btn_auto.pressed.connect(func():
		Global.auto_play = !Global.auto_play
		btn_auto.update_visual(Global.auto_play)
	)
	
	btn_mirror.pressed.connect(func():
		Global.mirror_mode = !Global.mirror_mode
		btn_mirror.update_visual(Global.mirror_mode)
	)
	
	btn_love.pressed.connect(func():
		var is_loved = current_selected_song.get("loved", false)
		current_selected_song["loved"] = not is_loved
		
		# 存檔邏輯
		var meta_path = current_selected_song.get("folder_path", "") + "meta.json"
		if FileAccess.file_exists(meta_path):
			var file = FileAccess.open(meta_path, FileAccess.WRITE)
			file.store_string(JSON.stringify(current_selected_song))
			file.close()
			
		btn_love.update_visual(current_selected_song["loved"])
	)
	
	btn_play.pressed.connect(func():
		# 1. 停止音樂
		if preview_player.playing:
			preview_player.stop()
			
		# 2. 記錄目前選擇的歌曲資料
		Global.current_song_data = current_selected_song
		
		# 3. 組合出遊戲場景需要的譜面路徑 (移植自舊版的 _update_difficulty_ui)
		var diffs = current_selected_song.get("difficulty", [])
		if diffs.size() > 0:
			var current_diff_raw = diffs[current_diff_index]
			var current_diff_type = current_diff_raw.split(" ")[0] # 取得 "MEGA", "HARD" 等字串
			var folder = current_selected_song.get("folder_path", "")
			Global.current_chart_path = folder + current_diff_type + ".xml"
			
		# 4. 切換場景
		Transition.change_scene("uid://3faac22k1tal")
	)
	
	difficulty_triangle.pressed.connect(_on_difficulty_triangle_pressed)

	_scan_local_songs()
	_restore_last_state()

func _on_back_button_pressed():
	if preview_player.playing:
		preview_player.stop()
	# 切換回主選單場景 (請確認這是你主選單的 UID 或路徑)
	Transition.change_scene("uid://dnda82ibqdnuq")
# ==========================================
# ★ 5. 核心邏輯：生成歌曲清單
# ==========================================
func _update_song_list_ui():
	# 1. 清除舊按鈕
	for child in song_vbox.get_children():
		child.queue_free()
		
	var all_songs = []
	all_songs.append_array(local_songs)
	#all_songs.append_array(Global.song_list)
	
	# ==========================================
	# ★ 核心加回：1. 執行雙重篩選 (Filtering)
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
			
		# 篩選 C：搜尋字串判斷 (如果你有保留搜尋框的話)
		if current_search_query != "":
			var s_title = song.get("title", "").to_lower()
			if not (current_search_query in s_title):
				continue
			
		# 順手把乾淨的布林值寫回 song 字典裡
		song["loved"] = is_loved
		song["ranked"] = is_ranked
		
		# 通過所有篩選的歌曲，加入候選名單
		processed_songs.append(song)
		
	# ==========================================
	# ★ 核心加回：2. 執行排序 (Sorting)
	# ==========================================
	match current_sort:
		"DEFAULT_ASC":
			processed_songs.reverse()
		"DEFAULT_DESC":
			pass
		"TITLE_ASC":
			processed_songs.sort_custom(func(a, b): return a.get("title", "").nocasecmp_to(b.get("title", "")) < 0)
		"TITLE_DESC":
			processed_songs.sort_custom(func(a, b): return a.get("title", "").nocasecmp_to(b.get("title", "")) > 0)
		"DIFF_ASC":
			processed_songs.sort_custom(func(a, b): return _get_max_diff(a) < _get_max_diff(b))
		"DIFF_DESC":
			processed_songs.sort_custom(func(a, b): return _get_max_diff(a) > _get_max_diff(b))

	# ==========================================
	# ★ 3. 實體化 UI (結合新的墊片邏輯)
	# ==========================================
	var half_screen = scroll_container.size.y / 2.0
	var item_half_height = 50.0 
	
	# 產生上方墊片
	var top_spacer = Control.new()
	top_spacer.custom_minimum_size.y = half_screen - item_half_height
	song_vbox.add_child(top_spacer)
	
	# ★ 關鍵修正：這裡改為迭代 processed_songs，而不是 all_songs
	for song in processed_songs:
		var item = SongListItemScene.instantiate()
		item.set_meta("song_data", song)
		song_vbox.add_child(item)
		if item.has_method("setup"):
			item.setup(song)
		if item.has_signal("item_clicked"):
			item.item_clicked.connect(_on_song_item_clicked)
			
	# 產生下方墊片
	var bottom_spacer = Control.new()
	bottom_spacer.custom_minimum_size.y = half_screen - item_half_height
	song_vbox.add_child(bottom_spacer)

# ==========================================
# ★ 自動恢復上次選歌狀態
# ==========================================
func _restore_last_state():
	is_filtering = true # 開啟防護罩，避免捲動引發錯誤
	
	# 1. 刷新並生成按鈕清單
	_update_song_list_ui()
	
	# 2. 等待兩幀，讓 Godot 完成排版並算出每個按鈕的實際 Y 座標
	await get_tree().process_frame
	await get_tree().process_frame
	
	# 3. 尋找上次打的歌是否還在清單裡
	var found_target = null
	
	# 確認 Global 裡有這個變數且不是空的 (避免第一次開遊戲報錯)
	if Global.get("last_selected_song_id") != null and Global.last_selected_song_id != "":
		for child in song_vbox.get_children():
			if child.has_meta("song_data"):
				var song = child.get_meta("song_data")
				if _get_song_id(song) == Global.last_selected_song_id:
					found_target = child
					break
					
	# 4. 判斷並執行恢復
	if found_target:
		# 狀況 A：找到上次的歌，把捲動條精準拉到那首歌的位置
		var center_offset = scroll_container.size.y / 2.0 - 50.0 # (假設按鈕一半高是 50)
		scroll_container.scroll_vertical = found_target.position.y - center_offset
		current_centered_item = found_target
		
		# 等待 0.1 秒讓畫面與滑動引擎穩定，然後「自動幫玩家點進去」！
		await get_tree().create_timer(0.1).timeout
		_enter_selected_mode(found_target.get_meta("song_data"))
	else:
		# 狀況 B：找不到 (或是玩家剛開遊戲第一次進來)，乖乖待在第一首歌
		scroll_container.scroll_vertical = 0
		
	# 解除防護罩
	is_filtering = false
	
func _refresh_and_reset_list():
	is_filtering = true # 開啟防護罩，避免此時觸發自動進入
	
	# 1. 嘗試記錄目前畫面中央的歌曲 ID 或 標題
	var target_song_id = ""
	if current_centered_item and current_centered_item.has_meta("song_data"):
		var song = current_centered_item.get_meta("song_data")
		target_song_id = song.get("id", song.get("title", ""))
		
	# 2. 重新生成清單
	_update_song_list_ui()
	
	# 3. 等待兩幀，讓 Godot 把新的按鈕排版完畢並算出正確座標
	await get_tree().process_frame
	await get_tree().process_frame
	
	# 4. 尋找剛剛那首歌是否還活著
	var found_target = null
	for child in song_vbox.get_children():
		if child.has_meta("song_data"):
			var song = child.get_meta("song_data")
			var current_id = song.get("id", song.get("title", ""))
			if current_id == target_song_id:
				found_target = child
				break
				
	# 5. 決定捲動條的位置
	if found_target:
		# 狀況 A (存活)：精準滾動到它的新位置 (減去一半畫面高度，讓它回到中央)
		var center_offset = scroll_container.size.y / 2.0 - 50.0 # (假設按鈕高度一半是50)
		scroll_container.scroll_vertical = found_target.position.y - center_offset
	else:
		# 狀況 B (被篩掉了)：什麼都不做！
		# 保留原本的 scroll_vertical，Godot 系統自然會去抓取「現在剛好落在這個高度」的新歌曲
		pass
		
	# 等待一小段時間讓滑動事件結算完畢，再關閉防護罩
	await get_tree().create_timer(0.1)
	
	if auto_expand_timer and not auto_expand_timer.is_stopped():
		auto_expand_timer.stop()
	is_filtering = false
	
	
# ==========================================
# ★ 6. 捲動與自動吸附邏輯
# ==========================================
func _on_scroll_value_changed(value: float):
	if is_snapping or is_in_selected_mode or is_filtering:
		return
		
	# 只要手還在滑，就不斷重置吸附計時器，並「打斷」展開計時器
	scroll_stop_timer.start()
	auto_expand_timer.stop() 

func _on_scroll_stopped():
	# 加上 is_filtering 的防護 (我們之前加過的)
	if is_in_selected_mode or song_vbox.get_child_count() == 0 or is_filtering:
		return
		
	# ★ 刪除原本在這裡的 is_snapping = true
	
	var center_y = scroll_container.scroll_vertical + (scroll_container.size.y / 2.0)
	var closest_item = null
	var min_dist = INF
	
	for item in song_vbox.get_children():
		if not item.has_method("set_focus_ratio"): continue
		var item_center_y = item.position.y + (item.size.y / 2.0)
		var dist = abs(item_center_y - center_y)
		if dist < min_dist:
			min_dist = dist
			closest_item = item
			
	if closest_item:
		# ★ 搬到這裡：只有確定找到按鈕、準備要執行吸附動畫時，才鎖定狀態！
		is_snapping = true 
		
		var target_scroll = closest_item.position.y + (closest_item.size.y / 2.0) - (scroll_container.size.y / 2.0)
		target_scroll = clamp(target_scroll, 0, scroll_container.get_v_scroll_bar().max_value)
		
		var tween = create_tween()
		tween.tween_property(scroll_container, "scroll_vertical", target_scroll, 0.15).set_trans(Tween.TRANS_SINE)
		tween.tween_callback(func(): 
			is_snapping = false
			
			if closest_item.get("song_data") != null:
				current_selected_song = closest_item.song_data
				auto_expand_timer.start()
		)

# ★ 新增：當延遲展開計時器時間到，才真正進入選定模式
func _on_auto_expand_timeout():
	if is_filtering: 
		return
	if is_filter_open:
		_toggle_filter_panel()
	if current_selected_song != null and not current_selected_song.is_empty():
		_enter_selected_mode(current_selected_song)

func _process(delta):
	# 如果沒有歌，或已經在選定模式，就不需要浪費效能計算
	if song_vbox.get_child_count() == 0 or is_in_selected_mode:
		return
		
	var center_y = scroll_container.scroll_vertical + (scroll_container.size.y / 2.0)
	var max_dist = 250.0 
	
	# ★ 新增：用來找出目前離中心最近的項目
	var closest_item = null
	var min_dist = INF
	
	for item in song_vbox.get_children():
		if item.has_method("set_focus_ratio"):
			var item_center_y = item.position.y + (item.size.y / 2.0)
			var dist = abs(item_center_y - center_y)
			
			# ★ 紀錄距離最近的項目
			if dist < min_dist:
				min_dist = dist
				closest_item = item
			
			# 計算並套用凸起形狀
			var ratio = clamp(1.0 - (dist / max_dist), 0.0, 1.0)
			ratio = ease(ratio, 0.5) 
			item.set_focus_ratio(ratio)
			
	# ==========================================
	# ★ 滑動音效觸發邏輯
	# ==========================================
	# 如果目前最靠近中心的項目，跟上一次紀錄的不同，就代表「切換到下一首歌了」
	if closest_item != null and closest_item != current_centered_item:
		# 避免第一次載入畫面時也發出聲音
		if current_centered_item != null:
			_play_scroll_sound()
			
		# 更新紀錄
		current_centered_item = closest_item
	
	if closest_item.has_meta("song_data"):
		_update_bg_cover(closest_item.get_meta("song_data"))
func _play_scroll_sound():
	# 方案 A：如果你原本就有 UiSoundManager，可以直接呼叫 (例如用 hover 音效代替)
		UiSoundManager.play_hover()

# ==========================================
# ★ 7. 模式切換邏輯 (瀏覽 <-> 選定)
# ==========================================
func _on_song_item_clicked(song_data: Dictionary, item_node):
	# 點擊直接進入選定模式
	_enter_selected_mode(song_data)
	
func _enter_selected_mode(song_data: Dictionary):
	if is_in_selected_mode: return
	is_in_selected_mode = true
	
	# --- 難度記憶邏輯 ---
	var target_song_id = _get_song_id(song_data)
	if Global.last_selected_song_id == target_song_id:
		current_diff_index = Global.last_selected_diff_index 
	else:
		current_diff_index = 0 
		Global.last_selected_diff_index = 0
	Global.last_selected_song_id = target_song_id
	
	current_selected_song = song_data
	_refresh_difficulty_display() 
	
	# --- UI 更新與動畫 ---
	title_label.play_marquee(song_data.get("title", "Unknown Title"))
	artist_label.text = song_data.get("artist", "Unknown")
	charter_label.text = "\nCharter: " + song_data.get("charter", "Unknown")
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(scroll_container, "modulate:a", 0.0, 0.3)
	tween.tween_property(list_bg_mask, "modulate:a", 0.0, 0.3)
	tween.tween_property(filter_menu_btn, "modulate:a", 0.0, 0.3)
	
	if back_btn:
		tween.tween_property(back_btn, "modulate:a", 0.0, 0.3)
		tween.chain().tween_callback(func(): back_btn.visible = false)
	
	if search_box:
		tween.tween_property(search_box, "modulate:a", 0.0, 0.3)
		tween.chain().tween_callback(func(): search_box.visible = false)
		
	if is_filter_open:
		is_filter_open = false
		filter_panel.visible = false
		filter_panel.modulate.a = 0.0
	
	if filter_menu_btn:
		filter_menu_btn.visible = false
		
	song_info_panel.visible = true
	tween.tween_property(song_info_panel, "modulate:a", 1.0, 0.3)
	
	bottom_info_container.visible = true
	tween.tween_property(bottom_info_container, "modulate:a", 1.0, 0.3)
	
	left_touch_area.visible = true
	
	btn_auto.update_visual(Global.auto_play)
	btn_mirror.update_visual(Global.mirror_mode)
	btn_play.update_visual(true)
	btn_love.update_visual(song_data.get("loved", false))
	
	if open_settings_btn:
		open_settings_btn.visible = true
		# 為了避免跟 chain() 衝突，我們另外開一個並行的 tween 動畫
		var settings_tween = create_tween()
		settings_tween.tween_property(open_settings_btn, "modulate:a", 1.0, 0.3)
	# ==========================================
	# ★ 終極無縫播放邏輯
	# ==========================================
	var audio_to_play = song_data.get("preview_path", "")
	if audio_to_play == "":
		audio_to_play = song_data.get("audio_path", "")
		
	if audio_to_play != "":
		# 如果這首歌跟現在正在播的「路徑不同」，才重新讀取
		if audio_to_play != current_playing_audio_path:
			var stream = load_external_audio(audio_to_play)
			if stream:
				preview_player.stream = stream
				preview_player.play()
				current_playing_audio_path = audio_to_play # 更新紀錄
		else:
			# 如果路徑一模一樣！代表是同一首歌，千萬別重載
			# 只要防呆檢查它如果剛好停了，再幫它按播放就好
			if not preview_player.playing:
				preview_player.play()

	# --- 替換背景圖片並淡入 ---
	_update_bg_cover(song_data)
	
func _return_to_browse_mode():
	if not is_in_selected_mode: return
	is_in_selected_mode = false
	left_touch_area.visible = false
	
	var tween = create_tween().set_parallel(true)
	
	# 淡出右側操作面板
	tween.tween_property(song_info_panel, "modulate:a", 0.0, 0.15)
	tween.chain().tween_callback(func(): song_info_panel.visible = false)
	
	# ★ 淡出左下角資訊區
	tween.tween_property(bottom_info_container, "modulate:a", 0.0, 0.15)
	tween.chain().tween_callback(func(): bottom_info_container.visible = false)
	if open_settings_btn:
		tween.tween_property(open_settings_btn, "modulate:a", 0.0, 0.15)
		tween.chain().tween_callback(func(): open_settings_btn.visible = false)
	# 重新淡入左側歌曲清單
	tween.tween_property(scroll_container, "modulate:a", 1.0, 0.3)
	tween.tween_property(list_bg_mask, "modulate:a", 1.0, 0.3)
	tween.tween_property(filter_menu_btn, "modulate:a", 1.0, 0.3)
	if back_btn:
		back_btn.visible = true
		var back_tween = create_tween()
		back_tween.tween_property(back_btn, "modulate:a", 1.0, 0.3)
	
	if search_box:
		search_box.visible = true
		var search_tween = create_tween()
		search_tween.tween_property(search_box, "modulate:a", 1.0, 0.3)
		
	if filter_menu_btn:
		filter_menu_btn.visible=true
		
func _on_difficulty_triangle_pressed():
	if current_selected_song.is_empty() or not current_selected_song.has("difficulty"):
		return
		
	var diffs = current_selected_song["difficulty"]
	# 切換到下一個難度索引
	current_diff_index = (current_diff_index + 1) % diffs.size()
	Global.last_selected_diff_index = current_diff_index
	
	_refresh_difficulty_display()

func _refresh_difficulty_display():
	var diff_raw = current_selected_song["difficulty"][current_diff_index]
	var parts = diff_raw.split(" ") # 例如 "MEGA 15" 分成 "MEGA" 和 "15"
	var d_name = parts[0] if parts.size() > 0 else "???"
	var d_num = parts[1] if parts.size() > 1 else "0"
	
	# 根據難度名稱給予顏色
	var target_color = Color(0.4, 0.4, 0.4)
	if "NORMAL" in d_name: target_color = Color(0, 0.55, 0.65)
	elif "HARD" in d_name: target_color = Color(0.95, 0.2, 0.25)
	elif "MEGA" in d_name: target_color = Color(0.6, 0.2, 0.8)
	elif "GIGA" in d_name: target_color = Color(0.4, 0.4, 0.4)
	elif "CASUAL" in d_name: target_color = Color(0, 0.8, 0.5)
	elif "TERA" in d_name: target_color = Color(0, 0, 0)
	# 呼叫三角形內部的動畫更新函式
	difficulty_triangle.update_difficulty(d_name, d_num, target_color)
# ==========================================
# ★ 8. 其他底層功能 (原封不動貼回來)
# ==========================================
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
		
func _get_song_id(song: Dictionary) -> String:
	return song.get("id", song.get("title", "unknown_song"))

func load_external_audio(path: String) -> AudioStream:
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

func _toggle_filter_panel():
	is_filter_open = !is_filter_open
	var tween = create_tween()
	
	if is_filter_open:
		filter_panel.visible = true
		filter_panel.modulate.a = 0.0
		# ★ 永遠從「標準位置往上 20 像素」的地方開始掉落
		filter_panel.position.y = filter_panel_base_y - 20
		
		tween.parallel().tween_property(filter_panel, "modulate:a", 1.0, 0.2)
		# ★ 永遠回到「標準位置」
		tween.parallel().tween_property(filter_panel, "position:y", filter_panel_base_y, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		tween.parallel().tween_property(filter_panel, "modulate:a", 0.0, 0.2)
		# ★ 永遠往上縮到「標準位置往上 20 像素」
		tween.parallel().tween_property(filter_panel, "position:y", filter_panel_base_y - 20, 0.2)
		tween.tween_callback(func(): filter_panel.visible = false)
		
func _on_filter_rank_pressed():
	if filter_rank == "ALL":
		filter_rank = "RANKED"
		rank_toggle_btn.text = "Rank: RANKED"
	elif filter_rank == "RANKED":
		filter_rank = "UNRANKED"
		rank_toggle_btn.text = "Rank: UNRANKED"
	else:
		filter_rank = "ALL"
		rank_toggle_btn.text = "Rank: ALL"
		
	_refresh_and_reset_list()

func _on_filter_love_pressed():
	filter_love = not filter_love
	if filter_love:
		love_toggle_btn.text = "Love: ONLY ♥"
		love_toggle_btn.modulate = Color(1.0, 0.3, 0.5) 
	else:
		love_toggle_btn.text = "Love: ALL ♡"
		love_toggle_btn.modulate = Color.WHITE
		
	_refresh_and_reset_list()

func _on_sort_pressed():
	current_sort_index = (current_sort_index + 1) % sort_modes.size()
	current_sort = sort_modes[current_sort_index]
	sort_toggle_btn.text = "Sort: " + sort_labels[current_sort_index]
	
	_refresh_and_reset_list()

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
	_refresh_and_reset_list() # 重新執行篩選與生成 UI

#-------------DELETE------------
# ==========================================
# ★ 刪除歌曲邏輯 (從舊版移植並優化)
# ==========================================
func show_toast(msg: String):
	toast_label.text = msg
	toast_label.visible = true
	toast_label.modulate.a = 1.0 # 瞬間顯示
	
	# 建立動畫來控制淡出
	var tween = create_tween()
	tween.tween_interval(1.5) # 停留 1.5 秒
	tween.tween_property(toast_label, "modulate:a", 0.0, 0.5) # 花 0.5 秒透明度變 0
	tween.tween_callback(func(): toast_label.visible = false) # 完全透明後關閉顯示
	
func _on_delete_btn_pressed():
	# 1. 貼心設計：點擊後自動收合下拉選單
	if is_filter_open:
		_toggle_filter_panel()
		
	# 2. 檢查是否有選中的歌曲 (在滑動模式下，current_selected_song 會跟著吸附更新)
	if current_selected_song.is_empty():
		print("❌ 請先選擇一首歌曲")
		return
		
	var folder_path = current_selected_song.get("folder_path", "")
	
	# 3. 防呆：阻擋刪除內建歌曲
	if folder_path.begins_with("res://"):
		show_toast("the base song cannot be deleted！") # 如果你有 toast 可以改用 show_toast()
		return
		
	if folder_path == "":
		show_toast("files not found.")
		return
		
	# 4. 更新標籤文字並顯示自製視窗
	var song_title = current_selected_song.get("title", "Unknown")
	dialog_message.text = "Delete %s?" % song_title
	custom_dialog.visible = true

func _on_cancel_btn_pressed():
	custom_dialog.visible = false

func _on_confirm_btn_pressed():
	custom_dialog.visible = false
	
	var folder_path = current_selected_song.get("folder_path", "")
	if folder_path == "" or not DirAccess.dir_exists_absolute(folder_path):
		return
		
	print("🗑️ 正在刪除歌曲資料夾: ", folder_path)
	
	# 執行遞迴刪除
	var result = _delete_folder_recursive(folder_path)
	
	if result == OK:
		print("✅ 歌曲刪除成功")
		
		# 停止音樂
		if preview_player.playing:
			preview_player.stop()
			
		current_playing_audio_path = ""
		current_selected_song = {}
		
		# 重新掃描本地檔案，並呼叫我們寫好的安全刷新機制！
		_scan_local_songs()
		_refresh_and_reset_list()
	else:
		print("❌ 刪除失敗，錯誤碼: ", result)

# 遞迴刪除資料夾實用工具
func _delete_folder_recursive(path: String) -> int:
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name != "." and file_name != "..":
				var full_path = path + file_name
				if dir.current_is_dir():
					_delete_folder_recursive(full_path + "/")
				else:
					DirAccess.remove_absolute(full_path)
			file_name = dir.get_next()
		dir.list_dir_end()
		return DirAccess.remove_absolute(path)
	return ERR_CANT_OPEN
#-------------DELETE------------



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


func _update_bg_cover(song_data: Dictionary):
	var cover_path = song_data.get("cover_path", "")
	if cover_path == "" or cover_path == current_bg_path:
		return
	current_bg_path = cover_path
	
	var tex = _load_or_get_cached_texture(cover_path)
	if tex == null:
		return
	
	var front = bg_a if bg_showing_a else bg_b
	var back = bg_b if bg_showing_a else bg_a
	
	back.texture = tex
	back.modulate.a = 0.0
	
	# ★ 移除 z_index 的用法，改成把 back 移到 BgCover 底下最後面，
	#    這樣「畫在最上面」只會影響 bg_a / bg_b 彼此，不會蓋到別的 UI
	back.get_parent().move_child(back, back.get_parent().get_child_count() - 1)
	brightness_mask.get_parent().move_child(brightness_mask, brightness_mask.get_parent().get_child_count() - 1)
	var tween = create_tween()
	tween.tween_property(back, "modulate:a", 1.0, 0.4)
	
	bg_showing_a = not bg_showing_a

func _load_or_get_cached_texture(path: String) -> Texture2D:
	var tex: Texture2D = _bg_texture_cache.get(path, null)
	if tex != null:
		return tex
		
	if path.begins_with("res://"):
		tex = load(path)
	else:
		var img = Image.load_from_file(path)
		if img != null:
			tex = ImageTexture.create_from_image(img)
			
	if tex != null:
		_bg_texture_cache[path] = tex
		
	return tex
