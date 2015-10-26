/*
 * This file is part of Adblock Plus <https://adblockplus.org/>,
 * Copyright (C) 2006-2015 Eyeo GmbH
 *
 * Adblock Plus is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * Adblock Plus is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Adblock Plus.  If not, see <http://www.gnu.org/licenses/&gt.
 */

#import "AppDelegate.h"

#import "Appearence.h"
#import "RootController.h"
#import "WhitelistedWebsitesController.h"

// Update filter list every 5 days
const NSTimeInterval FilterListsUpdatePeriod = 3600*24*5;
// Wake up application every hour (just hint for iOS)
const NSTimeInterval BackgroundFetchInterval = 3600;

@interface AppDelegate () <NSURLSessionDataDelegate>

@property (nonatomic, strong) AdblockPlusExtras *adblockPlus;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *backgroundFetches;
@property (nonatomic) UIBackgroundTaskIdentifier backgroundTaskIdentifier;
@property (nonatomic) BOOL firstUpdateTriggered;

@end

@implementation AppDelegate

- (void)dealloc
{
  self.adblockPlus = nil;
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
  dispatch_async(dispatch_get_main_queue(), ^{
    [self.adblockPlus reloadContentBlocker];

#ifdef DEBUG
    UILocalNotification *notification = [[UILocalNotification alloc]init];
    notification.repeatInterval = 0;
    notification.alertBody = @"Content blocker reloading has started";
    notification.fireDate = nil;
    [[UIApplication sharedApplication] setScheduledLocalNotifications:@[notification]];
#endif
  });
}

- (BOOL)application:(UIApplication *)application willFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
  [Appearence applyAppearence];
  return YES;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
  self.adblockPlus = [[AdblockPlusExtras alloc] init];
  self.firstUpdateTriggered = NO;

  if ([self.window.rootViewController isKindOfClass:[RootController class]]) {
    ((RootController *)self.window.rootViewController).adblockPlus = self.adblockPlus;
  }

  [application setMinimumBackgroundFetchInterval:BackgroundFetchInterval];

#ifdef DEBUG
  UIUserNotificationType types = UIUserNotificationTypeAlert|UIUserNotificationTypeBadge|UIUserNotificationTypeSound;
  UIUserNotificationSettings *settings = [UIUserNotificationSettings settingsForTypes: types categories:nil];
  [application registerUserNotificationSettings:settings];
#endif

  return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
  if (!self.adblockPlus.reloading) {
    return;
  }

  __weak __typeof(self) wSelf = self;
  __weak __typeof(application) wApplication = application;

  self.backgroundTaskIdentifier = [application beginBackgroundTaskWithExpirationHandler:^{
    [wSelf setBackgroundTaskIdentifier:UIBackgroundTaskInvalid withApplication:wApplication];
  }];
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
  [self setBackgroundTaskIdentifier:UIBackgroundTaskInvalid withApplication:application];
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
  if (!self.firstUpdateTriggered && !self.adblockPlus.updating && self.adblockPlus.lastUpdate == nil) {
    [self.adblockPlus updateFilterLists: NO];
    self.firstUpdateTriggered = YES;
  }
}

- (void)applicationWillTerminate:(UIApplication *)application
{
}

- (void)application:(UIApplication *)application handleEventsForBackgroundURLSession:(NSString *)identifier completionHandler:(void (^)())completionHandler
{
  NSLog(@"identifier: %@", identifier);

  if ([self.adblockPlus isBackgroundNotificationSessionConfigurationIdentifier:identifier]) {
    // All finished task are processed by delegate
    NSURLSession *session = [self.adblockPlus backgroundNotificationSessionWithIdentifier:identifier delegate:self];
    [session invalidateAndCancel];
  }

  completionHandler();
}

#pragma mark - Open URL

- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<NSString *,id> *)options
{
  if (![url.host isEqualToString:@"x-callback-url"]) {
    return NO;
  }

  if (![url.pathComponents containsObject:@"whitelist"]) {
    return NO;
  }

  if (![self.window.rootViewController isKindOfClass:[RootController class]]) {
    return NO;
  }

  NSString *website = nil;
  NSArray *components = [url.query componentsSeparatedByString:@"&"];
  for (NSString *component in components) {
    if ([component hasPrefix:@"website="]) {
      website = [component substringFromIndex:@"website=".length];
      break;
    }
  }

  if (website.length == 0) {
    return NO;
  }

  RootController *rootController = (RootController *)self.window.rootViewController;

  if ([rootController.topViewController isKindOfClass:[WhitelistedWebsitesController class]]) {
    [((id)rootController.topViewController) setWhitelistedWebsite:website];
  } else {
    NSString *segue = @"ShowWhitelistedWebsitesWithoutAnimationSegue";

    [UIView transitionWithView:rootController.view
                      duration:0.4
                       options:UIViewAnimationOptionTransitionCrossDissolve|UIViewAnimationOptionShowHideTransitionViews
                    animations:^{
                      [rootController popToRootViewControllerAnimated:NO];
                      [rootController.topViewController performSegueWithIdentifier:segue sender:nil];
                    }
                    completion:^(BOOL finished) {
                      if (finished) {
                        [((id)rootController.topViewController) setWhitelistedWebsite:website];
                      }
                    }];
  }

  return YES;
}


