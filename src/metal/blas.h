#pragma once

#include <Metal/Metal.h>

#include "asset/mesh_loader.h"

class BLAS
{
public:
    BLAS(const Model& model);
    ~BLAS();

    uint64_t GetResourceID();
    void SetLabel(NSString* label) { m_AccelerationStructure.label = label; }

    id<MTLAccelerationStructure> GetAccelerationStructure() const { return m_AccelerationStructure; }
    MTLPrimitiveAccelerationStructureDescriptor* GetDescriptor() const { return m_Descriptor; }

    Buffer* GetScratchBuffer() { return &m_Scratch; }
    void FreeScratchBuffer();
private:
    NSMutableArray* m_Geometries;
    MTLPrimitiveAccelerationStructureDescriptor* m_Descriptor;

    id<MTLAccelerationStructure> m_AccelerationStructure;
    Buffer m_Scratch;
};
