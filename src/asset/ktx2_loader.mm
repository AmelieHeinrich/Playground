#include "ktx2_loader.h"
#include "fs.h"
#include "metal/device.h"

#include <cstring>
#include <vector>

// KTX2 file format structures
// Based on https://registry.khronos.org/KTX/specs/2.0/ktx2.0.html

struct KTX2Header {
    uint8_t identifier[12];
    uint32_t vkFormat;
    uint32_t typeSize;
    uint32_t pixelWidth;
    uint32_t pixelHeight;
    uint32_t pixelDepth;
    uint32_t layerCount;
    uint32_t faceCount;
    uint32_t levelCount;
    uint32_t supercompressionScheme;

    uint32_t dfdByteOffset;
    uint32_t dfdByteLength;
    uint32_t kvdByteOffset;
    uint32_t kvdByteLength;
    uint64_t sgdByteOffset;
    uint64_t sgdByteLength;
};

struct KTX2LevelIndex {
    uint64_t byteOffset;
    uint64_t byteLength;
    uint64_t uncompressedByteLength;
};

// VkFormat values for ASTC
static const uint32_t VK_FORMAT_ASTC_4x4_UNORM_BLOCK = 157;
static const uint32_t VK_FORMAT_ASTC_5x4_UNORM_BLOCK = 158;
static const uint32_t VK_FORMAT_ASTC_5x5_UNORM_BLOCK = 159;
static const uint32_t VK_FORMAT_ASTC_6x5_UNORM_BLOCK = 160;
static const uint32_t VK_FORMAT_ASTC_6x6_UNORM_BLOCK = 161;
static const uint32_t VK_FORMAT_ASTC_8x5_UNORM_BLOCK = 162;
static const uint32_t VK_FORMAT_ASTC_8x6_UNORM_BLOCK = 163;
static const uint32_t VK_FORMAT_ASTC_8x8_UNORM_BLOCK = 164;
static const uint32_t VK_FORMAT_ASTC_10x5_UNORM_BLOCK = 165;
static const uint32_t VK_FORMAT_ASTC_10x6_UNORM_BLOCK = 166;
static const uint32_t VK_FORMAT_ASTC_10x8_UNORM_BLOCK = 167;
static const uint32_t VK_FORMAT_ASTC_10x10_UNORM_BLOCK = 168;
static const uint32_t VK_FORMAT_ASTC_12x10_UNORM_BLOCK = 169;
static const uint32_t VK_FORMAT_ASTC_12x12_UNORM_BLOCK = 170;

static MTLPixelFormat VkFormatToMTLPixelFormat(uint32_t vkFormat) {
    switch (vkFormat) {
        case VK_FORMAT_ASTC_4x4_UNORM_BLOCK:   return MTLPixelFormatASTC_4x4_LDR;
        case VK_FORMAT_ASTC_5x4_UNORM_BLOCK:   return MTLPixelFormatASTC_5x4_LDR;
        case VK_FORMAT_ASTC_5x5_UNORM_BLOCK:   return MTLPixelFormatASTC_5x5_LDR;
        case VK_FORMAT_ASTC_6x5_UNORM_BLOCK:   return MTLPixelFormatASTC_6x5_LDR;
        case VK_FORMAT_ASTC_6x6_UNORM_BLOCK:   return MTLPixelFormatASTC_6x6_LDR;
        case VK_FORMAT_ASTC_8x5_UNORM_BLOCK:   return MTLPixelFormatASTC_8x5_LDR;
        case VK_FORMAT_ASTC_8x6_UNORM_BLOCK:   return MTLPixelFormatASTC_8x6_LDR;
        case VK_FORMAT_ASTC_8x8_UNORM_BLOCK:   return MTLPixelFormatASTC_8x8_LDR;
        case VK_FORMAT_ASTC_10x5_UNORM_BLOCK:  return MTLPixelFormatASTC_10x5_LDR;
        case VK_FORMAT_ASTC_10x6_UNORM_BLOCK:  return MTLPixelFormatASTC_10x6_LDR;
        case VK_FORMAT_ASTC_10x8_UNORM_BLOCK:  return MTLPixelFormatASTC_10x8_LDR;
        case VK_FORMAT_ASTC_10x10_UNORM_BLOCK: return MTLPixelFormatASTC_10x10_LDR;
        case VK_FORMAT_ASTC_12x10_UNORM_BLOCK: return MTLPixelFormatASTC_12x10_LDR;
        case VK_FORMAT_ASTC_12x12_UNORM_BLOCK: return MTLPixelFormatASTC_12x12_LDR;
        default: return MTLPixelFormatInvalid;
    }
}

