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

#endif
