#import "SpectacleLoginItemHelper.h"

#import <ServiceManagement/ServiceManagement.h>

@implementation SpectacleLoginItemHelper

+ (BOOL)isLoginItemEnabledForBundle:(NSBundle *)bundle
{
  (void)bundle;
  if (@available(macOS 13.0, *)) {
    return SMAppService.mainAppService.status == SMAppServiceStatusEnabled;
  }
  return NO;
}

+ (void)enableLoginItemForBundle:(NSBundle *)bundle
{
  (void)bundle;
  if (@available(macOS 13.0, *)) {
    NSError *error = nil;
    if (![SMAppService.mainAppService registerAndReturnError:&error]) {
      NSLog(@"Unable to enable login item: %@", error.localizedDescription);
    }
  }
}

+ (void)disableLoginItemForBundle:(NSBundle *)bundle
{
  (void)bundle;
  if (@available(macOS 13.0, *)) {
    NSError *error = nil;
    if (![SMAppService.mainAppService unregisterAndReturnError:&error]) {
      NSLog(@"Unable to disable login item: %@", error.localizedDescription);
    }
  }
}

@end
