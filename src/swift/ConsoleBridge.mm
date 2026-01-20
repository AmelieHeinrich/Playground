#import "ConsoleBridge.h"

#import <map>
#import <string>

struct CommandEntry {
    CommandCallback callback;
    NSString* description;
};

@implementation ConsoleBridge {
    LogCallback _logCallback;
    NSMutableArray<NSDictionary*>* _logHistory;
    std::map<std::string, CommandEntry> _commands;
}

+ (instancetype)shared {
    static ConsoleBridge* instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[ConsoleBridge alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _logHistory = [NSMutableArray array];
        _maxHistorySize = 1000;
        
        // Register built-in commands
        [self registerCommand:@"help"
                     callback:^(NSArray<NSString*>* args) {
            [[ConsoleBridge shared] info:@"Available commands:"];
            for (NSDictionary* cmd in [[ConsoleBridge shared] allCommands]) {
                NSString* msg = [NSString stringWithFormat:@"  %@ - %@", cmd[@"name"], cmd[@"description"]];
                [[ConsoleBridge shared] info:msg];
            }
        }
                  description:@"List all available commands"];
        
        [self registerCommand:@"clear"
                     callback:^(NSArray<NSString*>* args) {
            [[ConsoleBridge shared] clearLogs];
        }
                  description:@"Clear the console"];
    }
    return self;
}

- (void)setLogCallback:(nullable LogCallback)callback {
    _logCallback = callback;
}

- (void)log:(NSString*)message level:(LogLevel)level {
    NSDate* timestamp = [NSDate date];
    
    // Store in history
    NSDictionary* entry = @{
        @"message": message,
        @"level": @(level),
        @"timestamp": timestamp
    };
    
    @synchronized (_logHistory) {
        [_logHistory addObject:entry];
        
        // Trim history if needed
        while (_logHistory.count > _maxHistorySize) {
            [_logHistory removeObjectAtIndex:0];
        }
    }
    
    // Notify callback
    if (_logCallback) {
        _logCallback(message, level, timestamp);
    }
    
    // Also log to NSLog for debugging
    NSString* levelStr;
    switch (level) {
        case LogLevelDebug: levelStr = @"DEBUG"; break;
        case LogLevelInfo: levelStr = @"INFO"; break;
        case LogLevelWarning: levelStr = @"WARNING"; break;
        case LogLevelError: levelStr = @"ERROR"; break;
    }
    NSLog(@"[%@] %@", levelStr, message);
}

- (void)debug:(NSString*)message {
    [self log:message level:LogLevelDebug];
}

- (void)info:(NSString*)message {
    [self log:message level:LogLevelInfo];
}

- (void)warning:(NSString*)message {
    [self log:message level:LogLevelWarning];
}

- (void)error:(NSString*)message {
    [self log:message level:LogLevelError];
}

- (void)logFormat:(LogLevel)level format:(NSString*)format, ... {
    va_list args;
    va_start(args, format);
    NSString* message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    
    [self log:message level:level];
}

- (NSArray<NSDictionary*>*)logHistory {
    @synchronized (_logHistory) {
        return [_logHistory copy];
    }
}

- (void)clearLogs {
    @synchronized (_logHistory) {
        [_logHistory removeAllObjects];
    }
    
    // Notify with special clear message
    if (_logCallback) {
        _logCallback(@"__CLEAR__", LogLevelInfo, [NSDate date]);
    }
}

- (void)registerCommand:(NSString*)name
               callback:(CommandCallback)callback
            description:(NSString*)description {
    CommandEntry entry;
    entry.callback = callback;
    entry.description = description;
    _commands[name.UTF8String] = entry;
}

- (void)unregisterCommand:(NSString*)name {
    _commands.erase(name.UTF8String);
}

- (BOOL)executeCommand:(NSString*)commandLine {
    // Parse command line
    NSString* trimmed = [commandLine stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (trimmed.length == 0) {
        return NO;
    }
    
    // Split into command and args
    NSMutableArray<NSString*>* parts = [[trimmed componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] mutableCopy];
    [parts filterUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSString* str, NSDictionary* bindings) {
        return str.length > 0;
    }]];
    
    if (parts.count == 0) {
        return NO;
    }
    
    NSString* command = parts[0];
    NSArray<NSString*>* args = parts.count > 1 ? [parts subarrayWithRange:NSMakeRange(1, parts.count - 1)] : @[];
    
    // Find and execute command
    auto it = _commands.find(command.UTF8String);
    if (it != _commands.end()) {
        [self info:[NSString stringWithFormat:@"> %@", commandLine]];
        it->second.callback(args);
        return YES;
    }
    
    [self error:[NSString stringWithFormat:@"Unknown command: %@", command]];
    return NO;
}

- (NSArray<NSDictionary*>*)allCommands {
    NSMutableArray* result = [NSMutableArray array];
    
    for (const auto& pair : _commands) {
        [result addObject:@{
            @"name": [NSString stringWithUTF8String:pair.first.c_str()],
            @"description": pair.second.description
        }];
    }
    
    [result sortUsingComparator:^NSComparisonResult(NSDictionary* a, NSDictionary* b) {
        return [a[@"name"] compare:b[@"name"]];
    }];
    
    return result;
}

- (NSArray<NSString*>*)commandsWithPrefix:(NSString*)prefix {
    NSMutableArray* result = [NSMutableArray array];
    std::string prefixStr = prefix.UTF8String;
    
    for (const auto& pair : _commands) {
        if (pair.first.find(prefixStr) == 0) {
            [result addObject:[NSString stringWithUTF8String:pair.first.c_str()]];
        }
    }
    
    return [result sortedArrayUsingSelector:@selector(compare:)];
}

@end
