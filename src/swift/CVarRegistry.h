#pragma once

#import <Foundation/Foundation.h>
#import <simd/simd.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, CVarType) {
    CVarTypeFloat,
    CVarTypeInt,
    CVarTypeBool,
    CVarTypeEnum,
    CVarTypeColor,
    CVarTypeVector3
};

@interface CVarRegistry : NSObject

+ (instancetype)shared;

// Registration methods
- (void)registerFloat:(NSString*)key
              pointer:(float*)ptr
                  min:(float)min
                  max:(float)max
          displayName:(NSString*)name;

- (void)registerInt:(NSString*)key
            pointer:(int*)ptr
                min:(int)min
                max:(int)max
        displayName:(NSString*)name;

- (void)registerBool:(NSString*)key
             pointer:(bool*)ptr
         displayName:(NSString*)name;

- (void)registerEnum:(NSString*)key
             pointer:(int*)ptr
             options:(NSArray<NSString*>*)options
         displayName:(NSString*)name;

- (void)registerColor:(NSString*)key
              pointer:(simd_float4*)ptr
          displayName:(NSString*)name;

- (void)registerVector3:(NSString*)key
                pointer:(simd_float3*)ptr
                    min:(float)min
                    max:(float)max
            displayName:(NSString*)name;

// Unregister (for cleanup)
- (void)unregister:(NSString*)key;

// Value access (for Swift bindings)
- (float)getFloat:(NSString*)key;
- (void)setFloat:(NSString*)key value:(float)value;

- (int)getInt:(NSString*)key;
- (void)setInt:(NSString*)key value:(int)value;

- (BOOL)getBool:(NSString*)key;
- (void)setBool:(NSString*)key value:(BOOL)value;

- (int)getEnum:(NSString*)key;
- (void)setEnum:(NSString*)key value:(int)value;

- (simd_float4)getColor:(NSString*)key;
- (void)setColor:(NSString*)key value:(simd_float4)value;

- (simd_float3)getVector3:(NSString*)key;
- (void)setVector3:(NSString*)key value:(simd_float3)value;

// UI generation - returns array of CVar descriptors
// Each descriptor contains: key, type, displayName, min, max, options (for enum)
- (NSArray<NSDictionary*>*)allCVars;

// Get categories (top-level keys from dot notation)
- (NSArray<NSString*>*)allCategories;

// Get CVars for a specific category
- (NSArray<NSDictionary*>*)cvarsForCategory:(NSString*)category;

@end

NS_ASSUME_NONNULL_END
