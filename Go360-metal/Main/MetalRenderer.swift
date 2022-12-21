//
//  MetalRenderer.swift
//  Go360-metal
//
//  Created by mark lim pak mun on 06/12/2022.
//  Copyright © 2022 Incremental Innovation. All rights reserved.
//

import AppKit
import MetalKit

// size=64 bytes, stride=64 bytes
struct Uniforms {
    let modelViewProjectionMatrix: matrix_float4x4
}

// Global constants
let kMaxInFlightFrameCount = 3
let kAlignedUniformsSize = (MemoryLayout<Uniforms>.stride & ~0xFF) + 0x100

class MetalRenderer: NSObject {
    var device: MTLDevice!
    var metalLayer: CAMetalLayer!
    var commandQueue: MTLCommandQueue!

    var sphereMesh: SphereMesh!
    var sphereRenderPipelineState: MTLRenderPipelineState!
    var depthTexture: MTLTexture!
    var computePipelineState: MTLComputePipelineState!
    var threadsPerThreadgroup: MTLSize!
    var threadgroupsPerGrid: MTLSize!

    var viewSize: CGSize!
    var degree: Float = 0
    var rotateX: Float = 0.0
    var rotateY: Float = 0.0
    var modelViewProjectionMatrix = matrix_identity_float4x4
    var projectionMatrix = matrix_identity_float4x4
    var uniformsBuffers = [MTLBuffer]()
    let frameSemaphore = DispatchSemaphore(value: kMaxInFlightFrameCount)
    var currentFrameIndex = 0

    var lumaTexture: MTLTexture?
    var chromaTexture: MTLTexture?
    var lumaTextureRef: CVMetalTexture?
    var chromaTextureRef: CVMetalTexture?
    var videoTextureCache: CVMetalTextureCache?
    var outputTexture: MTLTexture!
    var frameSize: CGSize!                          // Assume all frames of the video are the same.

    init(metalLayer: CAMetalLayer,
         frameSize: CGSize,
         device: MTLDevice) {
        self.metalLayer = metalLayer
        self.device = device
        self.frameSize = frameSize

        commandQueue = device.makeCommandQueue()
        super.init()
        buildResources(self.device)
    }

    deinit {
        for _ in 0..<kMaxInFlightFrameCount {
            self.frameSemaphore.signal()
        }
    }

    func buildResources(_ device: MTLDevice) {
        sphereMesh = SphereMesh(withRadius: 1.0,
                                inwardNormals: true,
                                device: device)

        // Allocate memory for 3 inflight blocks of Uniforms.
        for _ in 0..<kMaxInFlightFrameCount {
            let buffer = self.device.makeBuffer(length: kAlignedUniformsSize,
                                                options: .cpuCacheModeWriteCombined)
            uniformsBuffers.append(buffer)
        }

        guard let library = self.device.newDefaultLibrary() else {
            fatalError("Could not load default library from main bundle")
        }

        // Create the render pipeline for the drawable render pass.
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.label = "Render Sphere Pipeline"
        pipelineDescriptor.sampleCount = 1
        pipelineDescriptor.colorAttachments[0].pixelFormat = metalLayer.pixelFormat
        pipelineDescriptor.depthAttachmentPixelFormat = MTLPixelFormat.depth32Float
        pipelineDescriptor.vertexFunction = library.makeFunction(name: "SphereVertexShader")
        pipelineDescriptor.fragmentFunction = library.makeFunction(name: "SphereFragmentShader")
        let mtlVertexDescriptor = MTKMetalVertexDescriptorFromModelIO(sphereMesh.metalKitMesh.vertexDescriptor)
        pipelineDescriptor.vertexDescriptor = mtlVertexDescriptor
        //print(mtlVertexDescriptor)
        do {
            sphereRenderPipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        }
        catch {
            fatalError("Could not create sphere render pipeline state object: \(error)")
        }

        // Use a compute shader function to convert yuv colours to rgb colours.
        let kernelFunction = library.makeFunction(name: "YCbCrColorConversion")
        do {
            computePipelineState = try device.makeComputePipelineState(function: kernelFunction!)
        }
        catch {
            fatalError("Unable to create pipeline state")
        }
        // Instantiate a new instance of MTLTexture to capture the output of kernel function.
        // We assume all video frames have the same size.
        let mtlTextureDesc = MTLTextureDescriptor()
        mtlTextureDesc.textureType = .type2D
        mtlTextureDesc.pixelFormat = metalLayer.pixelFormat
        mtlTextureDesc.width = Int(self.frameSize.width)
        mtlTextureDesc.height = Int(self.frameSize.height)
        mtlTextureDesc.usage = [.shaderRead, .shaderWrite]
        outputTexture = device.makeTexture(descriptor: mtlTextureDesc)

        // To speed up the colour conversion of a video frame, utilise all available threads
        let w = computePipelineState.threadExecutionWidth
        let h = computePipelineState.maxTotalThreadsPerThreadgroup / w
        threadsPerThreadgroup = MTLSizeMake(w, h, 1)
        threadgroupsPerGrid = MTLSizeMake((mtlTextureDesc.width+threadsPerThreadgroup.width-1) / threadsPerThreadgroup.width,
                                          (mtlTextureDesc.height+threadsPerThreadgroup.height-1) / threadsPerThreadgroup.height,
                                          1)
     }

