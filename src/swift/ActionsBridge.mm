#import "ActionsBridge.h"

#import <map>
#import <string>

struct ActionEntry {
    ActionCallback callback;
    NSString* displayName;
    NSString* category;
    NSString* shortcutHint;
};

@implementation ActionsBridge {
    std::map<std::string, ActionEntry> _actions;
}

+ (instancetype)shared {
    static ActionsBridge* instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[ActionsBridge alloc] init];
    });
    return instance;
}

- (void)registerAction:(NSString*)key
              callback:(ActionCallback)callback
           displayName:(NSString*)name
              category:(NSString*)category {
    [self registerAction:key callback:callback displayName:name category:category shortcutHint:nil];
}

- (void)registerAction:(NSString*)key
              callback:(ActionCallback)callback
           displayName:(NSString*)name
              category:(NSString*)category
          shortcutHint:(nullable NSString*)shortcut {
    ActionEntry entry;
    entry.callback = callback;
    entry.displayName = name;
    entry.category = category;
    entry.shortcutHint = shortcut;
    _actions[key.UTF8String] = entry;
}

- (void)unregisterAction:(NSString*)key {
    _actions.erase(key.UTF8String);
}

- (BOOL)triggerAction:(NSString*)key {
    auto it = _actions.find(key.UTF8String);
    if (it != _actions.end()) {
        if (it->second.callback) {
            it->second.callback();
        }
        return YES;
    }
    return NO;
}

- (NSArray<NSDictionary*>*)allActions {
    NSMutableArray* result = [NSMutableArray array];
    
    for (const auto& pair : _actions) {
        NSMutableDictionary* dict = [NSMutableDictionary dictionary];
        dict[@"key"] = [NSString stringWithUTF8String:pair.first.c_str()];
        dict[@"displayName"] = pair.second.displayName;
        dict[@"category"] = pair.second.category;
        if (pair.second.shortcutHint) {
            dict[@"shortcutHint"] = pair.second.shortcutHint;
        }
        [result addObject:dict];
    }
    
    // Sort by category then by displayName
    [result sortUsingComparator:^NSComparisonResult(NSDictionary* a, NSDictionary* b) {
        NSComparisonResult categoryCompare = [a[@"category"] compare:b[@"category"]];
        if (categoryCompare != NSOrderedSame) {
            return categoryCompare;
        }
        return [a[@"displayName"] compare:b[@"displayName"]];
    }];
    
    return result;
}

- (NSArray<NSString*>*)allCategories {
    NSMutableSet* categories = [NSMutableSet set];
    
    for (const auto& pair : _actions) {
        [categories addObject:pair.second.category];
    }
    
    return [[categories allObjects] sortedArrayUsingSelector:@selector(compare:)];
}

- (NSArray<NSDictionary*>*)actionsForCategory:(NSString*)category {
    NSMutableArray* result = [NSMutableArray array];
    
    for (const auto& pair : _actions) {
        if ([pair.second.category isEqualToString:category]) {
            NSMutableDictionary* dict = [NSMutableDictionary dictionary];
            dict[@"key"] = [NSString stringWithUTF8String:pair.first.c_str()];
            dict[@"displayName"] = pair.second.displayName;
            dict[@"category"] = pair.second.category;
            if (pair.second.shortcutHint) {
                dict[@"shortcutHint"] = pair.second.shortcutHint;
            }
            [result addObject:dict];
        }
    }
    
    [result sortUsingComparator:^NSComparisonResult(NSDictionary* a, NSDictionary* b) {
        return [a[@"displayName"] compare:b[@"displayName"]];
    }];
    
    return result;
}

@end
