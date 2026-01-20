#include "AstcLoader.h"
#include "Mipmapper.h"
#include "Fs.h"
#include "Core/Logger.h"

#include <Metal/Device.h>
#include <cmath>

struct AstcHeader {
    uint8_t magic[4];
    uint8_t blockDimX, blockDimY, blockDimZ;
    uint32_t dimX, dimY, dimZ;
};

static uint32_t read24(const uint8_t* p) {
    return (uint32_t)p[0] | ((uint32_t)p[1] << 8) | ((uint32_t)p[2] << 16);
}

API_AVAILABLE(macos(15.0))
static MTLPixelFormat astcToPixelFormat(uint8_t bx, uint8_t by) {
    if (bx == 4  && by == 4)  return MTLPixelFormatASTC_4x4_LDR;
    if (bx == 5  && by == 4)  return MTLPixelFormatASTC_5x4_LDR;
    if (bx == 5  && by == 5)  return MTLPixelFormatASTC_5x5_LDR;
    if (bx == 6  && by == 5)  return MTLPixelFormatASTC_6x5_LDR;
    if (bx == 6  && by == 6)  return MTLPixelFormatASTC_6x6_LDR;
    if (bx == 8  && by == 5)  return MTLPixelFormatASTC_8x5_LDR;
    if (bx == 8  && by == 6)  return MTLPixelFormatASTC_8x6_LDR;
    if (bx == 8  && by == 8)  return MTLPixelFormatASTC_8x8_LDR;
    if (bx == 10 && by == 5)  return MTLPixelFormatASTC_10x5_LDR;
    if (bx == 10 && by == 6)  return MTLPixelFormatASTC_10x6_LDR;
    if (bx == 10 && by == 8)  return MTLPixelFormatASTC_10x8_LDR;
    if (bx == 10 && by == 10) return MTLPixelFormatASTC_10x10_LDR;
    if (bx == 12 && by == 10) return MTLPixelFormatASTC_12x10_LDR;
    if (bx == 12 && by == 12) return MTLPixelFormatASTC_12x12_LDR;

    return MTLPixelFormatInvalid;
}

static uint32_t CalculateMipLevels(uint32_t width, uint32_t height) {
    uint32_t levels = 1;
    uint32_t dimension = std::max(width, height);
    
    while (dimension > 1) {
        dimension >>= 1;
        levels++;
    }
    
    return levels;
}

API_AVAILABLE(macos(15.0))
id<MTLTexture> ASTCLoader::LoadASTC(const std::string& path)
{
    auto file = fs::LoadBinaryFile(path);
    if (!file.success) {
        LOG_ERROR_FMT("Failed to load ASTC file: %s", file.error.c_str());
        return nil;
    }

    uint8_t* fileData = file.data.data();
    uint64_t fileSize = file.data.size();

    if (fileSize < 16) {
        LOG_ERROR_FMT("ASTC file too small: %s", path.c_str());
        return nil;
    }

    // Parse header
    AstcHeader header;
    memcpy(&header.magic, fileData, 4);
    header.blockDimX = fileData[4];
    header.blockDimY = fileData[5];
    header.blockDimZ = fileData[6];
    header.dimX = read24(fileData + 7);
    header.dimY = read24(fileData + 10);
    header.dimZ = read24(fileData + 13);

    // Validate magic number
    if (header.magic[0] != 0x13 || header.magic[1] != 0xAB ||
        header.magic[2] != 0xA1 || header.magic[3] != 0x5C) {
        LOG_ERROR_FMT("Invalid ASTC magic number in file: %s", path.c_str());
        return nil;
    }

    MTLPixelFormat format = astcToPixelFormat(header.blockDimX, header.blockDimY);
    if (format == MTLPixelFormatInvalid) {
        LOG_ERROR_FMT("Unsupported ASTC block size %ux%u", header.blockDimX, header.blockDimY);
        return nil;
    }

    uint32_t width  = header.dimX;
    uint32_t height = header.dimY;

    // Calculate number of mip levels
    uint32_t mipCount = CalculateMipLevels(width, height);

    // Calculate the size of the base mip level
    uint32_t blocksX = (width + header.blockDimX - 1) / header.blockDimX;
    uint32_t blocksY = (height + header.blockDimY - 1) / header.blockDimY;
    size_t baseMipSize = blocksX * blocksY * 16; // ASTC blocks are always 16 bytes

    // Verify we have enough data for the base mip
    if (fileSize < 16 + baseMipSize) {
        LOG_ERROR_FMT("ASTC file doesn't contain enough data for base mip: %s", path.c_str());
        return nil;
    }

    // Create Metal texture descriptor with mipmaps
    MTLTextureDescriptor *desc =
        [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:format
                                                           width:width
                                                          height:height
                                                       mipmapped:YES];
    desc.usage = MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite;
    desc.mipmapLevelCount = mipCount;

    id<MTLTexture> texture = [Device::GetDevice() newTextureWithDescriptor:desc];
    texture.label = [NSString stringWithFormat:@"%s", path.c_str()];

    // Upload base mip level (level 0)
    uint32_t bytesPerRow = blocksX * 16;
    MTLRegion region = {
        {0, 0, 0},
        {width, height, 1}
    };

    [texture replaceRegion:region
              mipmapLevel:0
                withBytes:fileData + 16
              bytesPerRow:bytesPerRow];

    // Request mipmap generation
    Mipmapper::RequestMipmaps(texture);

    LOG_INFO_FMT("Loaded ASTC texture: %s (%ux%u, %u mip levels requested)", 
          path.c_str(), width, height, mipCount);

    return texture;
}
