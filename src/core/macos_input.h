#pragma once

#include "input.h"

class MacOSInput : public Input {
public:
    MacOSInput();
    virtual ~MacOSInput() = default;

    vector_float3 GetMoveVector() const override;
    vector_float2 GetRotateVector() const override;
    void Update(float deltaTime) override;

    // Mouse event handling (called from view)
    void SetMousePosition(vector_float2 position);
    void SetRightMouseDown(bool down);

private:
    vector_float2 m_CurrentMousePos;
    vector_float2 m_PreviousMousePos;
    bool m_FirstMouse;
    bool m_MouseButtonDown;
};