    func buildDepthBuffer() {
        let drawableSize = metalLayer.drawableSize
        let depthTexDesc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .depth32Float,
                                                                    width: Int(drawableSize.width),
                                                                    height: Int(drawableSize.height),
                                                                    mipmapped: false)
        depthTexDesc.resourceOptions = .storageModePrivate
        depthTexDesc.usage = [.renderTarget, .shaderRead]
        self.depthTexture = self.device.makeTexture(descriptor: depthTexDesc)
    }

    func resize(_ size: CGSize) {
        viewSize = size
        buildDepthBuffer()
        let aspect = Float(viewSize.width/viewSize.height)
        projectionMatrix = matrix_perspective_left_hand(radians_from_degrees(60),
                                                        aspect,
                                                        0.1, 10.0)
    }

    private func cleanTextures() {
        if lumaTextureRef != nil {
            lumaTextureRef = nil
        }

        if chromaTextureRef != nil {
            chromaTextureRef = nil
        }

        if let videoTextureCache = videoTextureCache {
            CVMetalTextureCacheFlush(videoTextureCache, 0)
        }
    }

    // Called by the view controller's newFrame method.
    func updateTexture(_ pixelBuffer: CVPixelBuffer) {
        if videoTextureCache == nil {
            let result = CVMetalTextureCacheCreate(kCFAllocatorDefault,
                                                   nil,                 // cacheAttributes
                                                   device,
                                                   nil,                 // textureAttributes
                                                   &videoTextureCache)
            if result != kCVReturnSuccess {
                print("create CVMetalTextureCacheCreate failure")
                return
            }
        }

        let textureWidth = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0)
        let textureHeight = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0)

        CVPixelBufferLockBaseAddress(pixelBuffer,
                                     CVPixelBufferLockFlags(rawValue:CVOptionFlags(0)))

        cleanTextures()

        var result: CVReturn
        result = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                           videoTextureCache!,
                                                           pixelBuffer,
                                                           nil,
                                                           .r8Unorm,
                                                           textureWidth, textureHeight,
                                                           0,
                                                           &lumaTextureRef)
        if result != kCVReturnSuccess {
            print("Failed to create lumaTextureRef: %d", result)
            return
        }
 
        let cbcrWidth = CVPixelBufferGetWidthOfPlane(pixelBuffer, 1);
        let cbcrHeight = CVPixelBufferGetHeightOfPlane(pixelBuffer, 1);
        result = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                           videoTextureCache!,
                                                           pixelBuffer,
                                                           nil,
                                                           .rg8Unorm,
                                                           cbcrWidth, cbcrHeight,
                                                           1,
                                                           &chromaTextureRef)

        if result != kCVReturnSuccess {
            print("Failed to create chromaTextureRef %d", result)
            return
        }

        // Pass these 2 MTLTextures to the kernel function
        lumaTexture = CVMetalTextureGetTexture(lumaTextureRef!)
        chromaTexture = CVMetalTextureGetTexture(chromaTextureRef!)

        CVPixelBufferUnlockBaseAddress(pixelBuffer,
                                       CVPixelBufferLockFlags(rawValue:CVOptionFlags(0)))
    }
 
    func updateModelViewProjectionMatrix() {
        
        var modelViewMatrix = matrix4x4_rotation(rotateX, float3(1, 0, 0))
        let rotationMatrix = matrix4x4_rotation(rotateY, float3(0, 1, 0))
        modelViewMatrix = matrix_multiply(modelViewMatrix, rotationMatrix)
        modelViewProjectionMatrix = matrix_multiply(projectionMatrix, modelViewMatrix)
    }

    // This method will be called per frame update.
    // CAMetalLayer has a function nextDrawable.
    func draw() {
        autoreleasepool {
            guard let drawable = metalLayer.nextDrawable() else {
                return
            }
            _ = frameSemaphore.wait(timeout: DispatchTime.distantFuture)
            
            let commandBuffer = commandQueue.makeCommandBuffer()
            let computeCommandEncoder = commandBuffer.makeComputeCommandEncoder()
            computeCommandEncoder.label = "Compute Encoder"

            computeCommandEncoder.setComputePipelineState(computePipelineState)
            computeCommandEncoder.setTexture(lumaTexture, at: 0)
            computeCommandEncoder.setTexture(chromaTexture, at: 1)
            computeCommandEncoder.setTexture(outputTexture, at: 2) // out texture
            computeCommandEncoder.dispatchThreadgroups(threadgroupsPerGrid,
                                                       threadsPerThreadgroup: threadsPerThreadgroup)
            computeCommandEncoder.endEncoding()

            let drawableSize = drawable.layer.drawableSize
            if (drawableSize.width != CGFloat(depthTexture.width) ||
                drawableSize.height != CGFloat(depthTexture.height)) {
                buildDepthBuffer()
            }
            let renderPassDescriptor = MTLRenderPassDescriptor()
            renderPassDescriptor.colorAttachments[0].texture = drawable.texture
            renderPassDescriptor.colorAttachments[0].loadAction = .clear
            renderPassDescriptor.colorAttachments[0].storeAction = .store
            renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(1, 1, 1, 1)

            renderPassDescriptor.depthAttachment.texture = self.depthTexture
            renderPassDescriptor.depthAttachment.loadAction = .clear
            renderPassDescriptor.depthAttachment.storeAction = .dontCare
            renderPassDescriptor.depthAttachment.clearDepth = 1

            updateModelViewProjectionMatrix()
            var uniform = Uniforms(modelViewProjectionMatrix: modelViewProjectionMatrix)
            let bufferPointer = uniformsBuffers[currentFrameIndex].contents()
            memcpy(bufferPointer,
                   &uniform,
                   kAlignedUniformsSize)
            let currentBuffer = uniformsBuffers[currentFrameIndex]

            let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
            renderEncoder.label = "Render Encoder"
            renderEncoder.setRenderPipelineState(sphereRenderPipelineState)
            let viewPort = MTLViewport(originX: 0.0, originY: 0.0,
                                       width: Double(viewSize.width), height: Double(viewSize.height),
                                       znear: -1.0, zfar: 1.0)
            renderEncoder.setViewport(viewPort)

            renderEncoder.setVertexBuffer(currentBuffer,
                                          offset: 0,
                                          at: 1)
            renderEncoder.setFragmentTexture(outputTexture,
                                             at: 0)

            let meshBuffer = sphereMesh.metalKitMesh.vertexBuffers[0]
            renderEncoder.setVertexBuffer(meshBuffer.buffer,
                                          offset: meshBuffer.offset,
                                          at: 0)

            // Issue the draw call to draw the indexed geometry of the mesh
            for (index, submesh) in sphereMesh.metalKitMesh.submeshes.enumerated() {
                let indexBuffer = submesh.indexBuffer
                renderEncoder.drawIndexedPrimitives(type: submesh.primitiveType,
                                                    indexCount: submesh.indexCount,
                                                    indexType: submesh.indexType,
                                                    indexBuffer: indexBuffer.buffer,
                                                    indexBufferOffset: indexBuffer.offset)
            }
            commandBuffer.addCompletedHandler {
                [weak self] commandBuffer in
                if let strongSelf = self {
                    strongSelf.frameSemaphore.signal()
                    /*
                     value of status    name
                     0               notEnqueued
                     1               enqueued
                     2               committed
                     3               scheduled
                     4               completed
                     5               error
                     */
                    if commandBuffer.status == .error {
                        print("Command Buffer Status Error")
                    }
                }
                return
            }
            renderEncoder.endEncoding()
            commandBuffer.present(drawable)
            commandBuffer.commit()
            currentFrameIndex = (currentFrameIndex + 1) % kMaxInFlightFrameCount
        }
    }
}
