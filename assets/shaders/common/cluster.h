#ifndef CLUSTER_H
#define CLUSTER_H

#include <simd/simd.h>
using namespace simd;

struct Cluster
{
    float4 Min;
    float4 Max;
};

#endif
