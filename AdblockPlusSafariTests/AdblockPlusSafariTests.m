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

#import <XCTest/XCTest.h>

#import "AdblockPlusExtras.h"
#import "AdblockPlus+Extension.h"
#import "AdblockPlus+Parsing.h"
#import "NSString+AdblockPlus.h"

@interface AdblockPlusSafariTests : XCTestCase

@end

@implementation AdblockPlusSafariTests

- (void)setUp
{
  [super setUp];
  // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown
{
  // Put teardown code here. This method is called after the invocation of each test method in the class.
  [super tearDown];
}

- (void)performMergeFilterLists:(NSString *)filterLists
{
  NSURL *input = [[NSBundle bundleForClass:[self class]] URLForResource:filterLists withExtension:@"json"];
  NSString *filename = input.lastPathComponent;
  NSURL *output = [[NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES] URLByAppendingPathComponent:filename isDirectory:NO];

  id websites = @[@"adblockplus.org", @"acceptableads.org"];

  NSError *error;
  if (![AdblockPlus mergeFilterListsFromURL:input
                    withWhitelistedWebsites:websites
                                      toURL:output
                                      error:&error]) {
    XCTAssert(false, @"Marging has failed: %@", [error localizedDescription]);
    return;
  }

  if (![[NSFileManager defaultManager] fileExistsAtPath:output.path]) {
    XCTAssert(false, @"File doesn't exist!");
    return;
  }

  NSInputStream *inputStream = [NSInputStream inputStreamWithURL:output];
  @try {
    [inputStream open];
    NSError *error;
    [NSJSONSerialization JSONObjectWithStream:inputStream options:NSJSONReadingMutableContainers error:&error];
    XCTAssert(error == nil, @"JSON is not valid: %@", error);
  }
  @catch (NSException *exception) {
    XCTAssert(false, @"Reading failed %@", exception.reason);
  }
  @finally {
    [inputStream close];
  }
}

- (void)testEmptyFilterListsMergeWithWhitelistedWebsites
{
  [self performMergeFilterLists:@"empty"];
}

- (void)testEasylistFilterListsMergeWithWhitelistedWebsites
{
  [self performMergeFilterLists:@"easylist_content_blocker"];}

- (void)testEasylistPlusExceptionsFilterListsMergeWithWhitelistedWebsites
{
  [self performMergeFilterLists:@"easylist+exceptionrules_content_blocker"];
}

- (void)testHostnameEscaping
{
  NSDictionary<NSString *, NSString *> *input =
  @{@"a.b.c.d": @"a\\.b\\.c\\.d",
    @"[|(){^$*+?.<>[]": @"\\[\\|\\(\\)\\{\\^\\$\\*\\+\\?\\.\\<\\>\\[\\]"
    };

  for (NSString *key in input) {
    id result = [AdblockPlus escapeHostname:key];
    XCTAssert([input[key] isEqualToString:result], @"Hostname is not escaped!");
  }
}

#pragma mark - Whitelisting

- (NSArray<NSString *> *)urls
{
  return
  @[@"https://translate.googleapis.com/translate_a/l?client=te&alpha=true&hl=en&cb=_callbacks_._0iatmzll3",
    @"https://accounts.google.com/o/oauth2/postmessageRelay?parent=http%3A%2F%2Fsimple-adblock.com#rpctoken=416116294&forcesecure=1",
    @"https://apis.google.com/_/scs/apps-static/_/js/k=oz.plusone.en_US.XhIFG_QmQdo.O/m=p1b,p1p/rt=j/sv=1/d=1/ed=1/rs=AGLTcCME3EBo6id2cVvokZvoI_1oIJFGZg/t=zcms/cb=gapi.loaded_1",
    @"http://gidnes.cz/o/fin/sph/dart-sph.png",
    @"http://bbcdn.go.cz.bbelements.com/bb/bb_codesnif.js?v=201506170712",
    @"http://bbcdn.go.cz.bbelements.com/bb/bb_one2n.113.65.77.1.js?v=201505281035",
    @"http://i.idnes.cz/15/063/w230/KRR5c2968_vybuchbustehrad.jpg",
    @"http://www.googletagmanager.com/gtm.js?id=GTM-VFBV"];
}

- (void)testWhitelistedHostname
{
  NSArray<NSString *> *urls = self.urls;

  NSArray<NSString *> *results =
  @[@"translate.googleapis.com",
    @"accounts.google.com",
    @"apis.google.com",
    @"gidnes.cz",
    @"bbcdn.go.cz.bbelements.com",
    @"bbcdn.go.cz.bbelements.com",
    @"i.idnes.cz",
    @"googletagmanager.com"];

  for (int i = 0; i < urls.count; i++) {
    XCTAssert([[urls[i] whitelistedHostname] isEqualToString:results[i]]
              , @"Hostname is not valid");
  }
}

- (void)testWhitelisting
{
  AdblockPlusExtras *adblockPlus = [[AdblockPlusExtras alloc] init];

  NSArray<NSString *> *urls = urls;

  NSArray<NSNumber *> *reuslts = @[@1, @2, @3, @4, @5, @5, @6, @7];

  adblockPlus.whitelistedWebsites = @[];

  for (int i = 0; i < urls.count; i++) {
    [adblockPlus whitelistWebsite:urls[i] index:nil];
    XCTAssert(adblockPlus.whitelistedWebsites.count == reuslts[i].intValue, @"Unexpected number of websites");
  }

  for (NSString *url in urls) {
    XCTAssert([adblockPlus.whitelistedWebsites containsObject:[url whitelistedHostname]], @"Website is not present");
  }
}

#pragma mark - BackgroundNotificationSession

- (void)testBackgroundNotificationSession
{
  AdblockPlusShared *adblockPlus = [[AdblockPlusShared alloc] init];

  NSMutableSet<NSString *> *set = [NSMutableSet set];

  int count = 10;
  for (int i = 0; i < count; i++) {
    NSString *ID = [adblockPlus generateBackgroundNotificationSessionConfigurationIdentifier];
    XCTAssert([adblockPlus isBackgroundNotificationSessionConfigurationIdentifier:ID], @"Identifier was not recognized!");
    [set addObject:ID];
  }

  // Add some tolerance, IDs are randomized, and there is very small change, that there will be at least one match.
  XCTAssert(set.count + 1 >= count, @"Identifier are not unique");
}

@end
