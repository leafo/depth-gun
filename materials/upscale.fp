// LUT post-process. Defold samples textures with Y origin opposite to Love2D,
// so the LUT lookup's y is flipped via 1.0 - y at the boundary.

varying mediump vec2 var_texcoord0;

uniform lowp sampler2D texture_sampler;
uniform lowp sampler2D world_sampler;
uniform lowp sampler2D lut_sampler;

lowp vec4 lookup(lowp vec4 src) {
    mediump float blueColor = src.b * 63.0;

    mediump vec2 quad1;
    quad1.y = floor(floor(blueColor) / 8.0);
    quad1.x = floor(blueColor) - (quad1.y * 8.0);

    mediump vec2 quad2;
    quad2.y = floor(ceil(blueColor) / 8.0);
    quad2.x = ceil(blueColor) - (quad2.y * 8.0);

    mediump vec2 texPos1;
    texPos1.x = (quad1.x * 0.125) + 0.5 / 512.0 + ((0.125 - 1.0 / 512.0) * src.r);
    texPos1.y = 1.0 - ((quad1.y * 0.125) + 0.5 / 512.0 + ((0.125 - 1.0 / 512.0) * src.g));

    mediump vec2 texPos2;
    texPos2.x = (quad2.x * 0.125) + 0.5 / 512.0 + ((0.125 - 1.0 / 512.0) * src.r);
    texPos2.y = 1.0 - ((quad2.y * 0.125) + 0.5 / 512.0 + ((0.125 - 1.0 / 512.0) * src.g));

    lowp vec4 c1 = texture2D(lut_sampler, texPos1);
    lowp vec4 c2 = texture2D(lut_sampler, texPos2);
    return mix(c1, c2, fract(blueColor));
}

void main() {
    lowp vec4 src = texture2D(world_sampler, var_texcoord0.xy);
    gl_FragColor = vec4(lookup(src).rgb, src.a);
}
