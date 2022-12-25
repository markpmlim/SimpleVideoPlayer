
#version 330

// Rectangular textures allows us to access texture values directly using
//  the pixel positions of the fragment.
uniform sampler2DRect samplerY;
uniform sampler2DRect samplerUV;
uniform vec2 textureDimensions;

in vec2 textureCoordinate;

out vec4 fragmentColor;

void main() {
  vec3 yuv;
  
  vec3 rgb;
    // For digital component video the color format YCbCr is used.
    // ITU-R BT.709, which is the standard for HDTV.
    // http://www.equasys.de/colorconversion.html
    // [0.0, 1.0] --> [0.0, textureWidth]
    // [0.0, 1.0] --> [0.0, textureHeight]
    vec2 lumaCoords = textureCoordinate * textureDimensions;
    vec2 chromaCoords = lumaCoords*vec2(0.5, 0.5);
    yuv.x = texture(samplerY, lumaCoords).r - (16.0 / 255.0);
    yuv.yz = texture(samplerUV, chromaCoords).rg - vec2(128.0 / 255.0, 128.0 / 255.0);
    rgb = mat3(1.164, 1.164, 1.164,
               0.0, -0.213, 2.112,
               1.793, -0.533, 0.0) * yuv;
    fragmentColor = vec4(rgb, 1.0);
}
