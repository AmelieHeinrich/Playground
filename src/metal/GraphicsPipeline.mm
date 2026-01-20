#include "GraphicsPipeline.h"
#include "Device.h"
#include "Metal/Shader.h"
#include "Core/Logger.h"

#include <Foundation/Foundation.h>
#include <Metal/Metal.h>

GraphicsPipeline GraphicsPipeline::Create(const GraphicsPipelineDesc& desc)
{
    @autoreleasepool {
        GraphicsPipeline pipeline;
        pipeline.m_Desc = desc;

        // Get functions from default library
        if (!desc.VertexFunctionName.empty()) {
            pipeline.m_VertexFunction = ShaderLibrary::GetFunction(desc.VertexFunctionName);
        }
        if (!desc.FragmentFunctionName.empty()) {
            pipeline.m_FragmentFunction = ShaderLibrary::GetFunction(desc.FragmentFunctionName);
        }

        MTLRenderPipelineDescriptor* descriptor = [MTLRenderPipelineDescriptor new];
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

            MTLDepthStencilDescriptor* depthStencilDescriptor = [MTLDepthStencilDescriptor new];
            depthStencilDescriptor.depthCompareFunction = desc.DepthFunc;
            depthStencilDescriptor.depthWriteEnabled = desc.DepthWriteEnabled ? YES : NO;

            pipeline.m_DepthStencilState = [Device::GetDevice() newDepthStencilStateWithDescriptor:depthStencilDescriptor];
        }
        NSString* label = [NSString stringWithFormat:@"%s %s",
                          desc.VertexFunctionName.c_str(),
                          desc.FragmentFunctionName.c_str()];
        descriptor.label = label;

        NSError* error = nil;
        pipeline.m_PipelineState = [Device::GetDevice() newRenderPipelineStateWithDescriptor:descriptor error:&error];
        if (!pipeline.m_PipelineState) {
            LOG_ERROR_FMT("Failed to create pipeline state: %@", error);
        }

        return pipeline;
    }
}
