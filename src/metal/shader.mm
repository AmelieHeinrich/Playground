#include "shader.h"
#include "fs.h"

#include <fstream>
#include <sstream>

static const std::unordered_map<std::string, ShaderStage> ENTRY_POINT_MAP = {
    {"vs_main", ShaderStage::VERTEX},
    {"fs_main", ShaderStage::FRAGMENT},
    {"cs_main", ShaderStage::COMPUTE},
    {"ms_main", ShaderStage::MESH},
    {"rhit_main", ShaderStage::CLOSEST_HIT},
    {"miss_main", ShaderStage::MISS},
    {"rgen_main", ShaderStage::RAY_GENERATION},
    {"ahit_main", ShaderStage::ANY_HIT}
};

Shader ShaderCompiler::Compile(id<MTLDevice> device, const std::string& path, ShaderType type)
{
    fs::StringResult res = fs::LoadTextFile(path);
    if (!res.success) {
        NSLog(@"Failed to load shader file: %s (err: %s)", path.c_str(), res.error.c_str());
        return Shader();
    }

    std::string source = res.data;
    NSString* nsSource = [NSString stringWithUTF8String:source.c_str()];

    MTLCompileOptions* options = [[MTLCompileOptions alloc] init];
    if (@available(iOS 16.0, *)) {
        options.languageVersion = MTLLanguageVersion3_0;
    } else {
        options.languageVersion = MTLLanguageVersion2_0;
    }

    NSError* error = nil;
    id<MTLLibrary> library = [device newLibraryWithSource:nsSource
                                     options:options
                                     error:&error];
    if (!library) {
        NSLog(@"Failed to compile shader: %@", error.localizedDescription);
        return Shader();
    }

    Shader shader;
    shader.Type = type;
    shader.Library = library;

    // Detect available entry points and populate AvailableModules
    NSArray<NSString*>* functionNames = [library functionNames];
    for (NSString* functionName in functionNames) {
        std::string entryPoint = [functionName UTF8String];
        
        // Check if this is a known entry point
        auto it = ENTRY_POINT_MAP.find(entryPoint);
        if (it != ENTRY_POINT_MAP.end()) {
            ShaderStage stage = it->second;
            id<MTLFunction> function = [library newFunctionWithName:functionName];
            
            if (function) {
                ShaderModule module;
                module.Stage = stage;
                module.Function = function;
                module.EntryPoint = entryPoint;
                
                shader.AvailableModules[stage] = module;
                
                NSLog(@"Found shader entry point: %s (stage: %d)", entryPoint.c_str(), static_cast<int>(stage));
            }
        }
    }

    if (shader.AvailableModules.empty()) {
        NSLog(@"Warning: No recognized entry points found in shader %s", path.c_str());
    }

    return shader;
}
