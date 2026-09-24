#version 440

// Realistic glass for a single rounded rectangle over a backdrop texture that holds
// exactly what lies behind it (the lock card over the lock's blurred background).
// The backdrop is lensed near the edge with chromatic dispersion, the same optics as
// glass.frag's realistic branch, from an analytic rounded-box SDF. Tint and light
// are drawn on top by the card itself.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 plateSize;   // px
    float plateRadius; // px
    float refraction; // 0-1 lens strength
    float dispersion; // 0-1 chromatic spread
};

layout(binding = 1) uniform sampler2D backdrop;

const float kLens = 28.0; // lens band inside the edge, px (as glass.frag)

float sdRoundedBox(vec2 p, vec2 halfSize, float r) {
    vec2 q = abs(p) - halfSize + r;
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
}

void main() {
    vec2 halfSize = plateSize * 0.5;
    vec2 p = qt_TexCoord0 * plateSize - halfSize;
    float r = clamp(plateRadius, 0.0, min(halfSize.x, halfSize.y));
    float sdf = sdRoundedBox(p, halfSize, r);
    float d = max(-sdf, 0.0);

    vec2 grad = vec2(dFdx(sdf), dFdy(sdf));
    vec2 n = grad / max(length(grad), 1e-4);

    // Content near the edge is sampled from further in, so it bends outward and
    // bunches up at the rim; the middle stays flat
    float t = clamp(1.0 - d / kLens, 0.0, 1.0);
    vec2 off = -n * clamp(refraction, 0.0, 1.0) * kLens * t * t / max(plateSize, vec2(1.0));
    float k = clamp(dispersion, 0.0, 1.0) * 0.25;

    vec3 col = vec3(texture(backdrop, clamp(qt_TexCoord0 + off * (1.0 + k), 0.0, 1.0)).r,
                    texture(backdrop, clamp(qt_TexCoord0 + off, 0.0, 1.0)).g,
                    texture(backdrop, clamp(qt_TexCoord0 + off * (1.0 - k), 0.0, 1.0)).b);

    float luma = dot(col, vec3(0.2126, 0.7152, 0.0722));
    col = clamp(mix(vec3(luma), col, 1.1), 0.0, 1.0);

    float coverage = 1.0 - smoothstep(-0.75, 0.75, sdf);
    fragColor = vec4(col * coverage, coverage) * qt_Opacity;
}
