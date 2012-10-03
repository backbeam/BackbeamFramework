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

- (id)initWithEntity:(NSString*)entity dictionary:(NSDictionary*)dict
{
    self = [super init];
    if (self) {
        self._entity = entity;
        self._fields = [[NSMutableDictionary alloc] init];
        
        for (NSString* key in dict.allKeys) {
            id value = [dict objectForKey:key];
            if ([key isEqualToString:@"_id"]) {
                self._identifier = value;
            } else if ([key isEqualToString:@"_created_at"]) {
                self._createdAt = [BBObject dateFromValue:value];
            } else if ([key isEqualToString:@"_updated_at"]) {
                self._updatedAt = [BBObject dateFromValue:value];
            } else if (![key hasPrefix:@"_"]) {
                [self._fields setObject:value forKey:key];
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
    NSString* path = [NSString stringWithFormat:@"/%@", self._entity];
    
    [[Backbeam instance] perform:@"POST" path:path params:nil body:self._fields success:^(id result) {
        if (![result isKindOfClass:[NSDictionary class]]) {
            failure(self, [NSError errorWithDomain:@"Backbeam" code:400 userInfo:nil]);
            return;
        }
        // TODO: check status
        self._identifier = [result objectForKey:@"id"];
        NSLog(@"result %@", result);
        
        success(self);
    } failure:^(NSError* err) {
        NSLog(@"error %@", err);
        failure(self, err);
    }];
}

- (void)update:(SuccessObjectBlock)success failure:(FailureObjectBlock)failure {
    // TODO: if not identifier
    NSString* path = [NSString stringWithFormat:@"/%@/%@", self._entity, self._identifier];
    
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
    NSString* path = [NSString stringWithFormat:@"/%@/%@", self._entity, self._identifier];
    
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


@end
