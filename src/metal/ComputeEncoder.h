#pragma once

#include "ComputePipeline.h"
#include "Buffer.h"
#include "Texture.h"
#include "IndirectCommandBuffer.h"
#include "Fence.h"

class ComputeEncoder
{
public:
    ComputeEncoder(id<MTLCommandBuffer> cmdBuffer, NSString* label, Fence* fence = nullptr);
    ~ComputeEncoder() = default;

    void End();

    void SetPipeline(const ComputePipeline& pipeline);
    void SetBytes(const void* bytes, size_t length, int index);

    void SetBuffer(id<MTLBuffer> buffer, int index, size_t offset = 0);
    void SetBuffer(const Buffer& buffer, int index, size_t offset = 0);

    void SetTexture(id<MTLTexture> texture, int index);
    void SetTexture(const Texture& texture, int index);

    void ResourceBarrier(const Buffer& buffer);
    void ResourceBarrier(const Texture& texture);
    void ResourceBarrier(const IndirectCommandBuffer& buffer);

    void PushGroup(NSString* string);
    void PopGroup();

    void Dispatch(MTLSize numGroups, MTLSize threadsPerGroup);

    void SignalFence();
    void WaitForFence();

    id<MTLComputeCommandEncoder> GetEncoder() { return m_Encoder; }
private:
    id<MTLComputeCommandEncoder> m_Encoder;
    Fence* m_Fence;
};
