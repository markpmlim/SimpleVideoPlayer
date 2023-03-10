///// Copyright (c) 2017 Razeware LLC
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

import Foundation
import GLKit

class Shader {
    var program: GLuint = 0
    // Vertex Shader
    var position = GLuint()
    var texCoord = GLuint()
    var modelViewProjectionMatrix = GLint()
    // Fragment Shader
#if os(iOS)
    var samplerY = GLuint()
    var samplerUV = GLuint()
#else
    var samplerBGRA = GLuint()
#endif

    init() {
        let glProgram = GLProgram()
        program = glProgram.compileShaders(vertexShaderName: "vertexShader",
                                           fragmentShaderName: "fragmentShader")
        glUseProgram(program)

        // Vertex Shader
        position = GLuint(glGetAttribLocation(program, "position"))
        glEnableVertexAttribArray(position)
        texCoord = GLuint(glGetAttribLocation(program, "texCoord"))
        glEnableVertexAttribArray(texCoord)
        modelViewProjectionMatrix = GLint(glGetUniformLocation(program, "modelViewProjectionMatrix"))

        // Fragment Shader
    #if os(iOS)
        samplerY = GLuint(glGetUniformLocation(program, "samplerY"))
        samplerUV = GLuint(glGetUniformLocation(program, "samplerUV"))
    #else
        // The macOS version use a different fragment shader.
        samplerBGRA = GLuint(glGetUniformLocation(program, "samplerBGRA"))
    #endif
    }
}
