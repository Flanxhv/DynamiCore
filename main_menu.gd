extends Control

func _ready() :
	BgmManager.play_bgm()
	UiSoundManager.bind_buttons(self)
	
func _on_play_button_pressed():
	# 切換到選曲頁面
	Transition.change_scene("res://SongSelect.tscn")

func _on_chart_button_pressed():
	Transition.change_scene("res://ChartDownload.tscn")

func _on_quit_button_pressed():
	# 關閉遊戲
	get_tree().quit()
