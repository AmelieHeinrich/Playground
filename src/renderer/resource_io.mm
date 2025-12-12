#include "resource_io.h"

std::unordered_map<std::string, Resource> ResourceIO::s_Resources;

Resource& ResourceIO::CreateTexture(const std::string& name, MTLTextureDescriptor* descriptor)
{
    Resource resource;
    resource.Type = ResourceType::TEXTURE;
    resource.Texture.SetDescriptor(descriptor);
    s_Resources[name] = resource;
    return s_Resources[name];
}

Resource& ResourceIO::CreateBuffer(const std::string& name, uint64_t size)
{
    Resource resource;
    resource.Type = ResourceType::BUFFER;
    resource.Buffer.Initialize(size);
    s_Resources[name] = resource;
    return s_Resources[name];
}

Resource& ResourceIO::CreateArgumentBuffer(const std::string& name, id<MTLFunction> function, int index)
{
    Resource resource;
    resource.Type = ResourceType::ARGUMENT_BUFFER;
    resource.ArgBuffer.Initialize(function, index);
    s_Resources[name] = resource;
    return s_Resources[name];
}

Resource& ResourceIO::Get(const std::string& name)
{
    return s_Resources[name];
}
