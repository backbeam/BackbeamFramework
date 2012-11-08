//
//  BBObject.m
//  Callezeta
//
//  Created by Alberto Gimeno Brieba on 16/08/12.
//  Copyright (c) 2012 Level Apps S.L. All rights reserved.
//

#import "BBObject.h"
#import "Backbeam.h"

@interface BBObject ()

@property (nonatomic, strong) NSString* _identifier;
@property (nonatomic, strong) NSString* _entity;
@property (nonatomic, strong) NSMutableDictionary* _fields;
@property (nonatomic, strong) NSDate* _createdAt;
@property (nonatomic, strong) NSDate* _updatedAt;

@end

@implementation BBObject

- (id)initWithEntity:(NSString*)entity
{
    self = [super init];
    if (self) {
        self._entity = entity;
        self._fields = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (id)initWithEntity:(NSString*)entity dictionary:(NSDictionary*)dict references:(NSDictionary *)references identifier:(NSString*)identifier
{
    self = [super init];
    if (self) {
        self._entity = entity;
        self._fields = [[NSMutableDictionary alloc] init];
        self._identifier = identifier;
        
        for (NSString* key in dict.allKeys) {
            NSObject* value = [dict objectForKey:key];
            if ([key isEqualToString:@"id"]) {
                self._identifier = [value description];
            } else if ([key isEqualToString:@"created_at"]) {
                self._createdAt = [BBObject dateFromValue:value];
            } else if ([key isEqualToString:@"updated_at"]) {
                self._updatedAt = [BBObject dateFromValue:value];
            } else {
                NSRange range = [key rangeOfString:@"#"];
                if (range.location != NSNotFound) {
                    NSString* _key = [key substringToIndex:range.location];
                    NSString* type = [key substringFromIndex:range.location+1];
                    if ([type isEqualToString:@"d"] && [value isKindOfClass:[NSNumber class]]) {
                        NSNumber* n = (NSNumber*)value;
                        value = [NSDate dateWithTimeIntervalSince1970:n.doubleValue/1000];
                    } else if ([type isEqualToString:@"r"] && [value isKindOfClass:[NSDictionary class]]) {
                        NSDictionary* dict = (NSDictionary*)value;
                        NSNumber* count = [dict objectForKey:@"count"];
                        NSArray* arr = [dict objectForKey:@"result"];
                        NSMutableArray* refs = [[NSMutableArray alloc] initWithCapacity:arr.count];
                        for (NSString* identifier in arr) {
                            [refs addObject:[references objectForKey:identifier]];
                        }
                        value = [NSDictionary dictionaryWithObjectsAndKeys:refs, @"result", count, @"count", nil];
                    } else if ([type isEqualToString:@"r"] && [value isKindOfClass:[NSString class]]) {
                        value = [references objectForKey:value];
                    }
                    [self._fields setObject:value forKey:_key];
                }
            }
        }
    }
    return self;
}

+ (NSDate*)dateFromValue:(id)value {
    NSTimeInterval time = [(NSNumber*)value doubleValue]/1000;
    return [NSDate dateWithTimeIntervalSince1970:time];;
}

- (NSString*)identifier {
    return self._identifier;
}

- (NSString*)entity {
    return self._entity;
}

- (NSDate*)createdAt {
    return self._createdAt;
}

- (NSDate*)updatedAt {
    return self._updatedAt;
}

- (NSString*)stringForKey:(NSString*)key {
    id obj = [self._fields objectForKey:key];
    if ([obj isKindOfClass:[NSString class]]) {
        return (NSString*)obj;
    }
    return nil;
}

- (NSDate*)dateForKey:(NSString*)key {
    id obj = [self._fields objectForKey:key];
    if ([obj isKindOfClass:[NSDate class]]) {
        return (NSDate*)obj;
    }
    return nil;
}

- (NSNumber*)numberForKey:(NSString*)key {
    id obj = [self._fields objectForKey:key];
    if ([obj isKindOfClass:[NSNumber class]]) {
        return (NSNumber*)obj;
    }
    return nil;
}

- (BBObject*)referenceForKey:(NSString*)key {
    id obj = [self._fields objectForKey:key];
    if ([obj isKindOfClass:[NSNumber class]]) {
        return (BBObject*)obj;
    }
    return nil;
}

- (void)setObject:(id)obj forKey:(NSString*)key {
    [self._fields setObject:obj forKey:key];
}

- (id)objectForKey:(NSString*)key {
    return [self._fields objectForKey:key];
}

- (void)removeObjectForKey:(NSString*)key {
    
}

- (void)increment:(NSString*)key by:(NSInteger)value {
    NSNumber* n = [self numberForKey:key];
    if (n) {
        n = [NSNumber numberWithInteger:n.integerValue+value];
    } else {
        n = [NSNumber numberWithInteger:value];
    }
    [self._fields setObject:n forKey:key];
}

- (void)insert:(SuccessObjectBlock)success failure:(FailureObjectBlock)failure {
    NSString* path = [NSString stringWithFormat:@"/data/%@", self._entity];
    
    [[Backbeam instance] perform:@"POST" path:path params:nil body:self._fields success:^(id result) {
        if (![result isKindOfClass:[NSDictionary class]]) {
            failure(self, [NSError errorWithDomain:@"Backbeam" code:400 userInfo:nil]);
            return;
        }
        // TODO: check status
        NSDictionary* object = [result objectForKey:@"object"];
        self._identifier = [object objectForKey:@"id"];
        NSLog(@"result %@", result);
        
        success(self);
    } failure:^(NSError* err) {
        NSLog(@"error %@", err);
        failure(self, err);
    }];
}

- (void)update:(SuccessObjectBlock)success failure:(FailureObjectBlock)failure {
    // TODO: if not identifier
    NSString* path = [NSString stringWithFormat:@"/data/%@/%@", self._entity, self._identifier];
    
    NSLog(@"fields %@", self._fields);
    [[Backbeam instance] perform:@"PUT" path:path params:nil body:self._fields success:^(id result) {
        if (![result isKindOfClass:[NSDictionary class]]) {
            failure(self, [NSError errorWithDomain:@"Backbeam" code:400 userInfo:nil]);
            return;
        }
        NSLog(@"result %@", result);
        
        success(self);
    } failure:^(NSError* err) {
        NSLog(@"error %@", err);
        failure(self, err);
    }];
}

- (void)remove:(SuccessObjectBlock)success failure:(FailureObjectBlock)failure {
    // TODO: if not identifier
    NSString* path = [NSString stringWithFormat:@"/data/%@/%@", self._entity, self._identifier];
    
    [[Backbeam instance] perform:@"DELETE" path:path params:nil body:self._fields success:^(id result) {
        if (![result isKindOfClass:[NSDictionary class]]) {
            failure(self, [NSError errorWithDomain:@"Backbeam" code:400 userInfo:nil]);
            return;
        }
        NSLog(@"result %@", result);
        
        success(self);
    } failure:^(NSError* err) {
        NSLog(@"error %@", err);
        failure(self, err);
    }];
}

- (UIImage*)imageWithSize:(CGSize)size success:(SuccessImageBlock)success {
    return [[Backbeam instance] image:self._identifier withSize:size success:success];
}

@end
