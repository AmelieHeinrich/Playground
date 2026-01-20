#include "Camera.h"
#include "Input.h"

#include <cmath>
#include <simd/quaternion.h>

Camera::Camera()
    : m_Position(simd_make_float3(0.0f, 0.0f, 0.0f))
    , m_Yaw(0.0f)
    , m_Pitch(0.0f)
    , m_MoveSpeed(5.0f)
    , m_RotationSensitivity(1.0f)
    , m_Fov(radians_from_degrees(60.0f))
    , m_AspectRatio(16.0f / 9.0f)
    , m_NearPlane(0.1f)
    , m_FarPlane(150.0f)
    , m_Forward(simd_make_float3(0.0f, 0.0f, 1.0f))
    , m_Right(simd_make_float3(1.0f, 0.0f, 0.0f))
    , m_Up(simd_make_float3(0.0f, 1.0f, 0.0f))
{
    UpdateDirectionVectors();
}

void Camera::Update(const Input& input, float deltaTime)
{
    vector_float2 rotateVec = input.GetRotateVector();
    m_Yaw += rotateVec.x * m_RotationSensitivity * deltaTime;
    m_Pitch += rotateVec.y * m_RotationSensitivity * deltaTime;

    const float maxPitch = radians_from_degrees(89.0f);
    if (m_Pitch > maxPitch) {
        m_Pitch = maxPitch;
    } else if (m_Pitch < -maxPitch) {
        m_Pitch = -maxPitch;
    }

    UpdateDirectionVectors();

    vector_float3 moveVec = input.GetMoveVector();

    vector_float3 movement = simd_make_float3(0.0f, 0.0f, 0.0f);

    movement += m_Forward * moveVec.z;

    movement += m_Right * moveVec.x;

    movement += simd_make_float3(0.0f, moveVec.y, 0.0f);

    m_Position += movement * m_MoveSpeed * deltaTime;
}

void Camera::UpdateDirectionVectors()
{
    float cosYaw = cosf(m_Yaw);
    float sinYaw = sinf(m_Yaw);
    float cosPitch = cosf(m_Pitch);
    float sinPitch = sinf(m_Pitch);

    m_Forward = simd_make_float3(
        sinYaw * cosPitch,
        sinPitch,
        cosYaw * cosPitch
    );
    m_Forward = simd_normalize(m_Forward);

    vector_float3 worldUp = simd_make_float3(0.0f, 1.0f, 0.0f);
    m_Right = simd_normalize(simd_cross(m_Forward, worldUp));

    m_Up = simd_normalize(simd_cross(m_Right, m_Forward));
}

matrix_float4x4 Camera::GetViewMatrix() const
{
    vector_float3 target = m_Position + m_Forward;
    return matrix_look_at_right_hand(m_Position, target, m_Up);
}

matrix_float4x4 Camera::GetProjectionMatrix() const
{
    return matrix_perspective_right_hand(m_Fov, m_AspectRatio, m_NearPlane, m_FarPlane);
}

matrix_float4x4 Camera::GetViewProjectionMatrix() const
{
    return simd_mul(GetProjectionMatrix(), GetViewMatrix());
}

vector_float3 Camera::GetForward() const
{
    return m_Forward;
}

vector_float3 Camera::GetRight() const
{
    return m_Right;
}

vector_float3 Camera::GetUp() const
{
    return m_Up;
}
