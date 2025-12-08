#pragma once

#include "input.h"

class MacOSInput : public Input {
public:
    MacOSInput();
    virtual ~MacOSInput() = default;

    vector_float3 GetMoveVector() const override;
    vector_float2 GetRotateVector() const override;
    void Update(float deltaTime) override;

private:
    vector_float2 m_CurrentMousePos;
    vector_float2 m_PreviousMousePos;
    bool m_FirstMouse;
    bool m_MouseButtonDown;
};