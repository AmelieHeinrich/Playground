#import "CVarRegistry.h"

#import <map>
#import <string>

struct CVarEntry {
    CVarType type;
    NSString* displayName;
    void* pointer;
    float minFloat;
    float maxFloat;
    int minInt;
    int maxInt;
    NSArray<NSString*>* enumOptions;
};

@implementation CVarRegistry {
    std::map<std::string, CVarEntry> _cvars;
}

+ (instancetype)shared {
    static CVarRegistry* instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[CVarRegistry alloc] init];
    });
    return instance;
}

- (void)registerFloat:(NSString*)key
              pointer:(float*)ptr
                  min:(float)min
                  max:(float)max
          displayName:(NSString*)name {
    CVarEntry entry;
    entry.type = CVarTypeFloat;
    entry.displayName = name;
    entry.pointer = ptr;
    entry.minFloat = min;
    entry.maxFloat = max;
    _cvars[key.UTF8String] = entry;
}

- (void)registerInt:(NSString*)key
            pointer:(int*)ptr
                min:(int)min
                max:(int)max
        displayName:(NSString*)name {
    CVarEntry entry;
    entry.type = CVarTypeInt;
    entry.displayName = name;
    entry.pointer = ptr;
    entry.minInt = min;
    entry.maxInt = max;
    _cvars[key.UTF8String] = entry;
}

- (void)registerBool:(NSString*)key
             pointer:(bool*)ptr
         displayName:(NSString*)name {
    CVarEntry entry;
    entry.type = CVarTypeBool;
    entry.displayName = name;
    entry.pointer = ptr;
    _cvars[key.UTF8String] = entry;
}

- (void)registerEnum:(NSString*)key
             pointer:(int*)ptr
             options:(NSArray<NSString*>*)options
         displayName:(NSString*)name {
    CVarEntry entry;
    entry.type = CVarTypeEnum;
    entry.displayName = name;
    entry.pointer = ptr;
    entry.enumOptions = options;
    _cvars[key.UTF8String] = entry;
}

- (void)registerColor:(NSString*)key
              pointer:(simd_float4*)ptr
          displayName:(NSString*)name {
    CVarEntry entry;
    entry.type = CVarTypeColor;
    entry.displayName = name;
    entry.pointer = ptr;
    _cvars[key.UTF8String] = entry;
}

- (void)unregister:(NSString*)key {
    _cvars.erase(key.UTF8String);
}

- (float)getFloat:(NSString*)key {
    auto it = _cvars.find(key.UTF8String);
    if (it != _cvars.end() && it->second.type == CVarTypeFloat) {
        return *static_cast<float*>(it->second.pointer);
    }
    return 0.0f;
}

- (void)setFloat:(NSString*)key value:(float)value {
    auto it = _cvars.find(key.UTF8String);
    if (it != _cvars.end() && it->second.type == CVarTypeFloat) {
        value = fmaxf(it->second.minFloat, fminf(it->second.maxFloat, value));
        *static_cast<float*>(it->second.pointer) = value;
    }
}

- (int)getInt:(NSString*)key {
    auto it = _cvars.find(key.UTF8String);
    if (it != _cvars.end() && it->second.type == CVarTypeInt) {
        return *static_cast<int*>(it->second.pointer);
    }
    return 0;
}

- (void)setInt:(NSString*)key value:(int)value {
    auto it = _cvars.find(key.UTF8String);
    if (it != _cvars.end() && it->second.type == CVarTypeInt) {
        value = std::max(it->second.minInt, std::min(it->second.maxInt, value));
        *static_cast<int*>(it->second.pointer) = value;
    }
}

- (BOOL)getBool:(NSString*)key {
    auto it = _cvars.find(key.UTF8String);
    if (it != _cvars.end() && it->second.type == CVarTypeBool) {
        return *static_cast<bool*>(it->second.pointer);
    }
    return NO;
}

- (void)setBool:(NSString*)key value:(BOOL)value {
    auto it = _cvars.find(key.UTF8String);
    if (it != _cvars.end() && it->second.type == CVarTypeBool) {
        *static_cast<bool*>(it->second.pointer) = value;
    }
}

