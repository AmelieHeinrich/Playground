#pragma once

#include <string>
#include <vector>
#include <optional>

namespace fs {

// Result types for error handling
struct FileResult {
    bool success;
    std::string error;
};

struct StringResult {
    bool success;
    std::string data;
    std::string error;
};

struct BinaryResult {
    bool success;
    std::vector<uint8_t> data;
    std::string error;
};

// Path resolution functions
// Get the path to the application bundle's Resources directory (if running from .app)
std::string GetResourcesPath();

// Get the path to the application's executable directory
std::string GetExecutablePath();

// Resolve a relative path to an absolute path, considering .app bundle structure
// If running from .app, relative paths are resolved relative to Resources/
// Otherwise, resolved relative to executable directory
std::string ResolvePath(const std::string& relativePath);

// Check if the application is running from a .app bundle
bool IsRunningFromBundle();

// File existence and info
bool FileExists(const std::string& path);
bool DirectoryExists(const std::string& path);
size_t GetFileSize(const std::string& path);

// String file operations (text files)
StringResult LoadTextFile(const std::string& path);
FileResult WriteTextFile(const std::string& path, const std::string& content);

// Binary file operations
BinaryResult LoadBinaryFile(const std::string& path);
FileResult WriteBinaryFile(const std::string& path, const std::vector<uint8_t>& data);
FileResult WriteBinaryFile(const std::string& path, const void* data, size_t size);

// Directory operations
FileResult CreateDirectory(const std::string& path);
FileResult CreateDirectories(const std::string& path); // Creates parent directories as needed
std::vector<std::string> ListDirectory(const std::string& path);

// Path manipulation
std::string GetDirectoryName(const std::string& path);
std::string GetFileName(const std::string& path);
std::string GetFileExtension(const std::string& path);
std::string JoinPath(const std::string& path1, const std::string& path2);

} // namespace fs
