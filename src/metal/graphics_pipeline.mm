#include "graphics_pipeline.h"
#include "device.h"
#include "metal/shader.h"

#include <Foundation/Foundation.h>
#include <Metal/Metal.h>

GraphicsPipeline GraphicsPipeline::Create(const GraphicsPipelineDesc& desc)
{
    GraphicsPipeline pipeline;

    Shader shader = ShaderCompiler::Compile(Device::GetDevice(), desc.Path, ShaderType::GRAPHICS);

    MTLRenderPipelineDescriptor* descriptor = [[MTLRenderPipelineDescriptor alloc] init];
    if (shader.HasStage(ShaderStage::VERTEX)) descriptor.vertexFunction = shader.GetFunction(ShaderStage::VERTEX);
    if (shader.HasStage(ShaderStage::FRAGMENT)) descriptor.fragmentFunction = shader.GetFunction(ShaderStage::FRAGMENT);
    descriptor.supportIndirectCommandBuffers = YES;

    for (int i = 0; i < desc.ColorFormats.size(); ++i) {
        descriptor.colorAttachments[i].pixelFormat = desc.ColorFormats[i];
        if (desc.EnableBlend) {
            descriptor.colorAttachments[i].blendingEnabled = YES;
            descriptor.colorAttachments[i].rgbBlendOperation = MTLBlendOperationAdd;
            descriptor.colorAttachments[i].alphaBlendOperation = MTLBlendOperationAdd;
            descriptor.colorAttachments[i].sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
            descriptor.colorAttachments[i].sourceAlphaBlendFactor = MTLBlendFactorSourceAlpha;
            descriptor.colorAttachments[i].destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
            descriptor.colorAttachments[i].destinationAlphaBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
        }
    }

    if (desc.DepthEnabled) {
        descriptor.depthAttachmentPixelFormat = desc.DepthFormat;

        MTLDepthStencilDescriptor* depthStencilDescriptor = [[MTLDepthStencilDescriptor alloc] init];
        depthStencilDescriptor.depthCompareFunction = desc.DepthFunc;
        depthStencilDescriptor.depthWriteEnabled = YES;

        pipeline.m_DepthStencilState = [Device::GetDevice() newDepthStencilStateWithDescriptor:depthStencilDescriptor];
    }

    NSError* error = nil;
    pipeline.m_PipelineState = [Device::GetDevice() newRenderPipelineStateWithDescriptor:descriptor error:&error];

    if (!pipeline.m_PipelineState) {
        NSLog(@"Failed to create pipeline state: %@", error);
    }

    return pipeline;
}