#pragma mark - Background mode

- (void)application:(UIApplication *)application performFetchWithCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler
{
  NSDate *lastUpdate = self.adblockPlus.lastUpdate;
  if (!lastUpdate) {
    lastUpdate = [NSDate distantPast];
  }

  if ([lastUpdate timeIntervalSinceNow] <= -FilterListsUpdatePeriod) {
    [self.adblockPlus updateFilterLists: NO];
    if (!self.backgroundFetches) {
      self.backgroundFetches = [NSMutableArray array];
    }
    [self.backgroundFetches addObject:
     @{@"completion": completionHandler,
       @"lastUpdate": lastUpdate,
       @"version": @(self.adblockPlus.downloadedVersion),
       @"startDate": [NSDate date]}];
  } else {
    // No need to perform background refresh
    NSLog(@"List is up to date");
    completionHandler(UIBackgroundFetchResultNoData);
  }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
  if ([keyPath isEqualToString:NSStringFromSelector(@selector(reloading))]) {

    BOOL reloading = [change[NSKeyValueChangeNewKey] boolValue];

    if (self.backgroundTaskIdentifier != UIBackgroundTaskInvalid && !reloading) {
      self.backgroundTaskIdentifier = UIBackgroundTaskInvalid;
    }

    UIApplication *application = UIApplication.sharedApplication;

    BOOL isBackground = application.applicationState != UIApplicationStateActive;

    if (self.backgroundTaskIdentifier == UIBackgroundTaskInvalid && reloading && isBackground) {
      __weak __typeof(self) wSelf = self;
      __weak __typeof(application) wApplication = application;

      self.backgroundTaskIdentifier = [application beginBackgroundTaskWithExpirationHandler:^{
        [wSelf setBackgroundTaskIdentifier:UIBackgroundTaskInvalid withApplication:wApplication];
      }];
    }
  } else if ([keyPath isEqualToString:NSStringFromSelector(@selector(filterLists))]) {

    AdblockPlusExtras *adblockPlus = object;
    if (!adblockPlus.updating) {

      for (NSDictionary *backgroundFetch in self.backgroundFetches) {

        // The date of the last known successful update
        NSDate *lastUpdate = backgroundFetch[@"lastUpdate"];
        BOOL updated = !!lastUpdate && [adblockPlus.lastUpdate compare:lastUpdate] == NSOrderedDescending;

        void (^completion)(UIBackgroundFetchResult) = backgroundFetch[@"completion"];
        if (completion) {
          completion(updated ? UIBackgroundFetchResultNewData : UIBackgroundFetchResultFailed);
        }

        NSTimeInterval timeElapsed = -[backgroundFetch[@"startDate"] timeIntervalSinceNow];
        NSLog(@"Background Fetch Duration: %f seconds, Updated: %d", timeElapsed, updated);
      }
      [self.backgroundFetches removeAllObjects];
    }
  } else {
    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
  }
}

- (void)setBackgroundTaskIdentifier:(UIBackgroundTaskIdentifier)backgroundTaskIdentifier
                    withApplication:(UIApplication *)application
{
  if (self.backgroundTaskIdentifier != UIBackgroundTaskInvalid) {
    [application endBackgroundTask:self.backgroundTaskIdentifier];
  }
  self.backgroundTaskIdentifier = backgroundTaskIdentifier;
}

#pragma mark -

-(void)setAdblockPlus:(AdblockPlusExtras *)adblockPlus
{
  AdblockPlusExtras *oldAdblockPlus = _adblockPlus;
  _adblockPlus = adblockPlus;

  for (NSString *keyPath in @[NSStringFromSelector(@selector(filterLists)),
                              NSStringFromSelector(@selector(reloading))]) {
    [oldAdblockPlus removeObserver:self
                        forKeyPath:keyPath
                           context:nil];
    [adblockPlus addObserver:self
                  forKeyPath:keyPath
                     options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld
                     context:nil];
  }
}

@end
