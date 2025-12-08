/*
Abstract:
First person camera class for 3D navigation.
Handles position, rotation, and view/projection matrix generation.
*/

#pragma once

#include <simd/simd.h>
#include <math/AAPLMath.h>

class Input;

/// First person camera for 3D rendering
class Camera {
public:
    Camera();
    ~Camera() = default;

    /// Updates camera position and rotation based on input
    /// @param input Input interface to poll for movement/rotation
    /// @param deltaTime Time since last frame in seconds
    void Update(const Input& input, float deltaTime);

    /// Returns the view matrix for rendering
    matrix_float4x4 GetViewMatrix() const;

    /// Returns the projection matrix for rendering
    matrix_float4x4 GetProjectionMatrix() const;

    /// Returns the combined view-projection matrix
    matrix_float4x4 GetViewProjectionMatrix() const;

    // Position accessors
    vector_float3 GetPosition() const { return m_Position; }
    void SetPosition(vector_float3 position) { m_Position = position; }

    // Rotation accessors (in radians)
    float GetYaw() const { return m_Yaw; }
    float GetPitch() const { return m_Pitch; }
    void SetYaw(float yaw) { m_Yaw = yaw; }
    void SetPitch(float pitch) { m_Pitch = pitch; }

    // Direction vectors
    vector_float3 GetForward() const;
    vector_float3 GetRight() const;
    vector_float3 GetUp() const;

    // Camera settings
    void SetMoveSpeed(float speed) { m_MoveSpeed = speed; }
    void SetRotationSensitivity(float sensitivity) { m_RotationSensitivity = sensitivity; }
    void SetFieldOfView(float fovRadians) { m_Fov = fovRadians; }
    void SetAspectRatio(float aspect) { m_AspectRatio = aspect; }
    void SetNearPlane(float nearZ) { m_NearPlane = nearZ; }
    void SetFarPlane(float farZ) { m_FarPlane = farZ; }

    float GetMoveSpeed() const { return m_MoveSpeed; }
    float GetRotationSensitivity() const { return m_RotationSensitivity; }
    float GetFieldOfView() const { return m_Fov; }
    float GetAspectRatio() const { return m_AspectRatio; }
    float GetNearPlane() const { return m_NearPlane; }
    float GetFarPlane() const { return m_FarPlane; }

private:
    // Transform
    vector_float3 m_Position;
    float m_Yaw;   // Rotation around Y axis (left/right)
    float m_Pitch; // Rotation around X axis (up/down)

    // Camera parameters
    float m_MoveSpeed;
    float m_RotationSensitivity;
    float m_Fov;          // Field of view in radians
    float m_AspectRatio;
    float m_NearPlane;
    float m_FarPlane;

    // Cached direction vectors
    void UpdateDirectionVectors();
    vector_float3 m_Forward;
    vector_float3 m_Right;
    vector_float3 m_Up;
};
