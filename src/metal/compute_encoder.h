#pragma once

#include "compute_pipeline.h"
#include "buffer.h"
#include "texture.h"

class ComputeEncoder
{
public:
    ComputeEncoder(id<MTLCommandBuffer> cmdBuffer, NSString* label);
    ~ComputeEncoder() = default;

    void End();

    void SetPipeline(const ComputePipeline& pipeline);
    void SetBytes(const void* bytes, size_t length, int index);

    void SetBuffer(id<MTLBuffer> buffer, int index, size_t offset = 0);
    void SetBuffer(const Buffer& buffer, int index, size_t offset = 0);

    void SetTexture(id<MTLTexture> texture, int index);
    void SetTexture(const Texture& texture, int index);
    
    void PushGroup(NSString* string);
    void PopGroup();

    void Dispatch(MTLSize numGroups, MTLSize threadsPerGroup);

    id<MTLComputeCommandEncoder> GetEncoder() { return m_Encoder; }
private:
    id<MTLComputeCommandEncoder> m_Encoder;
};
