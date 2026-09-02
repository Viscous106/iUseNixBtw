// This is a GLSL fragment shader for a ripple effect.
// It can be used with the OpenRGB Effects Plugin.

uniform float iTime; // Time in seconds since the shader started
uniform vec3 iResolution; // Viewport resolution (width, height, 0)

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    // Normalize coordinates to be between 0.0 and 1.0
    vec2 uv = fragCoord.xy / iResolution.xy;

    // Center of the ripple
    vec2 center = vec2(0.5, 0.5);

    // Distance from the center
    float dist = distance(uv, center);

    // Create the ripple effect using sine wave
    // Adjust the frequency (e.g., 20.0), speed (e.g., 5.0), and amplitude (e.g., 0.02)
    float ripple = sin(dist * 20.0 - iTime * 5.0) * 0.02;

    // Displace the UV coordinates based on the ripple
    vec2 displacedUv = uv + normalize(uv - center) * ripple;
    
    // Example: A simple color gradient that ripples
    vec3 color = vec3(0.0);
    color.r = sin(displacedUv.x * 10.0 + iTime) * 0.5 + 0.5;
    color.g = sin(displacedUv.y * 10.0 + iTime + 2.0) * 0.5 + 0.5;
    color.b = sin((displacedUv.x + displacedUv.y) * 5.0 + iTime + 4.0) * 0.5 + 0.5;

    // You can also create a ripple effect on a base color or a texture.
    // For instance, to make the ripple itself a color:
    float intensity = fract(dist * 5.0 - iTime * 1.5); // Creates concentric rings
    vec3 rippleColor = mix(vec3(0.0, 0.0, 0.5), vec3(0.0, 0.5, 1.0), intensity); // Blue tones
    
    // For this example, let's just output the rippleColor for clarity.
    fragColor = vec4(rippleColor, 1.0);
}
