#include "graphics_pipeline.h"
#include "device.h"
#include "metal/shader.h"

#include <Foundation/Foundation.h>
#include <Metal/Metal.h>

GraphicsPipeline GraphicsPipeline::Create(const GraphicsPipelineDesc& desc)
{
    GraphicsPipeline pipeline;
    pipeline.m_Desc = desc;

    Shader shader = ShaderCompiler::Compile(Device::GetDevice(), desc.Path, ShaderType::GRAPHICS);

    MTLRenderPipelineDescriptor* descriptor = [[MTLRenderPipelineDescriptor alloc] init];
    if (shader.HasStage(ShaderStage::VERTEX)) pipeline.m_VertexFunction = shader.GetFunction(ShaderStage::VERTEX);
    if (shader.HasStage(ShaderStage::FRAGMENT)) pipeline.m_FragmentFunction = shader.GetFunction(ShaderStage::FRAGMENT);
    if (desc.SupportsIndirect) descriptor.supportIndirectCommandBuffers = YES;

    descriptor.vertexFunction = pipeline.m_VertexFunction;
    if (pipeline.m_FragmentFunction) descriptor.fragmentFunction = pipeline.m_FragmentFunction;
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
    descriptor.label = [NSString stringWithUTF8String:desc.Path.c_str()];

    NSError* error = nil;
    pipeline.m_PipelineState = [Device::GetDevice() newRenderPipelineStateWithDescriptor:descriptor error:&error];
    if (!pipeline.m_PipelineState) {
        NSLog(@"Failed to create pipeline state: %@", error);
    }

    return pipeline;
}
