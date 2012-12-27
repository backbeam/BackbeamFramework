//
//  BBCache.h
//  Backbeam
//
//  Created by Alberto Gimeno Brieba on 29/11/12.
//  Copyright (c) 2012 Level Apps S.L. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface BBCache : NSObject

- (id)initWithDirectory:(NSString*)cacheDir maxSize:(unsigned long long int)maxCacheSize;

- (NSData*)read:(NSString*)key;

- (void)write:(NSData*)data withKey:(NSString*)key;

- (void)clear;

@end
