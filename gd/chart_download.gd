extends Control

@onready var list_container = $ScrollContainer/ListContainer
@onready var cloud_downloader = $CloudDownloader
@onready var back_button = $BackButton
@onready var search_box = $SearchBox

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
		
	# 綁定網路請求
	cloud_downloader.request_completed.connect(_on_list_downloaded)
	
	# 向你的 JSON 網址發送請求
	var url = "https://pub-19d1e53d80d84a4498c2b40adbfe578b.r2.dev/cloud_songs.json"
	print("📡 正在獲取雲端譜面列表...")
	cloud_downloader.request(url)
	
func _on_search_text_changed(query: String = ""):
	# 先把原本畫面上的所有卡片清空
	for child in list_container.get_children():
		child.queue_free()
		
	var filtered_songs: Array = []
	var query_lower = query.strip_edges().to_lower()
	
	# 1. 篩選邏輯
	if query_lower == "":
		# 如果搜尋框是空的，就拿全部的歌來準備
		filtered_songs = all_cloud_songs.duplicate()
	else:
		# 如果有打字，就進行過濾
		for song in all_cloud_songs:
			var s_title = song.get("title", "").to_lower()
			var s_artist = song.get("artist", "").to_lower()
			var s_charter = song.get("charter", "").to_lower()
			
			if query_lower in s_title or query_lower in s_artist or query_lower in s_charter :
				filtered_songs.append(song)
				
	# ==========================================
	# ★ 核心魔法：限制生成數量 (無聲無息地拯救效能)
	# ==========================================
	var display_songs = []
	if filtered_songs.size() > MAX_DISPLAY:
		# 如果符合條件的歌超過 50 首，我們只切出前 50 首來顯示
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
			print("JSON 解析失敗")
	else:
		print("網路請求失敗: ", response_code)

# ==========================================
# ★ 縱二橫向卷軸生成器
# ==========================================
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
