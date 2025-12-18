#ifndef LIGHT_H
#define LIGHT_H

#include <simd/simd.h>

struct PointLight
{
    float3 Position;
    float Radius;
    
    float3 Color;
    float Intensity;
};

struct DirectionalLight
{
    bool Enabled;
    float3 Direction;
    
    float Intensity;
    float3 Color;
};

#endif
