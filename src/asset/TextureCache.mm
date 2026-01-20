#include "TextureCache.h"
#include "AstcLoader.h"
#include "Ktx2Loader.h"
#include "Metal/Device.h"

TextureCache::Data TextureCache::sData;

void TextureCache::Shutdown()
{
    for (auto& texture : sData.Textures)
        Device::GetResidencySet().RemoveResource(texture.second);
    sData.Textures.clear();
}

id<MTLTexture> TextureCache::GetTexture(const std::string& path)
{
    auto it = sData.Textures.find(path);
    if (it != sData.Textures.end())
        return it->second;

    id<MTLTexture> texture = KTX2Loader::LoadKTX2(path);
    sData.Textures[path] = texture;

    Device::GetResidencySet().AddResource(texture);

    return texture;
}
