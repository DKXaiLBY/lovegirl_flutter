#include <flutter/runtime_effect.glsl>

uniform vec2 uCenter;
uniform float uRadius;
uniform vec3 uWorldX;
uniform vec3 uWorldY;
uniform vec3 uWorldZ;
uniform vec3 uOcean;
uniform vec3 uLand;
uniform sampler2D uMask;
out vec4 fragColor;

void main() {
  vec2 local = (FlutterFragCoord().xy - uCenter) / uRadius;
  float length2 = dot(local, local);
  if (length2 > 1.0) {
    fragColor = vec4(0.0);
    return;
  }
  float facing = sqrt(max(0.0, 1.0 - length2));
  vec3 world = uWorldX * local.x + uWorldY * local.y + uWorldZ * facing;
  vec2 uv = vec2(fract(0.5 + atan(world.x, world.z) / 6.28318530718),
    0.5 + asin(clamp(world.y, -1.0, 1.0)) / 3.14159265359);
  float land = texture(uMask, uv).r;
  vec3 color = mix(uOcean, uLand, land);
  float light = 0.78 + 0.19 * facing + 0.06 * (-local.x - local.y);
  fragColor = vec4(color * light, 1.0);
}
