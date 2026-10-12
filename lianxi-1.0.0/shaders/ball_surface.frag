#version 460 core
#include <flutter/runtime_effect.glsl>

uniform float u_radius;
uniform vec4 u_rotation;
uniform vec3 u_color;
uniform float u_stripe;
uniform float u_cue;
uniform sampler2D u_number;

out vec4 fragColor;

vec3 rotateInverse(vec3 v, vec4 q) {
  vec3 t = 2.0 * cross(-q.xyz, v);
  return v + q.w * t + cross(-q.xyz, t);
}

void main() {
  vec2 p = FlutterFragCoord().xy / u_radius;
  float rr = dot(p, p);
  if (rr >= 1.0) {
    fragColor = vec4(0.0);
    return;
  }

  vec3 surface = vec3(p, sqrt(max(0.0, 1.0 - rr)));
  vec3 local = rotateInverse(surface, normalize(u_rotation));
  vec3 ivory = vec3(0.96, 0.94, 0.84);
  vec3 pigment = u_color;
  vec3 base = u_cue > 0.5 ? ivory :
      (u_stripe > 0.5 && abs(local.y) > 0.38 ? vec3(0.97, 0.97, 0.94) : pigment);

  if (u_cue > 0.5) {
    if (local.z > 0.985 || local.z < -0.985) {
      base = mix(base, vec3(0.91, 0.18, 0.10), 0.92);
    }
  } else {
    vec3 decalSurface = local.z >= 0.0 ? local : vec3(-local.x, local.y, -local.z);
    if (decalSurface.z > 0.84) {
      vec2 decalUv = decalSurface.xy / 0.55 * 0.5 + 0.5;
      vec4 decal = texture(u_number, decalUv);
      base = mix(base, decal.rgb, decal.a);
    }
  }

  // Light and rim stay fixed in screen space while the pigment rolls.
  vec3 light = normalize(vec3(-0.42, -0.55, 0.73));
  float diffuse = max(dot(surface, light), 0.0);
  float specular = pow(max(dot(reflect(-light, surface), vec3(0.0, 0.0, 1.0)), 0.0), 35.0);
  float rim = smoothstep(0.75, 1.0, sqrt(rr));
  vec3 shaded = base * (0.48 + 0.56 * diffuse) * (1.0 - 0.30 * rim);
  shaded += vec3(0.68) * specular;
  fragColor = vec4(shaded, 1.0);
}
