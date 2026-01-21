import SwiftUI
import Metal

struct AboutView: View {
    let bridge: ApplicationBridge?
    @State private var isCapabilitiesExpanded = false

    init(bridge: ApplicationBridge? = nil) {
        self.bridge = bridge
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // App Icon and Title
                VStack(spacing: 12) {
                    #if os(macOS)
                    Image(nsImage: NSImage(named: "AppIcon macOS") ?? NSImage())
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 128, height: 128)
                        .cornerRadius(16)
                    #else
                    if let appIcon = UIImage(named: "AppIcon iOS") {
                        Image(uiImage: appIcon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 128, height: 128)
                            .cornerRadius(16)
                    } else {
                        Image(systemName: "cube.transparent")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 128, height: 128)
                            .foregroundStyle(.blue.gradient)
                    }
                    #endif

                    Text("Playground")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Metal Showcase Renderer")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 20)

                Divider()
                    .padding(.horizontal)

                // App Info
                VStack(alignment: .leading, spacing: 16) {
                    InfoRow(label: "Developer", value: "Amélie Heinrich")
                    InfoRow(label: "Platform", value: platformInfo)
                    InfoRow(label: "Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                }
                .padding(.horizontal, 20)

                Divider()
                    .padding(.horizontal)

                // GPU Information
                if let device = bridge?.device {
                    VStack(alignment: .leading, spacing: 16) {
                        Label("Graphics Device", systemImage: "gpu")
                            .font(.headline)
                            .foregroundStyle(.blue)

                        VStack(alignment: .leading, spacing: 12) {
                            InfoRow(label: "Name", value: device.name)

                            #if os(macOS)
                            InfoRow(label: "Registry ID", value: String(device.registryID))

                            if device.isLowPower {
                                HStack {
                                    Image(systemName: "battery.100")
                                        .foregroundStyle(.green)
                                    Text("Low Power Mode")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            if device.isRemovable {
                                HStack {
                                    Image(systemName: "eject")
                                        .foregroundStyle(.orange)
                                    Text("Removable")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            #endif

                            InfoRow(label: "Max Threads Per Group",
                                   value: "\(device.maxThreadsPerThreadgroup.width) × \(device.maxThreadsPerThreadgroup.height) × \(device.maxThreadsPerThreadgroup.depth)")

                            InfoRow(label: "Max Buffer Length",
                                    value: formatBytes(UInt64(device.maxBufferLength)))

                            if #available(macOS 13.0, iOS 16.0, *) {
                                InfoRow(label: "Recommended Max Working Set",
                                       value: formatBytes(device.recommendedMaxWorkingSetSize))
                            }
                        }

                        // Capabilities Section (Foldable)
                        DisclosureGroup(isExpanded: $isCapabilitiesExpanded) {
                            VStack(alignment: .leading, spacing: 8) {
                                CapabilityRow(name: "Ray Tracing", supported: device.supportsRaytracing)
                                CapabilityRow(name: "Shader Barycentric Coordinates", supported: device.supportsShaderBarycentricCoordinates)
                                CapabilityRow(name: "Function Pointers", supported: device.supportsFunctionPointers)

                                #if os(macOS)
                                if #available(macOS 13.0, *) {
                                    CapabilityRow(name: "Dynamic Library", supported: device.supportsDynamicLibraries)
                                }
                                #endif

                                if #available(macOS 13.0, iOS 16.0, *) {
                                    CapabilityRow(name: "Render Dynamic Library", supported: device.supportsRenderDynamicLibraries)
                                }

                                CapabilityRow(name: "32-bit Float Filtering", supported: device.supports32BitFloatFiltering)
                                CapabilityRow(name: "32-bit MSAA", supported: device.supports32BitMSAA)
                                CapabilityRow(name: "Query Texture LOD", supported: device.supportsQueryTextureLOD)
                                CapabilityRow(name: "BC Texture Compression", supported: device.supportsBCTextureCompression)
                                CapabilityRow(name: "Pull Model Interpolation", supported: device.supportsPullModelInterpolation)

                                if #available(macOS 11.0, iOS 14.0, *) {
                                    CapabilityRow(name: "Counter Sampling", supported: device.supportsCounterSampling(.atStageBoundary))
                                }

                                if #available(macOS 14.0, iOS 17.0, *) {
                                    CapabilityRow(name: "Raytracing from Render", supported: device.supportsRaytracingFromRender)
                                }
                            }
                            .padding(.top, 8)
                        } label: {
                            Label("GPU Capabilities", systemImage: "checklist")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 8)
                    }
                    .padding(.horizontal, 20)

                    Divider()
                        .padding(.horizontal)
                }

                // Description
                VStack(alignment: .leading, spacing: 12) {
                    Text("About")
                        .font(.headline)
                        .foregroundStyle(.blue)

                    Text("A Metal-based rendering showcase application demonstrating advanced graphics techniques including ray tracing, cascaded shadow maps, reflections, and deferred rendering. Designed to run on both iOS and macOS.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 20)

                Spacer()
            }
            .padding(.bottom, 20)
        }
    }

    private var platformInfo: String {
        #if os(macOS)
        return "macOS"
        #else
        return "iOS"
        #endif
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB, .useKB]
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 140, alignment: .leading)
            Text(value)
                .fontWeight(.medium)
            Spacer()
        }
        .font(.subheadline)
    }
}

struct CapabilityRow: View {
    let name: String
    let supported: Bool

    var body: some View {
        HStack {
            Image(systemName: supported ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(supported ? .green : .red)
                .font(.caption)
            Text(name)
                .font(.caption)
            Spacer()
        }
    }
}
