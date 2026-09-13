#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 panelSize;
    vec4 tint;
    float strength;
    float backdrop;
    float intensity;
};
layout(binding = 1) uniform sampler2D source;

void main() {
    vec2 p = (qt_TexCoord0 - 0.5) * panelSize;
    vec2 q = abs(p) - (panelSize * 0.5 - 24.0);
    vec2 corner = max(q, 0.0);
    float distance = length(corner) + min(max(q.x, q.y), 0.0) - 24.0;
    float coverage = 1.0 - smoothstep(-0.8, 0.4, distance);
    float depth = max(-distance, 0.0);
    vec2 normal = length(corner) > 0.001
        ? normalize(corner) * sign(p)
        : (q.x > q.y ? vec2(sign(p.x), 0.0) : vec2(0.0, sign(p.y)));

    // A convex rim bends only the artwork, never the text or other windows.
    float rim = 1.0 - smoothstep(0.0, 18.0, depth);
    vec2 bend = normal * (13.0 * rim * rim * intensity) / panelSize;
    vec2 uv = clamp(qt_TexCoord0 - bend, vec2(0.005), vec2(0.995));
    vec2 dispersion = normal * (0.65 * rim * intensity) / panelSize;
    vec3 art = vec3(texture(source, uv + dispersion).r,
                    texture(source, uv).g,
                    texture(source, uv - dispersion).b);
    float luminance = dot(art, vec3(0.2126, 0.7152, 0.0722));
    art = mix(vec3(luminance), art, 0.65);

    float light = pow(max(dot(normal, normalize(vec2(-0.65, -0.76))), 0.0), 3.0);
    float counterLight = pow(max(dot(normal, normalize(vec2(0.8, 0.6))), 0.0), 5.0);
    float lip = exp(-pow((depth - 1.0) / 0.85, 2.0));
    float innerLip = exp(-pow((depth - 5.0) / 1.8, 2.0));
    float reflection = lip * (0.10 + 0.58 * light + 0.28 * counterLight)
                     + innerLip * (0.035 + 0.08 * counterLight);
    float centerOpacity = mix(1.0, 0.88, backdrop * intensity);
    float alpha = strength * mix(centerOpacity, 0.42, rim * intensity);
    vec3 body = mix(tint.rgb, art, (0.055 + 0.38 * rim) * intensity);
    // Output premultiplied alpha, with reflections forming their own surface.
    vec3 color = body * alpha;
    float shine = reflection * strength * intensity;
    color = color * (1.0 - shine) + vec3(0.94, 0.97, 1.0) * shine;
    alpha = alpha + shine * (1.0 - alpha);
    fragColor = vec4(color, alpha) * coverage * qt_Opacity;
}
