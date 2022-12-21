/// Copyright (c) 2017 Razeware LLC
///
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
///
/// The above copyright notice and this permission notice shall be included in
/// all copies or substantial portions of the Software.
///
/// Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
/// distribute, sublicense, create a derivative work, and/or sell copies of the
/// Software in any work that is designed, intended, or marketed for pedagogical or
/// instructional purposes related to programming, coding, application development,
/// or information technology.  Permission for such use, copying, modification,
/// merger, publication, distribution, sublicensing, creation of derivative works,
/// or sale is expressly withheld.
///
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
/// THE SOFTWARE.

#version 300 es

precision mediump float;

uniform sampler2D samplerY;
uniform sampler2D samplerUV;

in vec2 textureCoordinate;

out vec4 fragmentColor;

void main() {
    mediump vec3 yuv;
    lowp vec3 rgb;

    // For digital component video the color format YCbCr is used.
    // ITU-R BT.709, which is the standard for HDTV.
    // http://www.equasys.de/colorconversion.html
    yuv.x = texture(samplerY, textureCoordinate).r - (16.0 / 255.0);
    yuv.yz = texture(samplerUV, textureCoordinate).ra - vec2(128.0 / 255.0, 128.0 / 255.0);
    rgb = mat3(1.164, 1.164, 1.164,
               0.0, -0.213, 2.112,
               1.793, -0.533, 0.0) * yuv;

    fragmentColor = vec4(rgb, 1);
}
