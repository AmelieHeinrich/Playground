#include "ktx2_loader.h"
#include "fs.h"
#include "metal/device.h"

#include <ktx.h>
#include <cstring>
#include <vector>

API_AVAILABLE(macos(15.0))
id<MTLTexture> KTX2Loader::LoadKTX2(const std::string& path)
{
    // Load file into memory
    auto file = fs::LoadBinaryFile(path);
    if (!file.success) {
        NSLog(@"Failed to load KTX2 file: %s - %s", path.c_str(), file.error.c_str());
        return nil;
    }

    // Create KTX texture from memory
    ktxTexture* texture = nullptr;
    KTX_error_code result = ktxTexture_CreateFromMemory(
        file.data.data(),
        file.data.size(),
        KTX_TEXTURE_CREATE_LOAD_IMAGE_DATA_BIT,
        &texture
    );

    if (result != KTX_SUCCESS) {
        NSLog(@"Failed to parse KTX2 file: %s - Error code: %d", path.c_str(), result);
        return nil;
    }

    // Ensure we have a KTX2 texture
    if (texture->classId != ktxTexture2_c) {
        NSLog(@"File is not KTX2 format: %s", path.c_str());
        ktxTexture_Destroy(texture);
        return nil;
    }

    ktxTexture2* ktx2Texture = (ktxTexture2*)texture;

    // Get texture properties
    ktx_uint32_t baseWidth = ktx2Texture->baseWidth;
    ktx_uint32_t baseHeight = ktx2Texture->baseHeight;
    ktx_uint32_t numLevels = ktx2Texture->numLevels;
    ktx_uint32_t numLayers = ktx2Texture->numLayers;
    ktx_uint32_t numFaces = ktx2Texture->numFaces;
    ktx_uint32_t vkFormat = ktx2Texture->vkFormat;
    bool isCubemap = ktx2Texture->isCubemap;

    // Convert format
    MTLPixelFormat mtlFormat = MTLPixelFormatASTC_6x6_LDR;
    if (mtlFormat == MTLPixelFormatInvalid) {
        NSLog(@"Unsupported texture format in: %s", path.c_str());
        ktxTexture_Destroy(texture);
        return nil;
    }

    // Create Metal texture descriptor
    MTLTextureDescriptor* desc = nil;

    if (isCubemap) {
        desc = [MTLTextureDescriptor textureCubeDescriptorWithPixelFormat:mtlFormat
                                                                      size:baseWidth
                                                                 mipmapped:numLevels > 1];
    } else if (numLayers > 1) {
        desc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:mtlFormat
                                                                   width:baseWidth
                                                                  height:baseHeight
                                                               mipmapped:numLevels > 1];
        desc.textureType = MTLTextureType2DArray;
        desc.arrayLength = numLayers;
    } else {
        desc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:mtlFormat
                                                                   width:baseWidth
                                                                  height:baseHeight
                                                               mipmapped:numLevels > 1];
    }

    desc.usage = MTLTextureUsageShaderRead;
    desc.mipmapLevelCount = numLevels;

    // Create Metal texture
    id<MTLTexture> metalTexture = [Device::GetDevice() newTextureWithDescriptor:desc];
    if (!metalTexture) {
        NSLog(@"Failed to create Metal texture for: %s", path.c_str());
        ktxTexture_Destroy(texture);
        return nil;
    }

    metalTexture.label = [NSString stringWithUTF8String:path.c_str()];

    // Upload texture data to Metal
    // libktx provides image data in the correct layout
    for (ktx_uint32_t layer = 0; layer < numLayers; ++layer) {
        for (ktx_uint32_t face = 0; face < numFaces; ++face) {
            for (ktx_uint32_t level = 0; level < numLevels; ++level) {
                ktx_size_t offset;
                result = ktxTexture_GetImageOffset(texture, level, layer, face, &offset);
                if (result != KTX_SUCCESS) {
                    NSLog(@"Failed to get image offset for level %u: %s", level, path.c_str());
                    continue;
                }

                ktx_uint32_t width = std::max(1u, baseWidth >> level);
                ktx_uint32_t height = std::max(1u, baseHeight >> level);

                // Get the image data pointer
                ktx_uint8_t* imageData = ktxTexture_GetData(texture) + offset;

                // Calculate size and bytes per row
                ktx_size_t imageSize = ktxTexture_GetImageSize(texture, level);

                // For compressed formats, we need to calculate bytes per row differently
                ktx_uint32_t bytesPerRow;
                if (ktx2Texture->isCompressed) {
                    // For block-compressed formats, calculate blocks
                    ktx_uint32_t blockWidth = 6;
                    ktx_uint32_t blockHeight = 6;

                    ktx_uint32_t blocksWide = (width + blockWidth - 1) / blockWidth;
                    ktx_uint32_t bytesPerBlock = (ktx_uint32_t)(imageSize / ((height + blockHeight - 1) / blockHeight) / blocksWide);
                    bytesPerRow = blocksWide * bytesPerBlock;
                } else {
                    // For uncompressed formats
                    bytesPerRow = (ktx_uint32_t)(imageSize / height);
                }

                MTLRegion region = MTLRegionMake2D(0, 0, width, height);

                // Upload to the appropriate slice/face
                ktx_uint32_t slice = isCubemap ? face : layer;

                [metalTexture replaceRegion:region
                                mipmapLevel:level
                                      slice:slice
                                  withBytes:imageData
                                bytesPerRow:bytesPerRow
                              bytesPerImage:imageSize];
            }
        }
    }

    // Clean up
    ktxTexture_Destroy(texture);

    NSLog(@"Loaded KTX2 texture: %s (%ux%u, %u mip levels, %u layers, format: %u)",
          path.c_str(), baseWidth, baseHeight, numLevels, numLayers, vkFormat);

    return metalTexture;
}
