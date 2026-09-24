#version 440

// Liquid Glass compositor for a BlobGroup in glass mode (see blob.frag). The input
// holds light data, not colour: r = specular rim, g = bezel light, b = edge line,
// a = coverage, all premultiplied. The output is a translucent tint with the light
// on top, plus a soft shadow drawn only outside the shape, so it never darkens the
// body. The compositor blurs whatever is behind the tinted body.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 tint;          // body colour; alpha is the glass opacity
    vec4 shadowColour;  // alpha is the shadow strength
    float highlight;    // 0-1 specular strength
    float lightMode;    // 1 in light mode: adds a darker hairline for edge definition
    vec2 shadowOffset;  // in UV units
};

layout(binding = 1) uniform sampler2D source;
layout(binding = 2) uniform sampler2D shadowSource;

void main() {
    vec4 src = texture(source, qt_TexCoord0);
    float cov = src.a;
    vec3 data = cov > 0.0 ? src.rgb / cov : vec3(0.0);

    float rim = clamp(data.r, 0.0, 1.0);
    float bezel = clamp(data.g, 0.0, 1.0);
    float edge = clamp(data.b, 0.0, 1.0);

    float h = clamp(highlight, 0.0, 1.0);
    float bodyA = clamp(tint.a, 0.0, 1.0);

    // Body: premultiplied tint
    vec4 glassCol = vec4(tint.rgb * bodyA, bodyA);

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
