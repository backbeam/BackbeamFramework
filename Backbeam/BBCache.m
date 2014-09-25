//
//  BBCache.m
//  Backbeam
//
//  Created by Alberto Gimeno Brieba on 29/11/12.
//  Copyright (c) 2012 Level Apps S.L. All rights reserved.
//

#import "BBCache.h"
#import "BBUtils.h"
#import "NSDictionary+SanityChecks.h"

@interface BBCache () {
    dispatch_queue_t diskQueue;
    dispatch_queue_t metaQueue;
}

@property (nonatomic, strong) NSString* dir;
@property (nonatomic, strong) NSString* metaFile;
@property (nonatomic, strong) NSMutableDictionary* objects;
@property (nonatomic, assign) unsigned long long int maxSize;
@property (nonatomic, strong) NSCache* memoryCache;

@end

@implementation BBCache

- (id)initWithDirectory:(NSString*)cacheDir maxSize:(unsigned long long int)maxCacheSize
{
    self = [super init];
    if (self) {
        self.dir = cacheDir;
        self.metaFile = [self.dir stringByAppendingPathComponent:@"meta"];
        self.objects = [NSKeyedUnarchiver unarchiveObjectWithFile:self.metaFile];
        if (!self.objects) {
            self.objects = [[NSMutableDictionary alloc] init];
        }
        self.maxSize = maxCacheSize;
        
        diskQueue = dispatch_queue_create("io.backbeam.cache.disk", DISPATCH_QUEUE_CONCURRENT);
        dispatch_set_target_queue(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), diskQueue);
        
        metaQueue = dispatch_queue_create("io.backbeam.cache.meta", DISPATCH_QUEUE_SERIAL);
        dispatch_set_target_queue(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), metaQueue);
        
        self.memoryCache = [[NSCache alloc] init];
    }
    return self;
}

- (void)setMaxCacheSize:(unsigned long long int)maxCacheSize {
    self.maxSize = maxCacheSize;
}

- (void)read:(NSString*)key threshold:(NSInteger)threshold completion:(CacheRead)completion {
    if (!key) {
        return completion(nil);
    }
    key = [@"_" stringByAppendingString:key];
    NSData *data = [self.memoryCache objectForKey:key];
    if (data) {
        return completion(data);
    }
    __block NSNumber *size = nil;
    dispatch_sync(metaQueue, ^{
        NSMutableDictionary *info = [self.objects objectForKey:key];
        if (info) {
            [info setObject:[NSDate date] forKey:key];
            size = [info numberForKey:@"size"];
        }
    });
    
    if (!size) {
        return completion(nil);
    }
    
    if (size.integerValue > threshold) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0ul), ^{
            NSData *data = [self readDataAndUpdateMetadata:key];
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(data);
            });
        });
    } else {
        completion([self readDataAndUpdateMetadata:key]);
    }
}

- (NSData*)readDataAndUpdateMetadata:(NSString*)key {
    NSData *data = [NSData dataWithContentsOfFile:[self pathForKey:key]];
    if (!data) {
        [self.objects removeObjectForKey:key]; // if the file has been removed for any reason
    } else {
        [self.memoryCache setObject:data forKey:key];
    }
    [self saveMetadata];
    return data;
}

- (void)write:(NSData*)data withKey:(NSString*)key {
    key = [@"_" stringByAppendingString:key];
    [self.memoryCache setObject:data forKey:key];
    dispatch_sync(metaQueue, ^{
        unsigned long long int currentSize = 0;
        for (NSDictionary* dict in self.objects.allValues) {
            currentSize += [dict numberForKey:@"size"].integerValue;
        }
        
        long long int minimumSizeToRemove = currentSize + data.length - self.maxSize;
        if (minimumSizeToRemove >= 0) {
            NSArray *sortedkeys = [self.objects keysSortedByValueUsingComparator:^NSComparisonResult(id a, id b) {
                NSDictionary *da = (NSDictionary*)a;
                NSDictionary *db = (NSDictionary*)b;
                NSDate* sa = [da dateForKey:@"date"];
                NSDate* sb = [db dateForKey:@"date"];
                return [sa compare:sb];
            }];
            NSFileManager* fm = [NSFileManager defaultManager];
            for (NSString* key in sortedkeys) {
                NSDictionary* info = [self.objects objectForKey:key];
                [fm removeItemAtPath:[self.dir stringByAppendingPathComponent:key] error:nil]; // TODO: error
                minimumSizeToRemove -= [info numberForKey:@"size"].integerValue;
                [self.objects removeObjectForKey:key];
                if (minimumSizeToRemove <= 0) {
                    break;
                }
            }
        }
        
        NSNumber* size = [NSNumber numberWithInteger:data.length];
        NSDate* date = [NSDate date];
        NSMutableDictionary* info = [NSMutableDictionary dictionaryWithObjectsAndKeys:size, @"size", date, @"date", nil];
        [self.objects setObject:info forKey:key];
        [self saveMetadata];
        dispatch_async(diskQueue, ^{
            [data writeToFile:[self pathForKey:key] atomically:YES];
        });
    });
}

- (NSString*)pathForKey:(NSString*)key {
    return [self.dir stringByAppendingPathComponent:key];
}

- (void)saveMetadata {
    dispatch_async(metaQueue, ^{
        [NSKeyedArchiver archiveRootObject:self.objects toFile:self.metaFile];
    });
}

- (void)clear {
    dispatch_sync(metaQueue, ^{
        NSFileManager* fm = [NSFileManager defaultManager];
        for (NSString* key in [self.objects allKeys]) {
            [fm removeItemAtPath:[self.dir stringByAppendingPathComponent:key] error:nil]; // TODO: error
        }
        [self.objects removeAllObjects];
        [self saveMetadata];
    });
}

@end
