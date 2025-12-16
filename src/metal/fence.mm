#include "fence.h"
#include "device.h"

Fence::Fence()
{
    m_Fence = [Device::GetDevice() newFence];
}
