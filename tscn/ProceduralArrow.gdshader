shader_type canvas_item;

// 外框與底色設定
uniform vec4 body_color : source_color = vec4(1.0, 0.8, 0.2, 0.2);   // 平時未按壓時的半透明底色
uniform vec4 border_color : source_color = vec4(1.0, 0.8, 0.2, 0.95); // 外框亮線顏色
uniform float border_thickness_px = 3.0;                              // 外框固定粗細 (像素，不受縮放影響)

// 狀態控制
uniform float is_holding_active = 0.0; // 1.0 = 長壓按住中
uniform float is_missed = 0.0;         // 1.0 = 斷條 Miss

// 當前矩形像素尺寸 (由 GDScript 每幀更新)
uniform vec2 rect_size = vec2(30.0, 100.0);

void fragment() {
    vec2 uv = UV;
    vec2 pixel_pos = uv * rect_size;

    // 1. 繪製精準像素外框 (以 pixel_pos 計算，寬窄完全不變形)
    float left = step(pixel_pos.x, border_thickness_px);
    float right = step(rect_size.x - border_thickness_px, pixel_pos.x);
    float top = step(pixel_pos.y, border_thickness_px);
    float bottom = step(rect_size.y - border_thickness_px, pixel_pos.y);
    float border_mask = clamp(left + right + top + bottom, 0.0, 1.0);

    // 2. 狀態顏色與透明度控制
    vec4 dynamic_body = body_color;
    vec4 dynamic_border = border_color;

    // (A) 長壓中：拉高至 0.65 扎實亮黃
    // (B) 平常下落：維持 0.25 半透明
    // (C) 斷條 Miss：降至 0.13 淡黃
    float target_body_alpha = body_color.a;
    if (is_holding_active > 0.5) {
        target_body_alpha = 0.45;
    } else if (is_missed > 0.5) {
        target_body_alpha = 0.13;
    }
    dynamic_body.a = target_body_alpha;

    // 外框同步淡化
    float target_border_alpha = border_color.a;
    if (is_missed > 0.5) {
        target_border_alpha = 0.35;
    }
    dynamic_border.a = target_border_alpha;

    // 3. 圖層合成：半透明底色 -> 亮線外框 (覆蓋在最上層)
    vec4 col = dynamic_body;
    col = mix(col, dynamic_border, border_mask * dynamic_border.a);

    // 乘上節點淡入淡出透明度
    COLOR = col * COLOR;
}