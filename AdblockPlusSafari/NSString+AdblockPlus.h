//
//  NSString+AdblockPlus.h
//  AdblockPlusSafari
//
//  Created by Jan Dědeček on 22/10/15.
//  Copyright © 2015 Eyeo GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (AdblockPlus)

- (NSString *__nullable)stringByRemovingHostDisallowedCharacters;

- (NSString *__nullable)whitelistedHostname;

@end
