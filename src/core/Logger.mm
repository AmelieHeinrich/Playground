#include "Logger.h"
#import "../Swift/ConsoleBridge.h"
#include <cstdarg>

// Logger implementation

Logger& Logger::Get() {
    static Logger instance;
    return instance;
}

Logger::Logger() {
    // ConsoleBridge is initialized as a singleton, nothing to do here
}

Logger::~Logger() {
    // ConsoleBridge cleanup is handled by the system
}

void Logger::Debug(const std::string& message) {
    LogInternal(LogLevelDebug, message);
}

void Logger::Info(const std::string& message) {
    LogInternal(LogLevelInfo, message);
}

void Logger::Warning(const std::string& message) {
    LogInternal(LogLevelWarning, message);
}

void Logger::Error(const std::string& message) {
    LogInternal(LogLevelError, message);
}

void Logger::Debug(const char* format, ...) {
    va_list args;
    va_start(args, format);
    LogFormatInternal(LogLevelDebug, format, args);
    va_end(args);
}

void Logger::Info(const char* format, ...) {
    va_list args;
    va_start(args, format);
    LogFormatInternal(LogLevelInfo, format, args);
    va_end(args);
}

void Logger::Warning(const char* format, ...) {
    va_list args;
    va_start(args, format);
    LogFormatInternal(LogLevelWarning, format, args);
    va_end(args);
}

void Logger::Error(const char* format, ...) {
    va_list args;
    va_start(args, format);
    LogFormatInternal(LogLevelError, format, args);
    va_end(args);
}

void Logger::LogInternal(LogLevel level, const std::string& message) {
    NSString* nsMessage = [NSString stringWithUTF8String:message.c_str()];
    ConsoleBridge* bridge = [ConsoleBridge shared];
    
    switch (level) {
        case LogLevelDebug:
            [bridge debug:nsMessage];
            break;
        case LogLevelInfo:
            [bridge info:nsMessage];
            break;
        case LogLevelWarning:
            [bridge warning:nsMessage];
            break;
        case LogLevelError:
            [bridge error:nsMessage];
            break;
    }
}

void Logger::LogFormatInternal(LogLevel level, const char* format, va_list args) {
    // Create NSString from format and args
    NSString* nsFormat = [NSString stringWithUTF8String:format];
    NSString* nsMessage = [[NSString alloc] initWithFormat:nsFormat arguments:args];
    
    ConsoleBridge* bridge = [ConsoleBridge shared];
    
    switch (level) {
        case LogLevelDebug:
            [bridge debug:nsMessage];
            break;
        case LogLevelInfo:
            [bridge info:nsMessage];
            break;
        case LogLevelWarning:
            [bridge warning:nsMessage];
            break;
        case LogLevelError:
            [bridge error:nsMessage];
            break;
    }
}

// LogStream implementation

Logger::LogStream::LogStream(LogLevel level)
    : m_Level(level) {
}

Logger::LogStream::~LogStream() {
    // Flush the stream to the logger
    std::string message = m_Stream.str();
    if (!message.empty()) {
        Logger::Get().LogInternal(m_Level, message);
    }
}