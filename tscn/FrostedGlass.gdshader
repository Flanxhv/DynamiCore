shader_type canvas_item;

// 呼叫 Godot 4 的螢幕紋理來做模糊
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;

// --- 在編輯器右側可以隨時調整的參數 ---
uniform float blur_amount : hint_range(0.0, 5.0) = 1.5; // 霧面模糊程度
uniform vec4 tint_color : source_color = vec4(0.1, 0.1, 0.1, 0.2); // 霧面區的底色 (例如半透明深灰)

uniform float split_x : hint_range(0.0, 1.0) = 0.65; // 分界線的 X 軸中心點 (0.5 = 畫面正中央)
uniform float slant : hint_range(-1.0, 1.0) = -0.1; // 斜率 (正數為左上到右下，負數為右上到左下)

uniform float line_thickness : hint_range(0.0, 0.05) = 0.004; // 分界線的粗細
uniform vec4 line_color : source_color = vec4(0.4, 0.8, 1.0, 0.5); // 分界線的顏色 (例如你的淺藍色)


void fragment() {
    // 根據 Y 軸座標與斜率，計算出目前的切割臨界點
    float threshold = split_x + (UV.y - 0.5) * slant;

    if (UV.x < threshold - line_thickness) {
        // 【左側區域】獲取背景畫面並進行模糊 (霧面感)
        vec4 blurred_bg = texture(screen_tex, SCREEN_UV, blur_amount);
        // 將模糊後的背景與我們設定的底色(tint_color)做混和
        COLOR = mix(blurred_bg, tint_color, tint_color.a);
        
    } else if (UV.x < threshold + line_thickness) {
        // 【分隔線】畫出那條斜線
        COLOR = line_color;
        
    } else {
        // 【右側區域】完全透明，露出原本的背景與特效
        COLOR = vec4(0.0);
    }
}