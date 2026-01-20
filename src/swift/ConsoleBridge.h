#pragma once

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, LogLevel) {
    LogLevelDebug,
    LogLevelInfo,
    LogLevelWarning,
    LogLevelError
};

typedef void(^LogCallback)(NSString* message, LogLevel level, NSDate* timestamp);
typedef void(^CommandCallback)(NSArray<NSString*>* args);

@interface ConsoleBridge : NSObject

+ (instancetype)shared;

// Logging
- (void)setLogCallback:(nullable LogCallback)callback;
- (void)log:(NSString*)message level:(LogLevel)level;
- (void)debug:(NSString*)message;
- (void)info:(NSString*)message;
- (void)warning:(NSString*)message;
- (void)error:(NSString*)message;

// Log with format
- (void)logFormat:(LogLevel)level format:(NSString*)format, ... NS_FORMAT_FUNCTION(2, 3);

// Log history (for initial UI population)
@property (nonatomic, readonly) NSArray<NSDictionary*>* logHistory;
@property (nonatomic) NSUInteger maxHistorySize; // Default: 1000

// Clear logs
- (void)clearLogs;

// Command registration and execution
- (void)registerCommand:(NSString*)name
               callback:(CommandCallback)callback
            description:(NSString*)description;
- (void)unregisterCommand:(NSString*)name;
- (BOOL)executeCommand:(NSString*)commandLine;
- (NSArray<NSDictionary*>*)allCommands; // Returns name and description for each

// Command autocomplete
- (NSArray<NSString*>*)commandsWithPrefix:(NSString*)prefix;

@end

// C++ friendly logging macros (use from .mm files)
#ifdef __cplusplus
#define CONSOLE_DEBUG(msg) [[ConsoleBridge shared] debug:@msg]
#define CONSOLE_INFO(msg) [[ConsoleBridge shared] info:@msg]
#define CONSOLE_WARNING(msg) [[ConsoleBridge shared] warning:@msg]
#define CONSOLE_ERROR(msg) [[ConsoleBridge shared] error:@msg]

#define CONSOLE_DEBUG_FMT(fmt, ...) [[ConsoleBridge shared] logFormat:LogLevelDebug format:@fmt, ##__VA_ARGS__]
#define CONSOLE_INFO_FMT(fmt, ...) [[ConsoleBridge shared] logFormat:LogLevelInfo format:@fmt, ##__VA_ARGS__]
#define CONSOLE_WARNING_FMT(fmt, ...) [[ConsoleBridge shared] logFormat:LogLevelWarning format:@fmt, ##__VA_ARGS__]
#define CONSOLE_ERROR_FMT(fmt, ...) [[ConsoleBridge shared] logFormat:LogLevelError format:@fmt, ##__VA_ARGS__]
#endif

NS_ASSUME_NONNULL_END
