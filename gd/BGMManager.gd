extends Node

var bgm_player = AudioStreamPlayer.new()

func _ready():
	# 確保遊戲暫停時，主選單音樂依然能播放
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# ★ 請把這裡換成你的音樂檔案路徑 (推薦使用 .ogg 格式)
	bgm_player.stream = preload("uid://b47ibaujyt07s")
	
	add_child(bgm_player)

# 播放音樂 (具備防呆：如果已經在播，就不會重頭開始)
func play_bgm():
	if not bgm_player.playing:
		bgm_player.volume_db = 0.0 # 確保音量是正常的
		bgm_player.play()

# 瞬間停止音樂
func stop_bgm():
	if bgm_player.playing:
		bgm_player.stop()

func fade_out_and_stop(duration: float = 0.5):
	if bgm_player.playing:
		var tween = create_tween()
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.tween_property(bgm_player, "volume_db", -40.0, duration)
		tween.chain().tween_callback(bgm_player.stop)
