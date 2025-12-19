#include "texture.h"
#include "device.h"

Texture::Texture(MTLTextureDescriptor* descriptor)
    : m_Descriptor([descriptor copy])
{
    Resize((uint32_t)descriptor.width, (uint32_t)descriptor.height);
}

Texture::Texture(id<MTLTexture> texture)
    : m_Texture(texture)
{
    if (m_Texture) {
        // Create descriptor from existing texture properties
        m_Descriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:texture.pixelFormat
                                                                          width:texture.width
                                                                         height:texture.height
                                                                      mipmapped:texture.mipmapLevelCount > 1];
        m_Descriptor.textureType = texture.textureType;
        m_Descriptor.arrayLength = texture.arrayLength;
        m_Descriptor.usage = texture.usage;
        
        Device::GetResidencySet().AddResource(m_Texture);
    }
}

Texture::~Texture()
{
    if (m_Texture) {
        Device::GetResidencySet().RemoveResource(m_Texture);
    }
    m_Descriptor = nil;
}

uint64_t Texture::GetResourceID() const
{
    return static_cast<uint64_t>(m_Texture.gpuResourceID._impl);
}

void Texture::SetDescriptor(MTLTextureDescriptor* descriptor)
{
    m_Descriptor = [descriptor copy];
}

void Texture::Resize(uint32_t width, uint32_t height)
{
    // Skip resize if dimensions haven't changed
    if (m_Texture && m_Descriptor.width == width && m_Descriptor.height == height) {
        return;
    }

    // Remove old texture from residency set and release it
    if (m_Texture) {
        Device::GetResidencySet().RemoveResource(m_Texture);
    }

    // Update descriptor dimensions
    m_Descriptor.width = width;
    m_Descriptor.height = height;

    // Create new texture with updated dimensions
    m_Texture = [Device::GetDevice() newTextureWithDescriptor:m_Descriptor];
    
    // Reapply label if one was set
    if (m_Label) {
        m_Texture.label = m_Label;
    }
    
    Device::GetResidencySet().AddResource(m_Texture);
}

void Texture::UploadData(const void* data, uint64_t size, uint64_t bpp)
{
    [m_Texture replaceRegion:MTLRegionMake2D(0, 0, Width(), Height()) mipmapLevel:0 withBytes:data bytesPerRow:Width() * bpp];
}
