extends Control

func _ready() :
	BgmManager.play_bgm()
	UiSoundManager.bind_buttons(self)
	
func _on_play_button_pressed():
	# 切換到選曲頁面
	Transition.change_scene("uid://dcrdq7tlb21h")

func _on_chart_button_pressed():
	# Chart Download
	Transition.change_scene("uid://vo74jk8d8m7r")

func _on_quit_button_pressed():
	# 關閉遊戲
	get_tree().quit()
