#pragma once

#import <Foundation/Foundation.h>
#include <string>
#include <sstream>

// Import ConsoleBridge to get LogLevel enum
#import "../Swift/ConsoleBridge.h"

class Logger {
public:
    // Get singleton instance
    static Logger& Get();
    
    // Basic logging methods
    void Debug(const std::string& message);
    void Info(const std::string& message);
    void Warning(const std::string& message);
    void Error(const std::string& message);
    
    // Format string logging (printf-style)
    void Debug(const char* format, ...);
    void Info(const char* format, ...);
    void Warning(const char* format, ...);
    void Error(const char* format, ...);
    
    // Stream-style logging helper
    class LogStream {
    public:
        LogStream(LogLevel level);
        ~LogStream();
        
        template<typename T>
        LogStream& operator<<(const T& value) {
            m_Stream << value;
            return *this;
        }
        
    private:
        LogLevel m_Level;
        std::stringstream m_Stream;
    };
    
    // Factory methods for stream-style logging
    static LogStream Debug() { return LogStream(LogLevelDebug); }
    static LogStream Info() { return LogStream(LogLevelInfo); }
    static LogStream Warning() { return LogStream(LogLevelWarning); }
    static LogStream Error() { return LogStream(LogLevelError); }
    
private:
    Logger();
    ~Logger();
    
    // Delete copy constructor and assignment operator
    Logger(const Logger&) = delete;
    Logger& operator=(const Logger&) = delete;
    
    void LogInternal(LogLevel level, const std::string& message);
    void LogFormatInternal(LogLevel level, const char* format, va_list args);
};

// Convenience macros for cleaner syntax
#define LOG_DEBUG(msg) Logger::Get().Debug(msg)
#define LOG_INFO(msg) Logger::Get().Info(msg)
#define LOG_WARNING(msg) Logger::Get().Warning(msg)
#define LOG_ERROR(msg) Logger::Get().Error(msg)

#define LOG_DEBUG_FMT(...) Logger::Get().Debug(__VA_ARGS__)
#define LOG_INFO_FMT(...) Logger::Get().Info(__VA_ARGS__)
#define LOG_WARNING_FMT(...) Logger::Get().Warning(__VA_ARGS__)
#define LOG_ERROR_FMT(...) Logger::Get().Error(__VA_ARGS__)

// Stream-style macros
#define LOG_DEBUG_STREAM Logger::Debug()
#define LOG_INFO_STREAM Logger::Info()
#define LOG_WARNING_STREAM Logger::Warning()
#define LOG_ERROR_STREAM Logger::Error()