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
#if os(iOS)
import OpenGLES.ES3
#else
import OpenGL
#endif

class GLProgram {
    private var programHandle: GLuint = 0
    private var vertexShader: GLuint = 0
    private var fragmentShader: GLuint = 0

    // Returns an OpenGLES program ID
    func compileShaders(vertexShaderName: String,
                        fragmentShaderName: String) -> GLuint {
        programHandle = glCreateProgram()

        if !compileShader(&vertexShader,
                          type: GLenum(GL_VERTEX_SHADER),
                          file: Bundle.main.path(forResource: vertexShaderName,
                                                 ofType: "glsl")!) {
            print("vertex shader failure")
        }

        if !compileShader(&fragmentShader,
                          type: GLenum(GL_FRAGMENT_SHADER),
                          file: Bundle.main.path(forResource: fragmentShaderName,
                                                 ofType: "glsl")!) {
            print("fragment shader failure")
        }

        glAttachShader(programHandle, vertexShader)
        glAttachShader(programHandle, fragmentShader)

        if !link() {
            print("link failure")
        }

        return programHandle
    }

    private func link() -> Bool {
        var status: GLint = 0

        glLinkProgram(programHandle)
        glGetProgramiv(programHandle, GLenum(GL_LINK_STATUS), &status)

        if status == GL_FALSE {
            return false
        }

        if vertexShader > 0 {
            glDeleteShader(vertexShader)
            vertexShader = 0
        }

        if fragmentShader > 0 {
            glDeleteShader(fragmentShader)
            fragmentShader = 0
        }

        return true
    }

    private func compileShader(_ shader: inout GLuint,
                               type: GLenum,
                               file: String) -> Bool {
        var status: GLint = 0
        var source: UnsafePointer<Int8>

        do {
            source = try NSString(contentsOfFile: file,
                                  encoding: String.Encoding.utf8.rawValue).utf8String!
        }
        catch {
            print("failed to load shader")
            return false
        }

        var castSource: UnsafePointer<GLchar>? = UnsafePointer<GLchar>(source)
        
        shader = glCreateShader(type)
        glShaderSource(shader, 1, &castSource, nil)
        glCompileShader(shader)
        glGetShaderiv(shader, GLenum(GL_COMPILE_STATUS), &status)

        if status == GL_FALSE {
            glDeleteShader(shader)
            return false
        }

        return true
    }
}
