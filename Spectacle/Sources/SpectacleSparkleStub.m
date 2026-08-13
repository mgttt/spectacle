#import <Foundation/Foundation.h>

// Compiled main nib still references SUUpdater. Spectacle.app.com's Sparkle 1
// feed is dead; this stub keeps nib unarchiving working without the framework.
@interface SUUpdater : NSObject
+ (instancetype)sharedUpdater;
- (void)setAutomaticallyChecksForUpdates:(BOOL)automaticallyChecksForUpdates;
@end

@implementation SUUpdater

+ (instancetype)sharedUpdater
{
  static SUUpdater *updater;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    updater = [self new];
  });
  return updater;
}

- (void)setAutomaticallyChecksForUpdates:(BOOL)automaticallyChecksForUpdates
{
  (void)automaticallyChecksForUpdates;
}

@end
