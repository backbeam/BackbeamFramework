//
//  BBCache.h
//  Backbeam
//
//  Created by Alberto Gimeno Brieba on 29/11/12.
//  Copyright (c) 2012 Level Apps S.L. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void(^CacheRead)(NSData *data);

@interface BBCache : NSObject

- (id)initWithDirectory:(NSString*)cacheDir maxSize:(unsigned long long int)maxCacheSize;

- (void)read:(NSString*)key threshold:(NSInteger)threshold completion:(CacheRead)completion;

- (void)write:(NSData*)data withKey:(NSString*)key;

- (void)clear;

- (void)setMaxCacheSize:(unsigned long long int)maxCacheSize;

@end
