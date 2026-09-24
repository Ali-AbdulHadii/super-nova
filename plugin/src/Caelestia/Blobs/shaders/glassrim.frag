#version 440

// Glass light for a single rounded rectangle (a card or a button): the same rim and
// inner light band as glass.frag, from an analytic rounded-box SDF instead of the
// blob geometry. Draws light only; the card's own colour stays underneath.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 rimSize;     // px
    vec4 radii;       // px: top-left, top-right, bottom-right, bottom-left
    float highlight;  // 0-1 specular strength
    float apple;      // 1 = Apple glass: lit on both diagonals, brighter band
};

float sdRoundedBox4(vec2 p, vec2 halfSize, vec4 r) {
    // r = (topRight, bottomRight, bottomLeft, topLeft), y down
    r.xy = (p.x > 0.0) ? r.xy : r.wz;
    r.x = (p.y > 0.0) ? r.y : r.x;
    vec2 q = abs(p) - halfSize + r.x;
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r.x;
}

void main() {
    vec2 halfSize = rimSize * 0.5;
    vec2 p = qt_TexCoord0 * rimSize - halfSize;

    float maxR = min(halfSize.x, halfSize.y);
    vec4 r = clamp(vec4(radii.y, radii.z, radii.w, radii.x), 0.0, maxR);
    float sdf = sdRoundedBox4(p, halfSize, r);
    float d = max(-sdf, 0.0);

    vec2 grad = vec2(dFdx(sdf), dFdy(sdf));
    vec2 n = grad / max(length(grad), 1e-4);
    vec2 lightDir = normalize(vec2(-1.0, -1.0));

    float h = clamp(highlight, 0.0, 1.0);
    float edge = 1.0 - smoothstep(0.5, 2.0, d);
    float light;
    if (apple > 0.5) {
        float facing = pow(abs(dot(n, lightDir)), 1.5);
        light = (edge * (0.35 + 0.65 * facing) * 0.55 + exp(-d / 7.0) * 0.12) * h;
    } else {
        float lit = pow(max(dot(n, lightDir), 0.0), 2.0) + 0.35 * pow(max(dot(n, -lightDir), 0.0), 2.0);
        light = (edge * clamp(0.2 + 0.8 * lit, 0.0, 1.0) * 0.7 + exp(-d / 8.0) * (0.6 + 0.4 * lit) * 0.08) * h;
    }

    // Inside the shape only, anti-aliased against the edge
    float coverage = 1.0 - smoothstep(-0.75, 0.75, sdf);
    light = clamp(light, 0.0, 1.0) * coverage;

    fragColor = vec4(vec3(light), light) * qt_Opacity;
}
