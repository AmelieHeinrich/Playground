#include "TLAS.h"
#include "Device.h"
#include "Renderer/SceneAb.h"
#include <Metal/Metal.h>
#include <simd/matrix.h>
#import "Swift/DebugBridge.h"

TLAS::~TLAS()
{
    if (m_TLAS) {
        NSString* name = m_TLAS.label ?: [NSString stringWithFormat:@"TLAS_%p", m_TLAS];
        [[DebugBridge shared] removeAllocation:name];
        Device::GetResidencySet().RemoveResource(m_TLAS);
    }
}

void TLAS::Initialize()
{
    m_InstanceBuffer.Initialize(sizeof(MTLAccelerationStructureInstanceDescriptor) * MAX_SCENE_INSTANCES);
    m_InstanceBuffer.SetLabel(@"TLAS Instance Buffer");

    m_Descriptor = [MTLInstanceAccelerationStructureDescriptor descriptor];
    m_Descriptor.instanceCount = MAX_SCENE_INSTANCES;
    m_Descriptor.instanceDescriptorType = MTLAccelerationStructureInstanceDescriptorTypeDefault;
    m_Descriptor.instanceDescriptorBuffer = m_InstanceBuffer.GetBuffer();

    MTLAccelerationStructureSizes sizes = [Device::GetDevice() accelerationStructureSizesWithDescriptor:m_Descriptor];
    m_ScratchBuffer.Initialize(sizes.buildScratchBufferSize);
    m_ScratchBuffer.SetLabel(@"TLAS Scratch Buffer");

    m_TLAS = [Device::GetDevice() newAccelerationStructureWithSize:sizes.accelerationStructureSize];
    Device::GetResidencySet().AddResource(m_TLAS);
    
    // Track allocation in Debug Bridge
    NSString* name = m_TLAS.label ?: [NSString stringWithFormat:@"TLAS_%p", m_TLAS];
    [[DebugBridge shared] trackAllocation:name
                                     size:sizes.accelerationStructureSize
                                     type:ResourceTypeAccelerationStructure
                                 heapType:HeapTypePrivate];
}

void TLAS::ResetInstanceBuffer()
{
    m_InstanceDescriptors.clear();
    m_BLASMap = [NSMutableArray array];
}

void TLAS::AddInstance(BLAS* blas)
{
    int found = -1;
    for (int i = 0; i < [m_BLASMap count]; i++) {
        if (m_BLASMap[i] == blas->GetAccelerationStructure()) {
            found = i;
            break;
        }
    }
    if (found == -1) {
        [m_BLASMap addObject:blas->GetAccelerationStructure()];
        found = (int)[m_BLASMap count] - 1;
    }

    MTLAccelerationStructureInstanceDescriptor instanceDescriptor = {};
    instanceDescriptor.options = MTLAccelerationStructureInstanceOptionNonOpaque;
    instanceDescriptor.mask = 0xFF;
    instanceDescriptor.accelerationStructureIndex = found;
    instanceDescriptor.transformationMatrix.columns[0][0] = 1.0f;
    instanceDescriptor.transformationMatrix.columns[1][1] = 1.0f;
    instanceDescriptor.transformationMatrix.columns[2][2] = 1.0f;

    m_InstanceDescriptors.push_back(instanceDescriptor);
}

void TLAS::Update()
{
    void* ptr = m_InstanceBuffer.Contents();
    memcpy(ptr, m_InstanceDescriptors.data(), sizeof(MTLAccelerationStructureInstanceDescriptor) * m_InstanceDescriptors.size());
}

uint64_t TLAS::GetResourceID()
{
    return m_TLAS.gpuResourceID._impl;
}

void TLAS::SetLabel(NSString* label)
{
    if (m_TLAS) {
        // Remove old tracking entry
        NSString* oldName = m_TLAS.label ?: [NSString stringWithFormat:@"TLAS_%p", m_TLAS];
        [[DebugBridge shared] removeAllocation:oldName];
        
        // Update label
        m_TLAS.label = label;
        
        // Re-track with new name
        MTLInstanceAccelerationStructureDescriptor* descriptor = m_Descriptor;
        MTLAccelerationStructureSizes sizes = [Device::GetDevice() accelerationStructureSizesWithDescriptor:descriptor];
        [[DebugBridge shared] trackAllocation:label
                                         size:sizes.accelerationStructureSize
                                         type:ResourceTypeAccelerationStructure
                                     heapType:HeapTypePrivate];
    }
}
