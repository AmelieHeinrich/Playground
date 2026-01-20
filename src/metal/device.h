#pragma once

#include "Metal/ResidencySet.h"
#include <Metal/Metal.h>

class Device
{
public:
    static void SetDevice(id<MTLDevice> device);
    static void SetCommandQueue(id<MTLCommandQueue> commandQueue);
    static void SetResidencySet(ResidencySet* residencySet);

    static id<MTLDevice> GetDevice();
    static id<MTLCommandQueue> GetCommandQueue();
    static ResidencySet& GetResidencySet();
private:
    static id<MTLDevice> m_Device;
    static id<MTLCommandQueue> m_CommandQueue;
    static ResidencySet* m_ResidencySet;
};
