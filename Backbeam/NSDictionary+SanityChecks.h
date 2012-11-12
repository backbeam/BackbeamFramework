//
//  NSDictionary+SanityChecks.h
//  Backbeam
//
//  Created by Alberto Gimeno Brieba on 09/11/12.
//  Copyright (c) 2012 Level Apps S.L. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSDictionary (SanityChecks)

- (NSString*)stringForKey:(id)key;

- (NSNumber*)numberForKey:(id)key;

- (NSDate*)dateForKey:(id)key;

- (NSDictionary*)dictionaryForKey:(id)key;

- (NSMutableDictionary*)mutableDictionaryForKey:(id)key;

- (NSArray*)arrayForKey:(id)key;

- (NSArray*)mutableArrayForKey:(id)key;

@end
