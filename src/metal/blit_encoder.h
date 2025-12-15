#pragma once

#include <Metal/Metal.h>

#include "texture.h"
#include "buffer.h"

class BlitEncoder {
public:
    BlitEncoder(id<MTLCommandBuffer> commandBuffer, NSString* label);
    ~BlitEncoder() = default;

    void CopyTexture(id<MTLTexture> source, id<MTLTexture> destination);
    void CopyTexture(const Texture& source, const Texture& destination);

    void FillBuffer(id<MTLBuffer> buffer, uint value);
    void FillBuffer(const Buffer& buffer, uint value);

    void End();
private:
    id<MTLBlitCommandEncoder> m_BlitEncoder;
};
