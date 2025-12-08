#include "fs.h"

#include <fstream>
#include <sstream>
#include <filesystem>
#include <mach-o/dyld.h>
#include <libgen.h>
#include <unistd.h>

namespace fs {

// Get the full path to the executable
std::string GetExecutablePath() {
    char buffer[1024];
    uint32_t size = sizeof(buffer);

    if (_NSGetExecutablePath(buffer, &size) == 0) {
        char realPath[PATH_MAX];
        if (realpath(buffer, realPath)) {
            std::string path(realPath);
            // Remove the executable name, keep just the directory
            size_t lastSlash = path.find_last_of('/');
            if (lastSlash != std::string::npos) {
                return path.substr(0, lastSlash);
            }
        }
    }

    return ".";
}

// Check if running from a .app bundle
bool IsRunningFromBundle() {
    std::string execPath = GetExecutablePath();
    // Check if the path contains .app/Contents/MacOS
    return execPath.find(".app/Contents/MacOS") != std::string::npos;
}

// Get the Resources directory path
std::string GetResourcesPath() {
    if (IsRunningFromBundle()) {
        std::string execPath = GetExecutablePath();
        // Replace /Contents/MacOS with /Contents/Resources
        size_t pos = execPath.find("/Contents/MacOS");
        if (pos != std::string::npos) {
            return execPath.substr(0, pos) + "/Contents/Resources";
        }
    }

    // If not in a bundle, return the executable directory
    return GetExecutablePath();
}

// Resolve a relative path
std::string ResolvePath(const std::string& relativePath) {
    // If already absolute, return as-is
    if (!relativePath.empty() && relativePath[0] == '/') {
        return relativePath;
    }

    // For relative paths, use Resources directory if in bundle
    std::string basePath = GetResourcesPath();
    return JoinPath(basePath, relativePath);
}

// Check if file exists
bool FileExists(const std::string& path) {
    std::string resolvedPath = ResolvePath(path);
    std::filesystem::path p(resolvedPath);
    return std::filesystem::exists(p) && std::filesystem::is_regular_file(p);
}

// Check if directory exists
bool DirectoryExists(const std::string& path) {
    std::string resolvedPath = ResolvePath(path);
    std::filesystem::path p(resolvedPath);
    return std::filesystem::exists(p) && std::filesystem::is_directory(p);
}

// Get file size
size_t GetFileSize(const std::string& path) {
    std::string resolvedPath = ResolvePath(path);
    try {
        return std::filesystem::file_size(resolvedPath);
    } catch (...) {
        return 0;
    }
}

// Load text file
StringResult LoadTextFile(const std::string& path) {
    StringResult result;
    std::string resolvedPath = ResolvePath(path);

    std::ifstream file(resolvedPath, std::ios::in);
    if (!file.is_open()) {
        result.success = false;
        result.error = "Failed to open file: " + resolvedPath;
        return result;
    }

    std::stringstream buffer;
    buffer << file.rdbuf();

    result.success = true;
    result.data = buffer.str();
    return result;
}

// Write text file
FileResult WriteTextFile(const std::string& path, const std::string& content) {
    FileResult result;
    std::string resolvedPath = ResolvePath(path);

    // Ensure parent directory exists
    std::string dir = GetDirectoryName(resolvedPath);
    if (!dir.empty() && !DirectoryExists(dir)) {
        auto dirResult = CreateDirectories(dir);
        if (!dirResult.success) {
            return dirResult;
        }
    }

    std::ofstream file(resolvedPath, std::ios::out | std::ios::trunc);
    if (!file.is_open()) {
        result.success = false;
        result.error = "Failed to create file: " + resolvedPath;
        return result;
    }

    file << content;

    if (file.fail()) {
        result.success = false;
        result.error = "Failed to write to file: " + resolvedPath;
        return result;
    }

    result.success = true;
    return result;
}

// Load binary file
BinaryResult LoadBinaryFile(const std::string& path) {
    BinaryResult result;
    std::string resolvedPath = ResolvePath(path);

    std::ifstream file(resolvedPath, std::ios::binary | std::ios::ate);
    if (!file.is_open()) {
        result.success = false;
        result.error = "Failed to open file: " + resolvedPath;
        return result;
    }

    std::streamsize size = file.tellg();
    file.seekg(0, std::ios::beg);

    result.data.resize(size);
    if (!file.read(reinterpret_cast<char*>(result.data.data()), size)) {
        result.success = false;
        result.error = "Failed to read file: " + resolvedPath;
        result.data.clear();
        return result;
    }

    result.success = true;
    return result;
}

// Write binary file (vector)
FileResult WriteBinaryFile(const std::string& path, const std::vector<uint8_t>& data) {
    return WriteBinaryFile(path, data.data(), data.size());
}

// Write binary file (raw pointer)
FileResult WriteBinaryFile(const std::string& path, const void* data, size_t size) {
    FileResult result;
    std::string resolvedPath = ResolvePath(path);

    // Ensure parent directory exists
    std::string dir = GetDirectoryName(resolvedPath);
    if (!dir.empty() && !DirectoryExists(dir)) {
        auto dirResult = CreateDirectories(dir);
        if (!dirResult.success) {
            return dirResult;
        }
    }

    std::ofstream file(resolvedPath, std::ios::binary | std::ios::trunc);
    if (!file.is_open()) {
        result.success = false;
        result.error = "Failed to create file: " + resolvedPath;
        return result;
    }

    file.write(reinterpret_cast<const char*>(data), size);

    if (file.fail()) {
        result.success = false;
        result.error = "Failed to write to file: " + resolvedPath;
        return result;
    }

    result.success = true;
    return result;
}

// Create directory
FileResult CreateDirectory(const std::string& path) {
    FileResult result;
    std::string resolvedPath = ResolvePath(path);

    try {
        if (std::filesystem::create_directory(resolvedPath)) {
            result.success = true;
        } else {
            // Directory might already exist
            if (DirectoryExists(resolvedPath)) {
                result.success = true;
            } else {
                result.success = false;
                result.error = "Failed to create directory: " + resolvedPath;
            }
        }
    } catch (const std::exception& e) {
        result.success = false;
        result.error = std::string("Exception creating directory: ") + e.what();
    }

    return result;
}

// Create directories recursively
FileResult CreateDirectories(const std::string& path) {
    FileResult result;
    std::string resolvedPath = ResolvePath(path);

    try {
        if (std::filesystem::create_directories(resolvedPath)) {
            result.success = true;
        } else {
            // Directories might already exist
            if (DirectoryExists(resolvedPath)) {
                result.success = true;
            } else {
                result.success = false;
                result.error = "Failed to create directories: " + resolvedPath;
            }
        }
    } catch (const std::exception& e) {
        result.success = false;
        result.error = std::string("Exception creating directories: ") + e.what();
    }

    return result;
}

// List directory contents
std::vector<std::string> ListDirectory(const std::string& path) {
    std::vector<std::string> entries;
    std::string resolvedPath = ResolvePath(path);

    try {
        for (const auto& entry : std::filesystem::directory_iterator(resolvedPath)) {
            entries.push_back(entry.path().filename().string());
        }
    } catch (...) {
        // Return empty vector on error
    }

    return entries;
}

// Get directory name from path
std::string GetDirectoryName(const std::string& path) {
    std::filesystem::path p(path);
    return p.parent_path().string();
}

// Get file name from path
std::string GetFileName(const std::string& path) {
    std::filesystem::path p(path);
    return p.filename().string();
}

// Get file extension
std::string GetFileExtension(const std::string& path) {
    std::filesystem::path p(path);
    std::string ext = p.extension().string();
    // Remove the leading dot if present
    if (!ext.empty() && ext[0] == '.') {
        return ext.substr(1);
    }
    return ext;
}

// Join path components
std::string JoinPath(const std::string& path1, const std::string& path2) {
    if (path1.empty()) return path2;
    if (path2.empty()) return path1;

    std::filesystem::path p1(path1);
    std::filesystem::path p2(path2);

    return (p1 / p2).string();
}

} // namespace fs
