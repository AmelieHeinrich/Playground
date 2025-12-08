#include "device.h"

id<MTLDevice> Device::m_Device;

void Device::SetDevice(id<MTLDevice> device)
{
    m_Device = device;
}

id<MTLDevice> Device::GetDevice()
{
    return m_Device;
}
