#include "BLAS.h"
#include "Metal/Device.h"
#include <Metal/Metal.h>
#import "Swift/DebugBridge.h"

struct PackedVertex
{
    float px, py, pz;
    float nx, ny, nz;
    float u, v;
    float tx, ty, tz, tw;
};

BLAS::BLAS(const Model& model)
{
    m_Geometries = [NSMutableArray array];

    for (auto& mesh : model.Meshes) {
        MTLAccelerationStructureTriangleGeometryDescriptor* geometry = [MTLAccelerationStructureTriangleGeometryDescriptor descriptor];
        geometry.vertexBuffer = model.VertexBuffer.GetBuffer();
        geometry.vertexStride = sizeof(PackedVertex);
        geometry.indexBuffer = model.IndexBuffer.GetBuffer();
        geometry.indexBufferOffset = mesh.IndexOffset * sizeof(uint);
        geometry.triangleCount = mesh.IndexCount / 3;
        geometry.indexType = MTLIndexTypeUInt32;
        geometry.opaque = model.Materials[mesh.MaterialIndex].Opaque;

        [m_Geometries addObject:geometry];
    }

    m_Descriptor = [MTLPrimitiveAccelerationStructureDescriptor descriptor];
    m_Descriptor.geometryDescriptors = m_Geometries;
    m_Descriptor.usage = MTLAccelerationStructureUsageNone;

    MTLAccelerationStructureSizes prebuildInfo = [Device::GetDevice() accelerationStructureSizesWithDescriptor:m_Descriptor];

    m_AccelerationStructure = [Device::GetDevice() newAccelerationStructureWithSize:prebuildInfo.accelerationStructureSize];
    m_Scratch.Initialize(prebuildInfo.buildScratchBufferSize);
    m_Scratch.SetLabel(@"BLAS Scratch Buffer");

    Device::GetResidencySet().AddResource(m_AccelerationStructure);
    
    // Track allocation in Debug Bridge
    NSString* name = m_AccelerationStructure.label ?: [NSString stringWithFormat:@"BLAS_%p", m_AccelerationStructure];
    [[DebugBridge shared] trackAllocation:name
                                     size:prebuildInfo.accelerationStructureSize
                                     type:ResourceTypeAccelerationStructure
                                 heapType:HeapTypePrivate];
}

BLAS::~BLAS()
{
    if (m_AccelerationStructure) {
        NSString* name = m_AccelerationStructure.label ?: [NSString stringWithFormat:@"BLAS_%p", m_AccelerationStructure];
        [[DebugBridge shared] removeAllocation:name];
        Device::GetResidencySet().RemoveResource(m_AccelerationStructure);
    }
}

uint64_t BLAS::GetResourceID()
{
    return m_AccelerationStructure.gpuResourceID._impl;
}

void BLAS::FreeScratchBuffer()
{
    m_Scratch.Cleanup();
}

void BLAS::SetLabel(NSString* label)
{
    if (m_AccelerationStructure) {
        // Remove old tracking entry
        NSString* oldName = m_AccelerationStructure.label ?: [NSString stringWithFormat:@"BLAS_%p", m_AccelerationStructure];
        [[DebugBridge shared] removeAllocation:oldName];
        
        // Update label
        m_AccelerationStructure.label = label;
        
        // Re-track with new name
        MTLAccelerationStructureSizes prebuildInfo = [Device::GetDevice() accelerationStructureSizesWithDescriptor:m_Descriptor];
        [[DebugBridge shared] trackAllocation:label
                                         size:prebuildInfo.accelerationStructureSize
                                         type:ResourceTypeAccelerationStructure
                                     heapType:HeapTypePrivate];
    }
}
