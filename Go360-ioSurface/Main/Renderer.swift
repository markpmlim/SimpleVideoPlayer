//
//  ViewController.swift
//  Go360-macOS
//
//  Created by mark lim pak mun on 06/12/2022.
//  Copyright © 2022 Incremental Innovation. All rights reserved.
//
// KIV - convert contents of CVPixelBuffer to a luminance and chroma textures.
// Unlike OpenGL ES and Metal, the corresponding function
//      CVOpenGLTextureCacheCreateTextureFromImage
// does not support creating these 2 textures directly.

import Foundation
import OpenGL.GL3
import CoreVideo
import GLKit

class Renderer {
    let shader: Shader!
    let model: Sphere!
    let fieldOfView: Float = 60.0
    var textureSize = CGSize(width: 1920.0, height: 960.0)

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
    // OpenGL Textures
    var lumaTexture: GLuint?        // luminance texture
    var chromaTexture: GLuint?      // chrominance texture

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
        glUniform1i(GLint(shader.samplerY), 0)
        glUniform1i(GLint(shader.samplerUV), 1)
        glUniformMatrix4fv(shader.modelViewProjectionMatrix,
                           1,
                           GLboolean(GL_FALSE),
                           modelViewProjectionMatrix.array)

        glUniform2f(GLint(shader.textureDimensions),
                    GLfloat(textureSize.width), GLfloat(textureSize.height))
        // We must call glActiveTexture first before binding the texture.
        if let lumaTexture = lumaTexture {
            glActiveTexture(GLenum(GL_TEXTURE0))
            glBindTexture(GLenum(GL_TEXTURE_RECTANGLE), lumaTexture)
        }

        if let chromaTexture = chromaTexture {
            glActiveTexture(GLenum(GL_TEXTURE1))
            glBindTexture(GLenum(GL_TEXTURE_RECTANGLE), chromaTexture)
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

    func updateTextures(_ pixelBuffer: CVPixelBuffer) {
        cleanTextures()
        if chromaTexture == nil {
            // Not necessary to lock
            let cvReturn = CVPixelBufferLockBaseAddress(pixelBuffer,
                                                        .readOnly)
            // Returns the instance of IOSurface backing the pixel buffer
            guard let surface = CVPixelBufferGetIOSurface(pixelBuffer)?.takeUnretainedValue() else {
                return
            }
            // Not necessary to lock
            IOSurfaceLock(surface, .readOnly, nil)
            var textureWidth = GLsizei(IOSurfaceGetWidthOfPlane(surface, 0))
            var textureHeight = GLsizei(IOSurfaceGetHeightOfPlane(surface, 0))
            // We could set the "textureSize" by passing its value during initialization of the Renderer object.
            textureSize = CGSize(width: CGFloat(textureWidth), height: CGFloat(textureHeight))

            var textureID: GLuint = 0
            glGenTextures(1, &textureID)
            // The call glActiveTexture must precede the call glBindTexture
            glActiveTexture(GLenum(GL_TEXTURE0))
            glBindTexture(GLenum(GL_TEXTURE_RECTANGLE), textureID);
            // cf: CGLIOSurface.h CGLTypes.h
            // 10007 - kCGLBadState (invalid context state) error
            var cglErr = CGLTexImageIOSurface2D(context.cglContextObj!,
                                                GLenum(GL_TEXTURE_RECTANGLE),
                                                GLenum(GL_R8),
                                                textureWidth, textureHeight,
                                                GLenum(GL_RED),
                                                GLenum(GL_UNSIGNED_BYTE),
                                                surface,
                                                0)
            lumaTexture = textureID
            glTexParameteri(GLenum(GL_TEXTURE_RECTANGLE), GLenum(GL_TEXTURE_MIN_FILTER), GL_LINEAR)
            glTexParameteri(GLenum(GL_TEXTURE_RECTANGLE), GLenum(GL_TEXTURE_MAG_FILTER), GL_LINEAR)
            glTexParameteri(GLenum(GL_TEXTURE_RECTANGLE), GLenum(GL_TEXTURE_WRAP_S), GL_CLAMP_TO_EDGE)
            glTexParameteri(GLenum(GL_TEXTURE_RECTANGLE), GLenum(GL_TEXTURE_WRAP_T), GL_CLAMP_TO_EDGE)
            glBindTexture(GLenum(GL_TEXTURE_RECTANGLE), 0)

            textureWidth = GLsizei(IOSurfaceGetWidthOfPlane(surface, 1))
            textureHeight = GLsizei(IOSurfaceGetHeightOfPlane(surface, 1))
            glGenTextures(1, &textureID)
            glActiveTexture(GLenum(GL_TEXTURE1))
            glBindTexture(GLenum(GL_TEXTURE_RECTANGLE), textureID);
            cglErr = CGLTexImageIOSurface2D(context.cglContextObj!,
                                            GLenum(GL_TEXTURE_RECTANGLE),
                                            GLenum(GL_RG8),
                                            textureWidth, textureHeight,
                                            GLenum(GL_RG),
                                            GLenum(GL_UNSIGNED_BYTE),
                                            surface,
                                            1)
            chromaTexture = textureID
            glBindTexture(GLenum(GL_TEXTURE_RECTANGLE), 0)
            glTexParameteri(GLenum(GL_TEXTURE_RECTANGLE), GLenum(GL_TEXTURE_MIN_FILTER), GL_LINEAR)
            glTexParameteri(GLenum(GL_TEXTURE_RECTANGLE), GLenum(GL_TEXTURE_MAG_FILTER), GL_LINEAR)
            glTexParameteri(GLenum(GL_TEXTURE_RECTANGLE), GLenum(GL_TEXTURE_WRAP_S), GL_CLAMP_TO_EDGE)
            glTexParameteri(GLenum(GL_TEXTURE_RECTANGLE), GLenum(GL_TEXTURE_WRAP_T), GL_CLAMP_TO_EDGE)
            IOSurfaceUnlock(surface, .readOnly, nil);
            CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
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

        if lumaTexture != nil {
            glDeleteTextures(1, &lumaTexture!)
            lumaTexture = nil
        }

        if chromaTexture != nil {
            glDeleteTextures(1, &chromaTexture!)
            chromaTexture = nil
        }
    }
}
