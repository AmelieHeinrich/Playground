#pragma once

#include <Metal/Metal.h>

#include "texture.h"
#include "buffer.h"
#include "indirect_command_buffer.h"
#include "fence.h"

class BlitEncoder {
public:
    BlitEncoder(id<MTLCommandBuffer> commandBuffer, NSString* label, Fence* fence = nullptr);
    ~BlitEncoder() = default;

    void CopyTexture(id<MTLTexture> source, id<MTLTexture> destination);
    void CopyTexture(const Texture& source, const Texture& destination);

    void FillBuffer(id<MTLBuffer> buffer, uint value);
    void FillBuffer(const Buffer& buffer, uint value);

    void OptimizeIndirectCommandBuffer(const IndirectCommandBuffer& indirectCommandBuffer, uint count);
    void ResetIndirectCommandBuffer(const IndirectCommandBuffer& indirectCommandBuffer, uint count);

    void SignalFence();
    void WaitForFence();

    void End();
private:
    id<MTLBlitCommandEncoder> m_BlitEncoder;
    Fence* m_Fence;
};
