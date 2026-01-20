#include "sky_loader.h"
#include "stb_image.h"
#include "fs.h"
#include "metal/device.h"
#include "metal/compute_pipeline.h"
#include "metal/command_buffer.h"
#include "metal/compute_encoder.h"

#include <cmath>

struct SkyLoaderParams {
    uint32_t cubemapSize;
    uint32_t face;
};

Texture* SkyLoader::LoadSky(const std::string& path)
{
    // Resolve path for macOS bundle and load file into memory
    std::string resolvedPath = fs::ResolvePath(path);
    auto file = fs::LoadBinaryFile(resolvedPath);
    if (!file.success) {
        NSLog(@"[SkyLoader] Failed to load HDR file: %s - %s", path.c_str(), file.error.c_str());
        return nullptr;
    }

    // Load HDR image from memory using STB
    int width, height, channels;
    float* hdrData = stbi_loadf_from_memory(file.data.data(), (int)file.data.size(), &width, &height, &channels, 4); // Force RGBA

    if (!hdrData) {
        NSLog(@"[SkyLoader] Failed to parse HDR file: %s", path.c_str());
        return nullptr;
    }

    NSLog(@"[SkyLoader] Loaded HDR: %s (%dx%d, %d channels)", path.c_str(), width, height, channels);

    // Create the equirectangular texture (2D, FP32 RGBA)
    MTLTextureDescriptor* equirectDesc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA32Float
                                                                                            width:width
                                                                                           height:height
                                                                                        mipmapped:NO];
    equirectDesc.usage = MTLTextureUsageShaderRead;
    equirectDesc.storageMode = MTLStorageModeShared;

    id<MTLTexture> equirectTexture = [Device::GetDevice() newTextureWithDescriptor:equirectDesc];
    equirectTexture.label = @"Equirectangular HDR";

    // Upload HDR data to equirectangular texture
    MTLRegion region = MTLRegionMake2D(0, 0, width, height);
    [equirectTexture replaceRegion:region
                       mipmapLevel:0
                         withBytes:hdrData
                       bytesPerRow:width * 4 * sizeof(float)];

    // Free STB image data
    stbi_image_free(hdrData);

    // Determine cubemap size (typically half the width for equirectangular)
    uint32_t cubemapSize = width / 4;
    // Clamp to reasonable range and ensure power of 2
    cubemapSize = std::max(64u, std::min(cubemapSize, 2048u));
    // Round to nearest power of 2
    uint32_t pow2Size = 1;
    while (pow2Size < cubemapSize) {
        pow2Size <<= 1;
    }
    cubemapSize = pow2Size;

    NSLog(@"[SkyLoader] Creating cubemap: %ux%u per face", cubemapSize, cubemapSize);

    // Create the output cubemap texture
    MTLTextureDescriptor* cubemapDesc = [MTLTextureDescriptor textureCubeDescriptorWithPixelFormat:MTLPixelFormatRGBA32Float
                                                                                              size:cubemapSize
                                                                                         mipmapped:NO];
    cubemapDesc.usage = MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite;
    cubemapDesc.storageMode = MTLStorageModePrivate;

    Texture* cubemap = new Texture(cubemapDesc);
    cubemap->SetLabel(@"Sky Cubemap");

    // Create a 2D array view for writing (Metal compute shaders can't write directly to cubemaps)
    MTLTextureDescriptor* arrayDesc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA32Float
                                                                                         width:cubemapSize
                                                                                        height:cubemapSize
                                                                                     mipmapped:NO];
    arrayDesc.textureType = MTLTextureType2DArray;
    arrayDesc.arrayLength = 6;
    arrayDesc.usage = MTLTextureUsageShaderWrite;
    arrayDesc.storageMode = MTLStorageModePrivate;

    // Create a texture view of the cubemap as a 2D array for writing
    id<MTLTexture> cubemapArrayView = [cubemap->GetTexture() newTextureViewWithPixelFormat:MTLPixelFormatRGBA32Float
                                                                               textureType:MTLTextureType2DArray
                                                                                    levels:NSMakeRange(0, 1)
                                                                                    slices:NSMakeRange(0, 6)];
    cubemapArrayView.label = @"Sky Cubemap Array View";

    // Create compute pipeline for equirectangular to cubemap conversion
    ComputePipeline skyLoaderPipeline;
    skyLoaderPipeline.Initialize("sky_loader");

    // Create command buffer for conversion
    id<MTLCommandBuffer> cmdBuffer = [Device::GetCommandQueue() commandBuffer];
    cmdBuffer.label = @"Sky Loader";

    // Dispatch compute shader for each face
    id<MTLComputeCommandEncoder> encoder = [cmdBuffer computeCommandEncoder];
    encoder.label = @"Equirectangular to Cubemap";

    [encoder setComputePipelineState:skyLoaderPipeline.GetPipelineState()];
    [encoder setTexture:equirectTexture atIndex:0];
    [encoder setTexture:cubemapArrayView atIndex:1];

    MTLSize threadgroupSize = MTLSizeMake(8, 8, 1);
    MTLSize numThreadgroups = MTLSizeMake((cubemapSize + 7) / 8, (cubemapSize + 7) / 8, 1);

    for (uint32_t face = 0; face < 6; ++face) {
        SkyLoaderParams params;
        params.cubemapSize = cubemapSize;
        params.face = face;

        [encoder setBytes:&params length:sizeof(params) atIndex:0];
        [encoder dispatchThreadgroups:numThreadgroups threadsPerThreadgroup:threadgroupSize];
    }

    [encoder endEncoding];
    [cmdBuffer commit];
    [cmdBuffer waitUntilCompleted];

    NSLog(@"[SkyLoader] Successfully created sky cubemap from: %s", path.c_str());

    return cubemap;
}
