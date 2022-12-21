
import MetalKit
import SceneKit.ModelIO

class SphereMesh {

    var metalKitMesh: MTKMesh

    init?(withRadius radius: Float,
          inwardNormals: Bool,
          device: MTLDevice) {

        let mdlVertexDescriptor = MDLVertexDescriptor()
        mdlVertexDescriptor.attributes[0] = MDLVertexAttribute(name: MDLVertexAttributePosition,
                                                               format: MDLVertexFormat.float3,
                                                               offset: 0,
                                                               bufferIndex: 0)
        mdlVertexDescriptor.attributes[1] = MDLVertexAttribute(name: MDLVertexAttributeNormal,
                                                               format: MDLVertexFormat.float3,
                                                               offset: MemoryLayout<Float>.stride * 3,
                                                               bufferIndex: 0)
        mdlVertexDescriptor.attributes[2] = MDLVertexAttribute(name: MDLVertexAttributeTextureCoordinate,
                                                               format: MDLVertexFormat.float2,
                                                               offset: MemoryLayout<Float>.stride * 6,
                                                               bufferIndex: 0)

        mdlVertexDescriptor.layouts[0] = MDLVertexBufferLayout(stride: MemoryLayout<Float>.stride * 8)

        let allocator = MTKMeshBufferAllocator(device: device)
        
        let sphereMDLMesh = MDLMesh.newEllipsoid(withRadii: [radius,radius,radius],
                                                 radialSegments: 500,
                                                 verticalSegments: 500,
                                                 geometryType: .triangles,
                                                 inwardNormals: inwardNormals,
                                                 hemisphere: false,
                                                 allocator: allocator)
        sphereMDLMesh.vertexDescriptor = mdlVertexDescriptor

        do {
            metalKitMesh = try MTKMesh(mesh: sphereMDLMesh,
                                       device:device)
        }
        catch let err as NSError {
            print("Can't create Sphere mesh:", err)
            return nil
        }
    }
}
