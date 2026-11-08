#version 440
// dot mask: an element turns into a matrix of led dots. a dot takes its color from the center of its cell —
// so every dot is one size and one even tone, like the pulse leds on the back of a phone. color is brightness only: monochrome
// build: qsb --qt6 -o dots.frag.qsb dots.frag

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;  // element size, px
    float pitch; // grid pitch, px. not step: that's a glsl builtin — spirv-cross renames it to _step and qt can't find the uniform
    float circ;  // 1 — dots inside the circle only (covers)
};
layout(binding = 1) uniform sampler2D source;

void main() {
    vec2 p = qt_TexCoord0 * size;
    vec2 c = (floor(p / pitch) + 0.5) * pitch;
    float r = pitch * 0.3; // as in radial-gradient(#000 40%, transparent 44%) in the concept
    float m = 1.0 - smoothstep(r - 0.6, r + 0.6, distance(p, c));
    if (circ > 0.5 && distance(c, size * 0.5) > min(size.x, size.y) * 0.5) m = 0.0;
    vec4 t = texture(source, c / size);
    float l = dot(t.rgb, vec3(0.299, 0.587, 0.114)); // luma: color covers go grey too
    fragColor = vec4(vec3(l), t.a) * m * qt_Opacity;
}
