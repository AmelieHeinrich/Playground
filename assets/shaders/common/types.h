#ifndef TYPES_METAL_H
#define TYPES_METAL_H

#if defined(IOS)
    #define ahFloat float
    #define ahVec2 float2
    #define ahVec3 float3
    #define ahVec4 float4
#else
    #define ahFloat float
    #define ahVec2 float2
    #define ahVec3 float3
    #define ahVec4 float4
#endif

#endif // TYPES_METAL_H
