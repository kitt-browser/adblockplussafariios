//
//  NSString+AdblockPlus.m
//  AdblockPlusSafari
//
//  Created by Jan Dědeček on 22/10/15.
//  Copyright © 2015 Eyeo GmbH. All rights reserved.
//

#import "NSString+AdblockPlus.h"

@implementation NSString (AdblockPlus)

- (NSString *__nullable)stringByRemovingHostDisallowedCharacters
{
  NSMutableCharacterSet *set = [[NSCharacterSet URLHostAllowedCharacterSet] mutableCopy];
  // Some of those characters are allowed in above set.
  [set removeCharactersInString:@"\\|()[{^$*?<>"];
  [set invert];
  return [[self componentsSeparatedByCharactersInSet:set] componentsJoinedByString:@""];
}

- (NSString *__nullable)whitelistedHostname
{
  // Convert to lower case
  NSString *input = [self lowercaseString];

  // Trim hostname
  NSString *hostname = [input stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

  // Prepend scheme if needed
  if (![hostname hasPrefix:@"http://"] && ![hostname hasPrefix:@"https://"]) {
    hostname = [@"http://" stringByAppendingString:hostname];
  }

  // Try to get host from URL
  hostname = [[NSURL URLWithString:hostname] host];
  if (hostname.length == 0) {
    hostname = self;
  }

  // Remove not allowed characters
  hostname = [hostname stringByRemovingHostDisallowedCharacters];

  // Remove www prefix
  if ([hostname hasPrefix:@"www."]) {
    hostname = [hostname substringFromIndex:@"www.".length];
  }

  return hostname;
}

@end
