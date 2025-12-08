#include "macos_input.h"

#include <imgui.h>

MacOSInput::MacOSInput()
    : m_CurrentMousePos(simd_make_float2(0.0f, 0.0f))
    , m_PreviousMousePos(simd_make_float2(0.0f, 0.0f))
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

    if (io.WantCaptureMouse || !m_MouseButtonDown || m_FirstMouse) {
        return simd_make_float2(0.0f, 0.0f);
    }

    vector_float2 delta = m_CurrentMousePos - m_PreviousMousePos;
    return -simd_make_float2(delta.x, delta.y) * 0.1f;
}

void MacOSInput::Update(float deltaTime)
{
    ImGuiIO& io = ImGui::GetIO();

    m_PreviousMousePos = m_CurrentMousePos;
    m_CurrentMousePos = simd_make_float2(io.MousePos.x, io.MousePos.y);

    bool isRightMouseDown = !io.WantCaptureMouse && ImGui::IsMouseDown(ImGuiMouseButton_Left);

    if (isRightMouseDown) {
        if (!m_MouseButtonDown) {
            m_FirstMouse = true;
            m_PreviousMousePos = m_CurrentMousePos;
        } else {
            m_FirstMouse = false;
        }
        m_MouseButtonDown = true;
    } else {
        m_MouseButtonDown = false;
        m_FirstMouse = true;
    }
}
