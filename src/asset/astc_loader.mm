#include "astc_loader.h"
#include "fs.h"

#include <metal/device.h>

struct AstcHeader {
    uint8_t magic[4];
    uint8_t blockDimX, blockDimY, blockDimZ;
    uint32_t dimX, dimY, dimZ;
};

static uint32_t read24(const uint8_t* p) {
    return (uint32_t)p[0] | ((uint32_t)p[1] << 8) | ((uint32_t)p[2] << 16);
}

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

id<MTLTexture> ASTCLoader::LoadASTC(const std::string& path)
{
    auto file = fs::LoadBinaryFile(path);
    if (!file.success) {
        NSLog(@"Failed to load ASTC file: %s", file.error.c_str());
        return nil;
    }
    
    uint8_t* fileData = file.data.data();
    uint64_t fileSize = file.data.size();

    // Parse header
    AstcHeader header;
    memcpy(&header.magic, fileData, 4);
    header.blockDimX = fileData[4];
    header.blockDimY = fileData[5];
    header.blockDimZ = fileData[6];
    header.dimX = read24(fileData + 7);
    header.dimY = read24(fileData + 10);
    header.dimZ = read24(fileData + 13);

    MTLPixelFormat format = astcToPixelFormat(header.blockDimX, header.blockDimY);
    if (format == MTLPixelFormatInvalid) return nil;

    uint32_t width  = header.dimX;
    uint32_t height = header.dimY;

    // Assume file contains mips sequentially
    // Compute how many mips until the data ends
    std::vector<size_t> mipOffsets;
    std::vector<size_t> mipSizes;

    size_t offset = 16;
    uint32_t w = width, h = height;

    while (offset < fileSize) {
        uint32_t blocksX = (w + header.blockDimX - 1) / header.blockDimX;
        uint32_t blocksY = (h + header.blockDimY - 1) / header.blockDimY;

        size_t mipSize = blocksX * blocksY * 16;

        mipOffsets.push_back(offset);
        mipSizes.push_back(mipSize);

        offset += mipSize;

        // Next mip
        w = std::max(1u, w >> 1);
        h = std::max(1u, h >> 1);
        if (w == 1 && h == 1) break;
    }

    NSUInteger mipCount = mipOffsets.size();

    // --- Create Metal texture ---
    MTLTextureDescriptor *desc =
        [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:format
                                                           width:width
                                                          height:height
                                                       mipmapped:(mipCount > 1)];
    desc.usage = MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite;

    id<MTLTexture> texture = [Device::GetDevice() newTextureWithDescriptor:desc];

    // Upload mips
    for (NSUInteger mip = 0; mip < mipCount; ++mip) {
        w = std::max(1u, width  >> mip);
        h = std::max(1u, height >> mip);

        // Calculate bytes per row for compressed format
        uint32_t blocksX = (w + header.blockDimX - 1) / header.blockDimX;
        uint32_t bytesPerRow = blocksX * 16; // ASTC blocks are always 16 bytes

        MTLRegion region = {
            {0,0,0},
            {w,h,1}
        };

        [texture replaceRegion:region
                  mipmapLevel:mip
                    withBytes:fileData + mipOffsets[mip]
                  bytesPerRow:bytesPerRow];
    }

    return texture;
}
