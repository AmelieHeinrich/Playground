// graphics_pipeline.h

#pragma once

#import <Metal/Metal.h>

#include <string>
#include <vector>

struct GraphicsPipelineDesc
{
    std::string Path;

    bool EnableBlend = false;
    std::vector<MTLPixelFormat> ColorFormats = {};

    MTLPixelFormat DepthFormat = MTLPixelFormatInvalid;
    bool DepthEnabled = false;
    MTLCompareFunction DepthFunc = MTLCompareFunctionNever;
};

class GraphicsPipeline
{
public:
    GraphicsPipeline() = default;
    ~GraphicsPipeline() = default;

    static GraphicsPipeline Create(const GraphicsPipelineDesc& desc);

    id<MTLRenderPipelineState> GetPipelineState() const { return m_PipelineState; }
    id<MTLDepthStencilState> GetDepthStencilState() const { return m_DepthStencilState; }

    GraphicsPipelineDesc GetDesc() { return m_Desc; };
private:
    id<MTLRenderPipelineState> m_PipelineState;
    id<MTLDepthStencilState> m_DepthStencilState;

    GraphicsPipelineDesc m_Desc;
};
