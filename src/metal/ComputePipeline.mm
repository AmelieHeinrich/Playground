#include "ComputePipeline.h"
#include "Device.h"
#include "Shader.h"
#include "Core/Logger.h"

ComputePipeline::ComputePipeline(const std::string& functionName, bool supportsIndirect)
{
    Initialize(functionName, supportsIndirect);
}

void ComputePipeline::Initialize(const std::string& functionName, bool supportsIndirect)
{
    @autoreleasepool {
        // Get function from default library
        m_ComputeFunction = ShaderLibrary::GetFunction(functionName);
        
        if (!m_ComputeFunction) {
            LOG_ERROR_FMT("Failed to find compute function: %s", functionName.c_str());
            return;
        }

        MTLComputePipelineDescriptor* descriptor = [MTLComputePipelineDescriptor new];
        if (supportsIndirect) descriptor.supportIndirectCommandBuffers = YES;
        descriptor.computeFunction = m_ComputeFunction;
        descriptor.label = [NSString stringWithUTF8String:functionName.c_str()];

        NSError* error = nil;
        m_PipelineState = [Device::GetDevice() newComputePipelineStateWithDescriptor:descriptor options:MTLPipelineOptionNone reflection:nil error:&error];
        if (error) {
            LOG_ERROR_FMT("Error creating compute pipeline state: %@", error);
        }
    }
}