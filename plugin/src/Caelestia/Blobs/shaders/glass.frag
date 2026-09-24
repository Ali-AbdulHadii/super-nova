#version 440

// Liquid Glass compositor for a BlobGroup in glass mode (see blob.frag). The input
// holds edge geometry, not colour: rg = outward normal (0.5-biased), b = depth
// inside the edge over 64px, a = coverage, all premultiplied.
//
// Standard glass: a translucent tint that the compositor blurs behind, with the
// light on top. Realistic glass: an opaque body drawn from the wallpaper (which
// the drawers window lines up with the desktop exactly), lensed near the edges
// with chromatic dispersion, then tinted and lit the same way. Both draw a soft
// shadow only outside the shape, so it never darkens the body.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 tint;          // body colour; alpha is the glass opacity (tint strength when realistic)
    vec4 shadowColour;  // alpha is the shadow strength
    float highlight;    // 0-1 specular strength
    float lightMode;    // 1 in light mode: adds a darker hairline for edge definition
    vec2 shadowOffset;  // in UV units
    float realistic;    // 1 = draw the body from the wallpaper
    float refraction;   // 0-1 lens strength
    float dispersion;   // 0-1 chromatic spread
    vec2 targetSize;    // px, to turn pixel offsets into UVs
};

layout(binding = 1) uniform sampler2D source;
layout(binding = 2) uniform sampler2D shadowSource;
layout(binding = 3) uniform sampler2D wallpaper;
layout(binding = 4) uniform sampler2D wallpaperBlur;

const float kDepthRange = 64.0; // must match blob.frag
const float kBezel = 14.0;      // light band inside the edge, px
const float kLens = 28.0;       // lens band inside the edge, px

vec3 wallSample(vec2 uv, float sharpness) {
    return mix(texture(wallpaperBlur, uv).rgb, texture(wallpaper, uv).rgb, sharpness);
}

void main() {
    vec4 src = texture(source, qt_TexCoord0);
    float cov = src.a;
    vec3 data = cov > 0.0 ? src.rgb / cov : vec3(0.5, 0.5, 0.0);

    vec2 n = data.rg * 2.0 - 1.0;
    n /= max(length(n), 1e-4);
    float d = clamp(data.b, 0.0, 1.0) * kDepthRange;

    // Key light from the top-left, a weaker fill from the opposite corner
    vec2 lightDir = normalize(vec2(-1.0, -1.0));
    float lit = pow(max(dot(n, lightDir), 0.0), 2.0) + 0.35 * pow(max(dot(n, -lightDir), 0.0), 2.0);

    float edge = 1.0 - smoothstep(0.5, 2.5, d);
    float rim = edge * clamp(0.25 + 0.75 * lit, 0.0, 1.0);
    float bezel = exp(-d / kBezel) * (0.6 + 0.4 * lit);

    float h = clamp(highlight, 0.0, 1.0);
    float tintA = clamp(tint.a, 0.0, 1.0);

    vec4 glassCol;
    if (realistic > 0.5) {
        // Lens: content near the edge is sampled from further in, so it bends
        // outward and bunches up at the rim; the middle stays flat
        float t = clamp(1.0 - d / kLens, 0.0, 1.0);
        vec2 off = -n * clamp(refraction, 0.0, 1.0) * kLens * t * t / max(targetSize, vec2(1.0));

        // Dispersion: each channel bends by a slightly different amount
        float k = clamp(dispersion, 0.0, 1.0) * 0.25;
        float sharp = t * 0.35; // the lensed edge reads a little crisper than the frosted body
        vec3 body = vec3(wallSample(qt_TexCoord0 + off * (1.0 + k), sharp).r,
                         wallSample(qt_TexCoord0 + off, sharp).g,
                         wallSample(qt_TexCoord0 + off * (1.0 - k), sharp).b);

        // Glass lifts saturation slightly, then the scheme tint keeps text readable
        float luma = dot(body, vec3(0.2126, 0.7152, 0.0722));
        body = clamp(mix(vec3(luma), body, 1.15), 0.0, 1.0);
        body = mix(body, tint.rgb, tintA);

        glassCol = vec4(body, 1.0);
    } else {
        glassCol = vec4(tint.rgb * tintA, tintA);
    }

    // Light mode: a faint dark hairline under the highlight, as glass on a light
    // background needs something darker than itself to read as an edge
    float hair = lightMode * edge * 0.12;
    glassCol = glassCol * (1.0 - hair) + vec4(vec3(0.0), hair);

    // Light: the rim plus a soft band inside the edge, laid over the body
    float light = clamp(rim * h + bezel * 0.12 * h, 0.0, 1.0);
    glassCol = glassCol * (1.0 - light) + vec4(vec3(light), light);

    glassCol *= cov;

    // Shadow only where the shape isn't, from the blurred coverage
    float sh = texture(shadowSource, qt_TexCoord0 - shadowOffset).a * shadowColour.a * (1.0 - cov);
    vec4 shadow = vec4(shadowColour.rgb * sh, sh);

    fragColor = (glassCol + shadow * (1.0 - glassCol.a)) * qt_Opacity;
}
