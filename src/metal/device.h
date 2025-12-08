#pragma once

#include <Metal/Metal.h>

class Device
{
public:
    static void SetDevice(id<MTLDevice> device);
    static id<MTLDevice> GetDevice();
private:
    static id<MTLDevice> m_Device;
};
