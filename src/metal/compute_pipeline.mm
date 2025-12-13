#include "compute_pipeline.h"
#include "device.h"
#include "shader.h"

ComputePipeline::ComputePipeline(const std::string& shaderName, bool supportsIndirect)
{
    Initialize(shaderName, supportsIndirect);
}

void ComputePipeline::Initialize(const std::string& shaderName, bool supportsIndirect)
{
    Shader shader = ShaderCompiler::Compile(Device::GetDevice(), shaderName, ShaderType::COMPUTE);

    MTLComputePipelineDescriptor* descriptor = [[MTLComputePipelineDescriptor alloc] init];
    if (supportsIndirect) descriptor.supportIndirectCommandBuffers = YES;
    descriptor.computeFunction = shader.GetFunction(ShaderStage::COMPUTE);
    descriptor.label = [NSString stringWithUTF8String:shaderName.c_str()];

    NSError* error = nil;
    m_PipelineState = [Device::GetDevice() newComputePipelineStateWithDescriptor:descriptor options:MTLPipelineOptionNone reflection:nil error:&error];
    if (error) {
        NSLog(@"Error creating compute pipeline state: %@", error);
    }
}
