#pragma once

#include "Blas.h"
#include <Foundation/Foundation.h>

class TLAS
{
public:
    TLAS() = default;
    ~TLAS();

    void Initialize();
    void ResetInstanceBuffer();
    void AddInstance(BLAS* blas);
    void Update();
    void SetLabel(NSString* label);

    uint64_t GetResourceID();
    id<MTLAccelerationStructure> GetTLAS() { return m_TLAS; }
    MTLInstanceAccelerationStructureDescriptor* GetDescriptor() { return m_Descriptor; }
    NSMutableArray* GetBLASMap() { return m_BLASMap; }

    Buffer* GetScratchBuffer() { return &m_ScratchBuffer; }
private:
    id<MTLAccelerationStructure> m_TLAS = nil;
    MTLInstanceAccelerationStructureDescriptor* m_Descriptor;

    Buffer m_InstanceBuffer;
    Buffer m_ScratchBuffer;
    std::vector<MTLAccelerationStructureInstanceDescriptor> m_InstanceDescriptors;
    NSMutableArray* m_BLASMap;
};
