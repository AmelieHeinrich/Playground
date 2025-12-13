#include "texture.h"
#include "device.h"

Texture::Texture(MTLTextureDescriptor* descriptor)
    : m_Descriptor([descriptor copy])
{
    Resize((uint32_t)descriptor.width, (uint32_t)descriptor.height);
}

Texture::~Texture()
{
    if (m_Texture) {
        Device::GetResidencySet().RemoveResource(m_Texture);
    }
    m_Descriptor = nil;
}

void Texture::SetDescriptor(MTLTextureDescriptor* descriptor)
{
    m_Descriptor = [descriptor copy];
}

void Texture::Resize(uint32_t width, uint32_t height)
{
    if (m_Texture) Device::GetResidencySet().RemoveResource(m_Texture);

    m_Descriptor.width = width;
    m_Descriptor.height = height;

    m_Texture = [Device::GetDevice() newTextureWithDescriptor:m_Descriptor];
    Device::GetResidencySet().AddResource(m_Texture);
}

void Texture::UploadData(const void* data, uint64_t size, uint64_t bpp)
{
    [m_Texture replaceRegion:MTLRegionMake2D(0, 0, Width(), Height()) mipmapLevel:0 withBytes:data bytesPerRow:Width() * bpp];
}
