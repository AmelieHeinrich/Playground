#pragma once

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void(^ActionCallback)(void);

@interface ActionsBridge : NSObject

+ (instancetype)shared;

// Register an action
- (void)registerAction:(NSString*)key
              callback:(ActionCallback)callback
           displayName:(NSString*)name
              category:(NSString*)category;

// Register with optional keyboard shortcut hint (for display only)
- (void)registerAction:(NSString*)key
              callback:(ActionCallback)callback
           displayName:(NSString*)name
              category:(NSString*)category
          shortcutHint:(nullable NSString*)shortcut;

// Unregister
- (void)unregisterAction:(NSString*)key;

// Trigger an action
- (BOOL)triggerAction:(NSString*)key;

// Get all actions for UI generation
// Returns: key, displayName, category, shortcutHint
- (NSArray<NSDictionary*>*)allActions;

// Get all categories
- (NSArray<NSString*>*)allCategories;

// Get actions for a specific category
- (NSArray<NSDictionary*>*)actionsForCategory:(NSString*)category;

@end

NS_ASSUME_NONNULL_END
