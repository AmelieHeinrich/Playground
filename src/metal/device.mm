#include "device.h"
#include <Metal/Metal.h>

id<MTLDevice> Device::m_Device;
id<MTLCommandQueue> Device::m_CommandQueue;
ResidencySet* Device::m_ResidencySet;

void Device::SetCommandQueue(id<MTLCommandQueue> commandQueue)
{
    m_CommandQueue = commandQueue;
}

void Device::SetResidencySet(ResidencySet* residencySet)
{
    m_ResidencySet = residencySet;
}

void Device::SetDevice(id<MTLDevice> device)
{
    m_Device = device;
}

id<MTLDevice> Device::GetDevice()
{
    return m_Device;
}

id<MTLCommandQueue> Device::GetCommandQueue()
{
    return m_CommandQueue;
}

ResidencySet& Device::GetResidencySet()
{
    return *m_ResidencySet;
}
