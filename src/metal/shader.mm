#include "Shader.h"
#include "Core/Logger.h"

#include <Metal/Metal.h>

id<MTLLibrary> ShaderLibrary::s_DefaultLibrary = nil;

void ShaderLibrary::Initialize(id<MTLDevice> device)
{
    s_DefaultLibrary = [device newDefaultLibrary];
    if (!s_DefaultLibrary) {
        LOG_ERROR("Failed to load default Metal library");
    }
}

id<MTLLibrary> ShaderLibrary::GetDefaultLibrary()
{
    return s_DefaultLibrary;
}

id<MTLFunction> ShaderLibrary::GetFunction(const std::string& name)
{
    if (!s_DefaultLibrary) {
        LOG_ERROR("Default library not initialized");
        return nil;
    }
    
    NSString* functionName = [NSString stringWithUTF8String:name.c_str()];
    id<MTLFunction> function = [s_DefaultLibrary newFunctionWithName:functionName];
    
    if (!function) {
        LOG_ERROR_FMT("Failed to find function: %s", name.c_str());
    }
    
    return function;
}