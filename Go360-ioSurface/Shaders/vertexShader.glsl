
#version 330 

uniform mat4 modelViewProjectionMatrix;

in vec4 position;
in vec2 texCoord;

out vec2 textureCoordinate;

void main() {
    textureCoordinate = texCoord;
    gl_Position = modelViewProjectionMatrix * position;
}