- (int)getEnum:(NSString*)key {
    auto it = _cvars.find(key.UTF8String);
    if (it != _cvars.end() && it->second.type == CVarTypeEnum) {
        return *static_cast<int*>(it->second.pointer);
    }
    return 0;
}

- (void)setEnum:(NSString*)key value:(int)value {
    auto it = _cvars.find(key.UTF8String);
    if (it != _cvars.end() && it->second.type == CVarTypeEnum) {
        int maxValue = (int)it->second.enumOptions.count - 1;
        value = std::max(0, std::min(maxValue, value));
        *static_cast<int*>(it->second.pointer) = value;
    }
}

- (simd_float4)getColor:(NSString*)key {
    auto it = _cvars.find(key.UTF8String);
    if (it != _cvars.end() && it->second.type == CVarTypeColor) {
        return *static_cast<simd_float4*>(it->second.pointer);
    }
    return simd_make_float4(0, 0, 0, 1);
}

- (void)setColor:(NSString*)key value:(simd_float4)value {
    auto it = _cvars.find(key.UTF8String);
    if (it != _cvars.end() && it->second.type == CVarTypeColor) {
        *static_cast<simd_float4*>(it->second.pointer) = value;
    }
}

- (NSArray<NSDictionary*>*)allCVars {
    NSMutableArray* result = [NSMutableArray array];
    
    for (const auto& pair : _cvars) {
        NSMutableDictionary* dict = [NSMutableDictionary dictionary];
        dict[@"key"] = [NSString stringWithUTF8String:pair.first.c_str()];
        dict[@"type"] = @(pair.second.type);
        dict[@"displayName"] = pair.second.displayName;
        
        switch (pair.second.type) {
            case CVarTypeFloat:
                dict[@"min"] = @(pair.second.minFloat);
                dict[@"max"] = @(pair.second.maxFloat);
                dict[@"value"] = @(*static_cast<float*>(pair.second.pointer));
                break;
            case CVarTypeInt:
                dict[@"min"] = @(pair.second.minInt);
                dict[@"max"] = @(pair.second.maxInt);
                dict[@"value"] = @(*static_cast<int*>(pair.second.pointer));
                break;
            case CVarTypeBool:
                dict[@"value"] = @(*static_cast<bool*>(pair.second.pointer));
                break;
            case CVarTypeEnum:
                dict[@"options"] = pair.second.enumOptions;
                dict[@"value"] = @(*static_cast<int*>(pair.second.pointer));
                break;
            case CVarTypeColor: {
                simd_float4 color = *static_cast<simd_float4*>(pair.second.pointer);
                dict[@"r"] = @(color.x);
                dict[@"g"] = @(color.y);
                dict[@"b"] = @(color.z);
                dict[@"a"] = @(color.w);
                break;
            }
        }
        
        [result addObject:dict];
    }
    
    // Sort by key for consistent ordering
    [result sortUsingComparator:^NSComparisonResult(NSDictionary* a, NSDictionary* b) {
        return [a[@"key"] compare:b[@"key"]];
    }];
    
    return result;
}

- (NSArray<NSString*>*)allCategories {
    NSMutableSet* categories = [NSMutableSet set];
    
    for (const auto& pair : _cvars) {
        NSString* key = [NSString stringWithUTF8String:pair.first.c_str()];
        NSArray* components = [key componentsSeparatedByString:@"."];
        if (components.count > 0) {
            [categories addObject:components[0]];
        }
    }
    
    return [[categories allObjects] sortedArrayUsingSelector:@selector(compare:)];
}

- (NSArray<NSDictionary*>*)cvarsForCategory:(NSString*)category {
    NSMutableArray* result = [NSMutableArray array];
    NSString* prefix = [category stringByAppendingString:@"."];
    
    for (NSDictionary* cvar in [self allCVars]) {
        NSString* key = cvar[@"key"];
        if ([key hasPrefix:prefix]) {
            [result addObject:cvar];
        }
    }
    
    return result;
}

@end
