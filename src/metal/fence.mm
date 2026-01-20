#include "Fence.h"
#include "Device.h"

Fence::Fence()
{
    m_Fence = [Device::GetDevice() newFence];
}
