#include "texture.h"
#include "device.h"

Texture::Texture(MTLTextureDescriptor* descriptor)
    : m_Descriptor(descriptor)
{
    Resize((uint32_t)descriptor.width, (uint32_t)descriptor.height);
}

Texture::~Texture()
{
    Device::GetResidencySet().RemoveResource(m_Texture);
}

void Texture::Resize(uint32_t width, uint32_t height)
{
    if (m_Texture) Device::GetResidencySet().RemoveResource(m_Texture);

    m_Descriptor.width = width;
    m_Descriptor.height = height;

    m_Texture = [Device::GetDevice() newTextureWithDescriptor:m_Descriptor];
    Device::GetResidencySet().AddResource(m_Texture);
}
