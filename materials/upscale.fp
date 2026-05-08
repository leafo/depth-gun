varying mediump vec2 var_texcoord0;

uniform lowp sampler2D texture_sampler; // unused (slot 0, sprite's atlas)
uniform lowp sampler2D world_sampler;   // slot 1, bound from render script

void main() {
    gl_FragColor = texture2D(world_sampler, var_texcoord0.xy);
}
