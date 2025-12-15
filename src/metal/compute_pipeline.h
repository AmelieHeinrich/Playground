#pragma once

#import <Metal/Metal.h>

#include <string>

class ComputePipeline
{
public:
    ComputePipeline() = default;
    ComputePipeline(const std::string& functionName, bool supportsIndirect = false);
    ~ComputePipeline() = default;

    void Initialize(const std::string& functionName, bool supportsIndirect = false);

    id<MTLComputePipelineState> GetPipelineState() const { return m_PipelineState; }
    id<MTLFunction> GetComputeFunction() const { return m_ComputeFunction; }
private:
    id<MTLComputePipelineState> m_PipelineState;
    id<MTLFunction> m_ComputeFunction;
};
