#include "macos_input.h"

#include <imgui.h>

MacOSInput::MacOSInput()
    : m_LastMousePos(simd_make_float2(0.0f, 0.0f))
    , m_FirstMouse(true)
    , m_MouseButtonDown(false)
{
}

vector_float3 MacOSInput::GetMoveVector() const
{
    ImGuiIO& io = ImGui::GetIO();
    
    if (io.WantCaptureKeyboard) {
        return simd_make_float3(0.0f, 0.0f, 0.0f);
    }

    vector_float3 moveVec = simd_make_float3(0.0f, 0.0f, 0.0f);

    if (ImGui::IsKeyDown(ImGuiKey_W)) {
        moveVec.z += 1.0f;
    }
    if (ImGui::IsKeyDown(ImGuiKey_S)) {
        moveVec.z -= 1.0f;
    }
    if (ImGui::IsKeyDown(ImGuiKey_D)) {
        moveVec.x += 1.0f;
    }
    if (ImGui::IsKeyDown(ImGuiKey_A)) {
        moveVec.x -= 1.0f;
    }
    if (ImGui::IsKeyDown(ImGuiKey_Space)) {
        moveVec.y += 1.0f;
    }
    if (ImGui::IsKeyDown(ImGuiKey_LeftShift)) {
        moveVec.y -= 1.0f;
    }

    return moveVec;
}

vector_float2 MacOSInput::GetRotateVector() const
{
    ImGuiIO& io = ImGui::GetIO();
    
    if (io.WantCaptureMouse) {
        return simd_make_float2(0.0f, 0.0f);
    }

    vector_float2 rotateVec = simd_make_float2(0.0f, 0.0f);

    if (m_MouseButtonDown) {
        vector_float2 currentMousePos = simd_make_float2(io.MousePos.x, io.MousePos.y);
        
        if (!m_FirstMouse) {
            vector_float2 delta = currentMousePos - m_LastMousePos;
            rotateVec.x = delta.x;
            rotateVec.y = -delta.y;
        }
    }

    return rotateVec;
}

void MacOSInput::Update(float deltaTime)
{
    ImGuiIO& io = ImGui::GetIO();
    
    if (!io.WantCaptureMouse && ImGui::IsMouseDown(ImGuiMouseButton_Right)) {
        m_MouseButtonDown = true;
        
        vector_float2 currentMousePos = simd_make_float2(io.MousePos.x, io.MousePos.y);
        
        if (m_FirstMouse) {
            m_LastMousePos = currentMousePos;
            m_FirstMouse = false;
        } else {
            m_LastMousePos = currentMousePos;
        }
    } else {
        m_MouseButtonDown = false;
        m_FirstMouse = true;
    }
}