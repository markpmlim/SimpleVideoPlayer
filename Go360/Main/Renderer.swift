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
import OpenGLES.ES3
import CoreVideo
import GLKit

class Renderer {
    let shader: Shader!
    let model: Sphere!
    let fieldOfView: Float = 60.0

    var context: EAGLContext!
    // VBO
    var vertexBuffer: GLuint = 0
    var texCoordBuffer: GLuint = 0
    var indexBuffer: GLuint = 0
    // VAO
    var vertexArray: GLuint = 0
    // Transform
    var modelViewProjectionMatrix = GLKMatrix4Identity
    // Texture
    var lumaTexture: CVOpenGLESTexture?
    var chromaTexture: CVOpenGLESTexture?
    var videoTextureCache: CVOpenGLESTextureCache?

    init(context: EAGLContext, shader: Shader, model: Sphere) {
        self.context = context
        self.shader = shader
        self.model = model
        
        createVBO()
        createVAO()
    }

    deinit {
        deleteVBO()
        deleteVAO()
    }

    func render() {
        glClearColor(0.0, 0.0, 0.0, 1.0)
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT))

        glUseProgram(shader.program)

        // Uniforms
        glUniform1i(GLint(shader.samplerY), 0)
        glUniform1i(GLint(shader.samplerUV), 1)
        glUniformMatrix4fv(shader.modelViewProjectionMatrix,
                           1,
                           GLboolean(GL_FALSE),
                           modelViewProjectionMatrix.array)

        // Texture
        if  let lumaTexture = lumaTexture,
            let chromaTexture = chromaTexture {
            glActiveTexture(GLenum(GL_TEXTURE0))
            glBindTexture(CVOpenGLESTextureGetTarget(lumaTexture),
                          CVOpenGLESTextureGetName(lumaTexture))
            glActiveTexture(GLenum(GL_TEXTURE1))
            glBindTexture(CVOpenGLESTextureGetTarget(chromaTexture),
                          CVOpenGLESTextureGetName(chromaTexture))
        }

        glBindVertexArray(vertexArray)
        glDrawElements(GLenum(GL_TRIANGLES),
                       GLsizei(model.indexCount),
                       GLenum(GL_UNSIGNED_SHORT),
                       nil)
        glBindVertexArray(0)
    }

    // Called by the view controller's delegate method "glkViewControllerUpdate"
    func updateModelViewProjectionMatrix(_ rotationX: Float, _ rotationY: Float) {
        // Compute the projection matrix
        let aspect = fabs(Float(UIScreen.main.bounds.size.width) / Float(UIScreen.main.bounds.size.height))
        let nearZ: Float = 0.1
        let farZ: Float = 100.0
        let fieldOfViewInRadians = GLKMathDegreesToRadians(fieldOfView)
        let projectionMatrix = GLKMatrix4MakePerspective(fieldOfViewInRadians,
                                                         aspect,
                                                         nearZ, farZ)
        // Only rotational movements; no translation
        // Which means the camera/viewer is at the centre of sphere.
        var modelViewMatrix = GLKMatrix4Identity
        //modelViewMatrix = GLKMatrix4Translate(modelViewMatrix, 0.0, 0.0, -2.0)
        modelViewMatrix = GLKMatrix4RotateX(modelViewMatrix, rotationX)
        modelViewMatrix = GLKMatrix4RotateY(modelViewMatrix, rotationY)
        modelViewProjectionMatrix = GLKMatrix4Multiply(projectionMatrix, modelViewMatrix)
    }

    func updateTextures(_ pixelBuffer: CVPixelBuffer) {
        if videoTextureCache == nil {
            let result = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault,
                                                      nil,
                                                      context,
                                                      nil,
                                                      &videoTextureCache)
            if result != kCVReturnSuccess {
                print("create CVOpenGLESTextureCacheCreate failure")
                return
            }
        }
    
        let textureWidth = GLsizei(CVPixelBufferGetWidth(pixelBuffer))
        let textureHeight = GLsizei(CVPixelBufferGetHeight(pixelBuffer))

        var result: CVReturn

        cleanTextures()

        // Mapping the luma plane of a 420v buffer as a source texture:
        glActiveTexture(GLenum(GL_TEXTURE0))
        result = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                              videoTextureCache!,
                                                              pixelBuffer,
                                                              nil,
                                                              GLenum(GL_TEXTURE_2D),
                                                              GL_LUMINANCE,
                                                              textureWidth, textureHeight,
                                                              GLenum(GL_LUMINANCE),
                                                              GLenum(GL_UNSIGNED_BYTE),
                                                              0,
                                                              &lumaTexture)
        if result != kCVReturnSuccess {
            print("create CVOpenGLESTextureCacheCreateTextureFromImage failure 1 %d", result)
            return
        }

        // Mapping the chroma plane of a 420v buffer as a source texture:
        glBindTexture(CVOpenGLESTextureGetTarget(lumaTexture!),
                      CVOpenGLESTextureGetName(lumaTexture!))
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MIN_FILTER), GL_LINEAR)
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MAG_FILTER), GL_LINEAR)
        glTexParameterf(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_S), GLfloat(GL_CLAMP_TO_EDGE))
        glTexParameterf(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_T), GLfloat(GL_CLAMP_TO_EDGE))

        glActiveTexture(GLenum(GL_TEXTURE1))
        result = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                              videoTextureCache!,
                                                              pixelBuffer,
                                                              nil,
                                                              GLenum(GL_TEXTURE_2D),
                                                              GL_LUMINANCE_ALPHA,
                                                              textureWidth / 2, textureHeight / 2,
                                                              GLenum(GL_LUMINANCE_ALPHA),
                                                              GLenum(GL_UNSIGNED_BYTE),
                                                              1,
                                                              &chromaTexture)
        if result != kCVReturnSuccess {
            print("create CVOpenGLESTextureCacheCreateTextureFromImage failure 2 %d", result)
            return
        }
    
        glBindTexture(CVOpenGLESTextureGetTarget(chromaTexture!),
                      CVOpenGLESTextureGetName(chromaTexture!))
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MIN_FILTER), GL_LINEAR)
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MAG_FILTER), GL_LINEAR)
        glTexParameterf(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_S), GLfloat(GL_CLAMP_TO_EDGE))
        glTexParameterf(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_T), GLfloat(GL_CLAMP_TO_EDGE))
    }

    private func createVBO() {
        // Vertex
        glGenBuffers(1, &vertexBuffer)
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), vertexBuffer)
        glBufferData(GLenum(GL_ARRAY_BUFFER),
                     GLsizeiptr(model.vertexCount * GLint(3 * MemoryLayout<GLfloat>.size)),
                     model.vertices,
                     GLenum(GL_STATIC_DRAW))
        
        // Texture Coordinates
        glGenBuffers(1, &texCoordBuffer)
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), texCoordBuffer)
        glBufferData(GLenum(GL_ARRAY_BUFFER),
                     GLsizeiptr(model.vertexCount * GLint(2 * MemoryLayout<GLfloat>.size)),
                     model.texCoords,
                     GLenum(GL_DYNAMIC_DRAW))
        
        // Indices
        glGenBuffers(1, &indexBuffer)
        glBindBuffer(GLenum(GL_ELEMENT_ARRAY_BUFFER), indexBuffer)
        glBufferData(GLenum(GL_ELEMENT_ARRAY_BUFFER),
                     GLsizeiptr(model.indexCount * GLint(MemoryLayout<GLushort>.size)),
                     model.indices,
                     GLenum(GL_STATIC_DRAW))
    }

    private func createVAO() {
        glGenVertexArrays(1, &vertexArray)
        glBindVertexArray(vertexArray)
        
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), vertexBuffer)
        glEnableVertexAttribArray(shader.position)
        glVertexAttribPointer(shader.position,
                              3,
                              GLenum(GL_FLOAT),
                              GLboolean(GL_FALSE),
                              GLsizei(MemoryLayout<GLfloat>.size * 3),
                              nil)
        
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), texCoordBuffer)
        glEnableVertexAttribArray(shader.texCoord)
        glVertexAttribPointer(shader.texCoord,
                              2,
                              GLenum(GL_FLOAT),
                              GLboolean(GL_FALSE),
                              GLsizei(MemoryLayout<GLfloat>.size * 2),
                              nil)
        
        glBindBuffer(GLenum(GL_ELEMENT_ARRAY_BUFFER), indexBuffer)
        
        glBindVertexArray(0)
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), 0)
        glBindBuffer(GLenum(GL_ELEMENT_ARRAY_BUFFER), 0)
    }

    private func deleteVBO() {
        glDeleteBuffers(1, &vertexBuffer)
        glDeleteBuffers(1, &texCoordBuffer)
        glDeleteBuffers(1, &indexBuffer)
    }

    private func deleteVAO() {
        glDeleteVertexArrays(1, &vertexArray)
    }

    private func cleanTextures() {
        if lumaTexture != nil {
            lumaTexture = nil
        }
        
        if chromaTexture != nil {
            chromaTexture = nil
        }
        
        if let videoTextureCache = videoTextureCache {
            CVOpenGLESTextureCacheFlush(videoTextureCache, 0)
        }
    }
}
