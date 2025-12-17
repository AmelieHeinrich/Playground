#pragma once

#include "blas.h"
#include "tlas.h"
#include "fence.h"

class AccelerationEncoder
{
public:
    AccelerationEncoder(id<MTLCommandBuffer> cmdBuffer, NSString* label, Fence* fence);
    ~AccelerationEncoder() = default;

    void End();

    void BuildTLAS(TLAS* tlas);
    void BuildBLAS(BLAS* blas);

    // TODO: Refit, compact
private:
    id<MTLAccelerationStructureCommandEncoder> m_Encoder;
    Fence* m_Fence;
};
