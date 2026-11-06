extends Button

@onready var bg_poly = $BgPoly
@onready var swipe_poly = $SwipePoly
@onready var name_label = $NameLabel
@onready var num_label = $NumLabel

var current_color: Color = Color.DARK_GRAY

func _ready():
	swipe_poly.visible = false
	
	# ★ 新增：強制設定縮放中心點為「右下角」，這是放大不會跑位的絕對關鍵！
	pivot_offset = size 
	
	# ★ 自動讓底層背景三角形貼合按鈕的實際大小
	var p_bl = Vector2(0, size.y)          # 左下角
	var p_br = Vector2(size.x, size.y)     # 右下角 (直角處)
	var p_tr = Vector2(size.x, 0)          # 右上角
	bg_poly.polygon = PackedVector2Array([p_bl, p_br, p_tr])

# 當主程式點擊難度切換時，呼叫這個函式
func update_difficulty(diff_name: String, diff_num: String, new_color: Color):
	# 1. 動畫前置準備：計算當前大小的三個頂點
	var p_bl = Vector2(0, size.y)
	var p_br = Vector2(size.x, size.y)
	var p_tr = Vector2(size.x, 0)
	
	# 把 Swipe 層設定為「現在的舊顏色」，並覆蓋整個三角形
	swipe_poly.color = current_color
	swipe_poly.polygon = PackedVector2Array([p_bl, p_br, p_tr])
	swipe_poly.visible = true
	
	# 2. 把底層換成「即將出現的新顏色」，並更新文字
	bg_poly.color = new_color
	current_color = new_color
	name_label.text = diff_name
	num_label.text = diff_num
	
	# 3. 執行「刷過」動畫
	var tween = create_tween()
	tween.tween_method(_animate_swipe, 0.0, 1.0, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func(): swipe_poly.visible = false)

# 動態改變舊三角形的頂點，讓它往右下角縮小消失
func _animate_swipe(progress: float):
	var p_br = Vector2(size.x, size.y) # 右下角直角點永遠不動
	
	# 讓左下角的點和右上角的點，隨著進度往右下角收縮
	var p_left = Vector2(0, size.y).lerp(p_br, progress)
	var p_top = Vector2(size.x, 0).lerp(p_br, progress)
	
	swipe_poly.polygon = PackedVector2Array([p_left, p_br, p_top])
