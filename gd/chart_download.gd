extends Control

@onready var list_container = $ScrollContainer/ListContainer
@onready var cloud_downloader = $CloudDownloader
@onready var back_button = $BackButton
@onready var search_box = $SearchBox
@onready var search_timer: Timer = Timer.new()
var _pending_search_query: String = ""
#download card
var card_scene = preload("uid://dap52n7jsrtn5")
var all_cloud_songs: Array = []

# ★ 效能救星：設定畫面最多只生成 50 張卡片
const MAX_DISPLAY = 100

func _ready():
	BgmManager.play_bgm()
	UiSoundManager.bind_buttons(self)
	
	# 綁定返回按鈕
	back_button.pressed.connect(func():
		Transition.change_scene("uid://dnda82ibqdnuq")
	)
	
	if search_box:
		search_box.text_changed.connect(_on_search_text_changed)
	search_timer.one_shot = true
	search_timer.wait_time = 0.3  # 延遲 300 毫秒（通常 0.25 ~ 0.4 秒手感最佳）
	search_timer.timeout.connect(_execute_search)
	add_child(search_timer)
	# 綁定網路請求
	cloud_downloader.request_completed.connect(_on_list_downloaded)
	
	# 向你的 JSON 網址發送請求
	var url = "https://pub-19d1e53d80d84a4498c2b40adbfe578b.r2.dev/songs_list.json"
	cloud_downloader.request(url)
	
func _on_search_text_changed(query: String = "") -> void:
	_pending_search_query = query
	search_timer.start() # 每次打字都會重設倒數時間

# 2. 停止打字 0.3 秒後，才真正執行篩選與載入
func _execute_search() -> void:
	var query = _pending_search_query
	
	# 先把原本畫面上的所有卡片清空
	for child in list_container.get_children():
		child.queue_free()
		
	var filtered_songs: Array = []
	var query_lower = query.strip_edges().to_lower()
	
	# 篩選邏輯
	if query_lower == "":
		filtered_songs = all_cloud_songs.duplicate()
	else:
		for song in all_cloud_songs:
			var s_title = song.get("title", "").to_lower()
			var s_artist = song.get("artist", "").to_lower()
			var s_charter = song.get("charter", "").to_lower()
			
			if query_lower in s_title or query_lower in s_artist or query_lower in s_charter:
				filtered_songs.append(song)
				
	var display_songs = []
	if filtered_songs.size() > MAX_DISPLAY:
		display_songs = filtered_songs.slice(0, MAX_DISPLAY)
	else:
		display_songs = filtered_songs
		
	# 用精簡過的名單生成卡片
	_generate_card_grid(display_songs)
	
func _on_list_downloaded(result, response_code, headers, body):
	if response_code == 200:
		var json_string = body.get_string_from_utf8()
		var parsed_data = JSON.parse_string(json_string)
		
		if parsed_data != null:
			all_cloud_songs = parsed_data
			# ★ 第一次載入時，直接呼叫搜尋函式 (這樣就會自動套用 50 首的限制)
			var initial_query = search_box.text if search_box else ""
			_on_search_text_changed(initial_query)
		else:
			Toast.show_toast("Load failed: songs_list.json")
	else:
		Toast.show_toast("Request failed. Error code: "+response_code)
		
func _generate_card_grid(songs: Array):
	var current_vbox: VBoxContainer = null
	
	for i in range(songs.size()):
		# 每遇到偶數 (0, 2, 4...)，就新建一個「垂直盒子 (VBox)」當作新的一列
		if i % 2 == 0:
			current_vbox = VBoxContainer.new()
			# 設定上下兩張卡片的垂直間距
			current_vbox.add_theme_constant_override("separation", 20)
			# 將這一列加入到橫向滾動的容器中
			list_container.add_child(current_vbox)
			
		# 實例化一張新卡片
		var new_card = card_scene.instantiate()
		current_vbox.add_child(new_card)
		
		# 把歌曲資料塞進去！
		new_card.setup(songs[i])
