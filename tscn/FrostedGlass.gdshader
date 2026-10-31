shader_type canvas_item;

// 分割線在螢幕水平比例 (0.0 ~ 1.0)
uniform float split_x : hint_range(0.0, 1.0) = 0.65;
// 傾斜率（-0.15）
uniform float slant : hint_range(-1.0, 1.0) = 0.10;

uniform float drop_shadow_width_px : hint_range(5.0, 80.0) = 35.0; // 投影向右延伸的寬度（像素）
uniform float drop_shadow_opacity : hint_range(0.0, 1.0) = 0.45;    // 投影最深處不透明度
uniform vec4 rim_light_color : source_color = vec4(0.4, 0.85, 1.0, 0.9); // 左側邊緣的金屬切角高光
uniform float rim_light_width_px : hint_range(0.5, 3.0) = 1.2;     // 高光寬度（像素）

void fragment() {
    // 取得像素單位大小
    vec2 screen_pixel_size = SCREEN_PIXEL_SIZE;
    
    // 計算切割線在當前 Y 軸下的 X 軸位置 (UV)
    float center_uv_x = split_x + (UV.y - 0.5) * slant;
    
    // 當前像素距離切割線邊緣的水平像素距離（負數代表在左側高平面，正數代表在右側低平面）
    float dist_px = (UV.x - center_uv_x) / screen_pixel_size.x;

    vec4 final_col = vec4(0.0);

    // ==========================================
    // 1. 左側面板（較高平面）：完全透明，僅在最邊緣處有一道高光倒角
    // ==========================================
    if (dist_px < 0.0) {
        // 在最貼近邊界處（例如 -1.2px 到 0px）呈現高光亮邊
        if (dist_px >= -rim_light_width_px) {
            float t = (dist_px - (-rim_light_width_px)) / rim_light_width_px;
            final_col = vec4(rim_light_color.rgb, rim_light_color.a * t);
        }
    }
    // ==========================================
    // 2. 右側面板（較低平面）：受到左側面板遮蔽，產生向右淡出的柔和陰影
    // ==========================================
    else if (dist_px <= drop_shadow_width_px) {
        // 使用平滑曲線讓陰影由深（左緣）向淺（右側）自然衰減
        float norm_dist = dist_px / drop_shadow_width_px;
        float shadow_falloff = pow(1.0 - norm_dist, 2.0); // 平方衰減，柔和自然
        
        final_col = vec4(0.0, 0.0, 0.0, drop_shadow_opacity * shadow_falloff);
    }

    COLOR = final_col;
}