static void GetBlockDimensions(uint32_t vkFormat, uint32_t& blockWidth, uint32_t& blockHeight) {
    switch (vkFormat) {
        case VK_FORMAT_ASTC_4x4_UNORM_BLOCK:   blockWidth = 4;  blockHeight = 4;  break;
        case VK_FORMAT_ASTC_5x4_UNORM_BLOCK:   blockWidth = 5;  blockHeight = 4;  break;
        case VK_FORMAT_ASTC_5x5_UNORM_BLOCK:   blockWidth = 5;  blockHeight = 5;  break;
        case VK_FORMAT_ASTC_6x5_UNORM_BLOCK:   blockWidth = 6;  blockHeight = 5;  break;
        case VK_FORMAT_ASTC_6x6_UNORM_BLOCK:   blockWidth = 6;  blockHeight = 6;  break;
        case VK_FORMAT_ASTC_8x5_UNORM_BLOCK:   blockWidth = 8;  blockHeight = 5;  break;
        case VK_FORMAT_ASTC_8x6_UNORM_BLOCK:   blockWidth = 8;  blockHeight = 6;  break;
        case VK_FORMAT_ASTC_8x8_UNORM_BLOCK:   blockWidth = 8;  blockHeight = 8;  break;
        case VK_FORMAT_ASTC_10x5_UNORM_BLOCK:  blockWidth = 10; blockHeight = 5;  break;
        case VK_FORMAT_ASTC_10x6_UNORM_BLOCK:  blockWidth = 10; blockHeight = 6;  break;
        case VK_FORMAT_ASTC_10x8_UNORM_BLOCK:  blockWidth = 10; blockHeight = 8;  break;
        case VK_FORMAT_ASTC_10x10_UNORM_BLOCK: blockWidth = 10; blockHeight = 10; break;
        case VK_FORMAT_ASTC_12x10_UNORM_BLOCK: blockWidth = 12; blockHeight = 10; break;
        case VK_FORMAT_ASTC_12x12_UNORM_BLOCK: blockWidth = 12; blockHeight = 12; break;
        default: blockWidth = 1; blockHeight = 1; break;
    }
}

