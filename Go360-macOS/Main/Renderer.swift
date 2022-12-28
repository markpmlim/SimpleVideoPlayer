//
//  ViewController.swift
//  Go360-macOS
//
//  Created by mark lim pak mun on 06/12/2022.
//  Copyright © 2022 Incremental Innovation. All rights reserved.
//
// Unlike OpenGL ES and Metal, the corresponding function
//      CVOpenGLTextureCacheCreateTextureFromImage
// does not support creating the luminance and chrominance textures directly.

import Foundation
import OpenGL
import CoreVideo
import GLKit

class Renderer {
    let shader: Shader!
    let model: Sphere!
    let fieldOfView: Float = 60.0

    var context: NSOpenGLContext!
    var view: NSOpenGLView!
    var viewSize = CGSize.zero          // in pixels
    // VBOs and IBO
    var vertexBuffer: GLuint = 0
    var texCoordBuffer: GLuint = 0
    var indexBuffer: GLuint = 0
    // VAO
    var vertexArray: GLuint = 0
    // Transforms
    var projectionMatrix = GLKMatrix4Identity
    var modelViewProjectionMatrix = GLKMatrix4Identity
    // OpenGL Texture
    var videoFrameTexture: GLuint?

    init(view: NSOpenGLView, context: NSOpenGLContext, shader: Shader, model: Sphere) {
        self.view = view
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

    func resize(_ size: CGSize) {
        viewSize = size
        // Compute the projection matrix
        let aspect = Float(viewSize.width/viewSize.height)
        let fieldOfViewInRadians = GLKMathDegreesToRadians(fieldOfView)
        projectionMatrix = GLKMatrix4MakePerspective(fieldOfViewInRadians,
                                                     aspect,
                                                     0.1, 10.0)
    }

    func render() {
        glClearColor(0.0, 0.0, 0.0, 1.0)
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT))

        glUseProgram(shader.program)

        // Uniforms
        glUniform1i(GLint(shader.samplerBGRA), 0)
        glUniformMatrix4fv(shader.modelViewProjectionMatrix,
                           1,
                           GLboolean(GL_FALSE),
                           modelViewProjectionMatrix.array)

        // Texture
        if let videoFrameTexture = videoFrameTexture {
            glActiveTexture(GLenum(GL_TEXTURE0))
            glBindTexture(GLenum(GL_TEXTURE_2D), videoFrameTexture)
        }

        glBindVertexArray(vertexArray)
        glDrawElements(GLenum(GL_TRIANGLES),
                       GLsizei(model.indexCount),
                       GLenum(GL_UNSIGNED_SHORT),
                       nil)
        glBindVertexArray(0)
    }

    func updateModelViewProjectionMatrix(_ rotationX: Float, _ rotationY: Float) {
        // Only rotational movements; no translation.
        // Which means the camera/viewer is at the centre of the scene.
        var modelViewMatrix = GLKMatrix4Identity
        modelViewMatrix = GLKMatrix4RotateX(modelViewMatrix, rotationX)
        modelViewMatrix = GLKMatrix4RotateY(modelViewMatrix, rotationY)
        modelViewProjectionMatrix = GLKMatrix4Multiply(projectionMatrix, modelViewMatrix)
    }

    func updateTexture(_ pixelBuffer: CVPixelBuffer) {

        cleanTextures()
        if videoFrameTexture == nil {
            CVPixelBufferLockBaseAddress(pixelBuffer,
                                         .readOnly)
            let textureWidth = GLsizei(CVPixelBufferGetWidth(pixelBuffer))
            let textureHeight = GLsizei(CVPixelBufferGetHeight(pixelBuffer))
            let bpr = CVPixelBufferGetBytesPerRow(pixelBuffer)
            // GLsizei(bpr/4) == GLsizei(textureHeight) for 32-bit RGBA/BGRA
            let data = CVPixelBufferGetBaseAddress(pixelBuffer)
            var textureID: GLuint = 0
            glGenTextures(1, &textureID)
            glBindTexture(GLenum(GL_TEXTURE_2D), textureID);
            glTexImage2D(GLenum(GL_TEXTURE_2D),
                         0,
                         GL_RGBA,
                         GLsizei(textureWidth), GLsizei(textureHeight),
                         0,
                         GLenum(GL_BGRA),
                         GLenum(GL_UNSIGNED_INT_8_8_8_8_REV),
                         data)
            videoFrameTexture = textureID
            glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MIN_FILTER), GL_LINEAR)
            glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MAG_FILTER), GL_LINEAR)
            glTexParameterf(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_S), GLfloat(GL_CLAMP_TO_EDGE))
            glTexParameterf(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_T), GLfloat(GL_CLAMP_TO_EDGE))
            CVPixelBufferUnlockBaseAddress(pixelBuffer,
                                           .readOnly)
        }
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

        if videoFrameTexture != nil {
            glDeleteTextures(1, &videoFrameTexture!)
            videoFrameTexture = nil
        }
    }
}
