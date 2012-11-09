//
//  NSDictionary+SanityChecks.m
//  Backbeam
//
//  Created by Alberto Gimeno Brieba on 09/11/12.
//  Copyright (c) 2012 Level Apps S.L. All rights reserved.
//

#import "NSDictionary+SanityChecks.h"

@implementation NSDictionary (SanityChecks)

- (NSString*)stringForKey:(id)key {
    id value = [self objectForKey:key];
    if (value == nil || value == [NSNull null] || ![value isKindOfClass:[NSString class]]) {
        return nil;
    }
    return (NSString*)value;
}

- (NSNumber*)numberForKey:(id)key {
    id value = [self objectForKey:key];
    if (value == nil || value == [NSNull null] || ![value isKindOfClass:[NSNumber class]]) {
        return nil;
    }
    return (NSNumber*)value;
}

- (NSDictionary*)dictionaryForKey:(id)key {
    id value = [self objectForKey:key];
    if (value == nil || value == [NSNull null] || ![value isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    return (NSDictionary*)value;
}

- (NSArray*)arrayForKey:(id)key {
    id value = [self objectForKey:key];
    if (value == nil || value == [NSNull null] || ![value isKindOfClass:[NSArray class]]) {
        return nil;
    }
    return (NSArray*)value;
}

@end
