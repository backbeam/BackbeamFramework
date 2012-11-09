//
//  NSDictionary+SanityChecks.h
//  Callezeta
//
//  Created by Alberto Gimeno Brieba on 09/11/12.
//  Copyright (c) 2012 Level Apps S.L. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSDictionary (SanityChecks)

- (NSString*)stringForKey:(id)key;
- (NSNumber*)numberForKey:(id)key;
- (NSDictionary*)dictionaryForKey:(id)key;
- (NSArray*)arrayForKey:(id)key;

@end
