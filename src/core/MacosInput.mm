#include "MacosInput.h"

#import <AppKit/AppKit.h>

MacOSInput::MacOSInput()
    : m_CurrentMousePos(simd_make_float2(0.0f, 0.0f))
    , m_PreviousMousePos(simd_make_float2(0.0f, 0.0f))
    , m_FirstMouse(true)
    , m_MouseButtonDown(false)
{
}

void MacOSInput::SetMousePosition(vector_float2 position)
{
    m_CurrentMousePos = position;
}

void MacOSInput::SetRightMouseDown(bool down)
{
    if (down) {
        if (!m_MouseButtonDown) {
            // First press - save position but mark that we should skip the first delta
            m_FirstMouse = true;
            m_PreviousMousePos = m_CurrentMousePos;
        }
        m_MouseButtonDown = true;
    } else {
        m_MouseButtonDown = false;
        m_FirstMouse = true;
    }
}

static bool IsKeyPressed(unsigned short keyCode) {
    // Use CGEventSource to check key state
    return CGEventSourceKeyState(kCGEventSourceStateCombinedSessionState, keyCode);
}

vector_float3 MacOSInput::GetMoveVector() const
{
    // Don't process keyboard input if input is disabled
    if (!IsEnabled()) {
        return simd_make_float3(0.0f, 0.0f, 0.0f);
    }

    vector_float3 moveVec = simd_make_float3(0.0f, 0.0f, 0.0f);

    // Key codes for WASD and Space/Shift
    // W = 13, S = 1, A = 0, D = 2, Space = 49, Left Shift = 56
    if (IsKeyPressed(13)) { // W
        moveVec.z += 1.0f;
    }
    if (IsKeyPressed(1)) { // S
        moveVec.z -= 1.0f;
    }
    if (IsKeyPressed(2)) { // D
        moveVec.x += 1.0f;
    }
    if (IsKeyPressed(0)) { // A
        moveVec.x -= 1.0f;
    }
    if (IsKeyPressed(49)) { // Space
        moveVec.y += 1.0f;
    }
    if (IsKeyPressed(56)) { // Left Shift
        moveVec.y -= 1.0f;
    }

    return moveVec;
}

vector_float2 MacOSInput::GetRotateVector() const
{
    if (!m_MouseButtonDown || m_FirstMouse) {
        return simd_make_float2(0.0f, 0.0f);
    }

    vector_float2 delta = m_CurrentMousePos - m_PreviousMousePos;
    return -simd_make_float2(delta.x, delta.y) * 0.1f;
}

void MacOSInput::Update(float deltaTime)
{
    // IMPORTANT: Update previous position AFTER camera has read the delta in GetRotateVector
    // This happens at the END of the frame, so next frame's GetRotateVector will calculate the correct delta
    m_PreviousMousePos = m_CurrentMousePos;
    
    // Clear first mouse flag after the first frame
    if (m_FirstMouse && m_MouseButtonDown) {
        m_FirstMouse = false;
    }
}
