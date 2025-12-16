#ifndef CLUSTER_H
#define CLUSTER_H

#include <simd/simd.h>
using namespace simd;

#define MAX_LIGHTS_PER_CLUSTER 256

struct Cluster
{
    float4 Min;
    float4 Max;
};

#endif
