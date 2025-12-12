#pragma once

#include <stdint.h>

#import <Metal/Metal.h>

class Texture
{
public:
    Texture() = default;
    Texture(MTLTextureDescriptor* descriptor);
    ~Texture();

    void SetDescriptor(MTLTextureDescriptor* descriptor);
    void Resize(uint32_t width, uint32_t height);
    id<MTLTexture> GetTexture() const { return m_Texture; }

    bool Valid() { return m_Texture != nil; }

    void SetLabel(NSString* label) { m_Texture.label = label; }
private:
    id<MTLTexture> m_Texture;
    MTLTextureDescriptor* m_Descriptor;
};
