#pragma once

#include <stdint.h>

#import <Metal/Metal.h>

class Texture
{
public:
    Texture() = default;
    Texture(MTLTextureDescriptor* descriptor);
    Texture(id<MTLTexture> texture);
    ~Texture();

    void SetDescriptor(MTLTextureDescriptor* descriptor);
    void Resize(uint32_t width, uint32_t height);
    void UploadData(const void* data, uint64_t size, uint64_t bpp);

    id<MTLTexture> GetTexture() const { return m_Texture; }
    uint64_t GetResourceID() const;
    bool Valid() { return m_Texture != nil; }
    void SetLabel(NSString* label) { m_Texture.label = label; }
    uint32_t Width() const { return (uint32_t)m_Descriptor.width; }
    uint32_t Height() const { return (uint32_t)m_Descriptor.height; }
private:
    id<MTLTexture> m_Texture = nil;
    MTLTextureDescriptor* m_Descriptor;
};