id<MTLTexture> KTX2Loader::LoadKTX2(const std::string& path)
{
    auto file = fs::LoadBinaryFile(path);
    if (!file.success) {
        NSLog(@"Failed to load KTX2 file: %s", file.error.c_str());
        return nil;
    }

    uint8_t* fileData = file.data.data();
    uint64_t fileSize = file.data.size();

    if (fileSize < sizeof(KTX2Header)) {
        NSLog(@"KTX2 file too small: %s", path.c_str());
        return nil;
    }

    // Parse header
    KTX2Header header;
    memcpy(&header, fileData, sizeof(KTX2Header));

    // Validate KTX2 identifier
    const uint8_t ktx2Identifier[12] = {
        0xAB, 0x4B, 0x54, 0x58, 0x20, 0x32, 0x30, 0xBB, 0x0D, 0x0A, 0x1A, 0x0A
    };

    if (memcmp(header.identifier, ktx2Identifier, 12) != 0) {
        NSLog(@"Invalid KTX2 identifier: %s", path.c_str());
        return nil;
    }

    // Check for supercompression (we don't support it)
    if (header.supercompressionScheme != 0) {
        NSLog(@"KTX2 supercompression not supported: %s", path.c_str());
        return nil;
    }

    // Convert VkFormat to Metal format
    MTLPixelFormat format = VkFormatToMTLPixelFormat(header.vkFormat);
    if (format == MTLPixelFormatInvalid) {
        NSLog(@"Unsupported VkFormat %u in KTX2 file: %s", header.vkFormat, path.c_str());
        return nil;
    }

    uint32_t blockWidth, blockHeight;
    GetBlockDimensions(header.vkFormat, blockWidth, blockHeight);

    // Read level index array
    std::vector<KTX2LevelIndex> levelIndices(header.levelCount);
    size_t levelIndexOffset = sizeof(KTX2Header);
    memcpy(levelIndices.data(), fileData + levelIndexOffset, sizeof(KTX2LevelIndex) * header.levelCount);
    
    // Note: KTX2LevelIndex.byteOffset is relative to the start of the file, per spec.

    // Create texture descriptor
    MTLTextureDescriptor* desc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:format
                                                                                     width:header.pixelWidth
                                                                                    height:header.pixelHeight
                                                                                 mipmapped:header.levelCount > 1];
    desc.usage = MTLTextureUsageShaderRead;
    desc.mipmapLevelCount = header.levelCount;

    id<MTLTexture> texture = [Device::GetDevice() newTextureWithDescriptor:desc];
    texture.label = [NSString stringWithUTF8String:path.c_str()];

    // Upload all mip levels
    // KTX2 stores levels from smallest to largest (reverse of Metal's expectation)
    for (uint32_t mipLevel = 0; mipLevel < header.levelCount; ++mipLevel) {
        // Read from the end of the level array (smallest mip is at index 0, largest is at end)
        uint32_t ktx2Index = header.levelCount - 1 - mipLevel;
        const KTX2LevelIndex& levelIndex = levelIndices[ktx2Index];

        uint32_t width = std::max(1u, header.pixelWidth >> mipLevel);
        uint32_t height = std::max(1u, header.pixelHeight >> mipLevel);

        // Calculate blocks and bytes per row
        uint32_t blocksX = (width + blockWidth - 1) / blockWidth;
        uint32_t blocksY = (height + blockHeight - 1) / blockHeight;
        uint32_t expectedSize = blocksX * blocksY * 16; // ASTC blocks are always 16 bytes

        // Verify the data size matches
        if (levelIndex.byteLength != expectedSize) {
            NSLog(@"Warning: Mip level %u size mismatch. Expected %u, got %llu",
                  mipLevel, expectedSize, levelIndex.byteLength);
        }

        // Verify offset is within file
        if (levelIndex.byteOffset + levelIndex.byteLength > fileSize) {
            NSLog(@"Error: Mip level %u data exceeds file size", mipLevel);
            return nil;
        }

        MTLRegion region = {
            {0, 0, 0},
            {width, height, 1}
        };

        // byteOffset is relative to the start of the file, per spec
        const uint8_t* mipData = fileData + levelIndex.byteOffset;

        // For compressed formats, bytesPerRow is the number of bytes per row of blocks
        [texture replaceRegion:region
                  mipmapLevel:mipLevel
                    withBytes:mipData
                  bytesPerRow:blocksX * 16];

        NSLog(@"Uploaded mip %u (ktx2Index=%u): %ux%u (%ux%u blocks, %llu bytes at offset %llu, expected %u bytes)",
              mipLevel, ktx2Index, width, height, blocksX, blocksY, levelIndex.byteLength, levelIndex.byteOffset, expectedSize);
    }

    NSLog(@"Loaded KTX2 texture: %s (%ux%u, %u mip levels)",
          path.c_str(), header.pixelWidth, header.pixelHeight, header.levelCount);

    return texture;
}