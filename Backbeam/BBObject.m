//
//  BBObject.m
//  Backbeam
//
//  Created by Alberto Gimeno Brieba on 16/08/12.
//  Copyright (c) 2012 Level Apps S.L. All rights reserved.
//

#import "BBObject.h"
#import "BBError.h"

@interface BBObject ()

@property (nonatomic, strong) NSString* _identifier;
@property (nonatomic, strong) NSString* _entity;
@property (nonatomic, strong) NSMutableDictionary* _fields;
@property (nonatomic, strong) NSMutableDictionary* _commands;
@property (nonatomic, strong) NSDate* _createdAt;
@property (nonatomic, strong) NSDate* _updatedAt;
@property (nonatomic, strong) BackbeamSession* _session;

@end

@implementation BBObject

- (id)initWith:(BackbeamSession*)session entity:(NSString*)entity
{
    self = [super init];
    if (self) {
        self._entity = entity;
        self._fields = [[NSMutableDictionary alloc] init];
        self._commands = [[NSMutableDictionary alloc] init];
        self._session = session;
    }
    return self;
}

- (id)initWith:(BackbeamSession*)session entity:(NSString*)entity andIdentifier:(NSString*)identifier
{
    self = [super init];
    if (self) {
        self._entity = entity;
        self._identifier = identifier;
        self._fields = [[NSMutableDictionary alloc] init];
        self._commands = [[NSMutableDictionary alloc] init];
        self._session = session;
    }
    return self;
}

- (id)initWith:(BackbeamSession*)session entity:(NSString*)entity dictionary:(NSDictionary*)dict references:(NSDictionary *)references identifier:(NSString*)identifier
{
    self = [super init];
    if (self) {
        self._entity = entity;
        self._fields = [[NSMutableDictionary alloc] init];
        self._commands = [[NSMutableDictionary alloc] init];
        self._identifier = identifier;
        self._session = session;
        [self fillValuesWithDictionary:dict andReferences:references];
    }
    return self;
}

- (void)fillValuesWithDictionary:(NSDictionary*)dict andReferences:(NSDictionary*)references {
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
                        NSDictionary* obj = [references objectForKey:identifier];
                        if (obj) { // sanity check
                            [refs addObject:obj];
                        }
                    }
                    value = [NSDictionary dictionaryWithObjectsAndKeys:refs, @"result", count, @"count", nil];
                } else if ([type isEqualToString:@"r"] && [value isKindOfClass:[NSString class]]) {
                    value = [references objectForKey:value];
                }
                if (value) { // sanity check
                    [self._fields setObject:value forKey:_key];
                }
            }
        }
    }
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
    [self._commands setObject:obj forKey:key];
}

- (id)objectForKey:(NSString*)key {
    return [self._fields objectForKey:key];
}

- (void)removeObjectForKey:(NSString*)key {
    [self._fields removeObjectForKey:key];
    [self._commands setObject:[NSNull null] forKey:key];
}

- (void)increment:(NSString*)key by:(NSInteger)value {
    // TODO: send command _incr-
    NSNumber* n = [self numberForKey:key];
    if (n) {
        n = [NSNumber numberWithInteger:n.integerValue+value];
    } else {
        n = [NSNumber numberWithInteger:value];
    }
    [self._fields setObject:n forKey:key];
}

- (void)processResponse:(id)result success:(SuccessOperationObjectBlock)success failure:(FailureObjectBlock)failure {
    if (![result isKindOfClass:[NSDictionary class]]) {
        failure(self, [BBError errorWithStatus:@"InvalidResponse" result:result]);
        return;
    }
    
    NSString* status     = [result stringForKey:@"status"];
    NSDictionary* object = [result dictionaryForKey:@"object"];
    
    if (!status || !object) {
        failure(self, [BBError errorWithStatus:@"InvalidResponse" result:result]);
        return;
    }
    
    if (![status isEqualToString:@"Success"] && ![status isEqualToString:@"PendingValidation"]) {
        failure(self, [BBError errorWithStatus:status result:result]);
        return;
    }
    
    [self fillValuesWithDictionary:object andReferences:nil];
    success(status, self);
}

- (void)processResponse:(id)result error:(NSError*)err failure:(FailureObjectBlock)failure {
    if (![result isKindOfClass:[NSDictionary class]]) {
        failure(self, [BBError errorWithStatus:@"InvalidResponse" result:result]);
        return;
    }
    
    NSString* status = [result stringForKey:@"status"];
    if (status) {
        failure(self, [BBError errorWithStatus:status result:result]);
        return;
    }
    
    failure(self, [BBError errorWithError:err]);
}

- (BOOL)save:(SuccessObjectBlock)success failure:(FailureObjectBlock)failure {
    if (!self._entity) { return NO; }
    
    NSString* path = nil;
    NSString* method = nil;
    if (self._identifier) {
        method = @"PUT";
        path = [NSString stringWithFormat:@"/data/%@/%@", self._entity, self._identifier];
    } else {
        method = @"POST";
        path = [NSString stringWithFormat:@"/data/%@", self._entity];
    }
    
    [self._session perform:method path:path params:nil body:self._commands success:^(id result) {
        [self._commands removeAllObjects];
        [self processResponse:result success:^(NSString* status, BBObject* object) {
            if ([self.entity isEqualToString:@"user"]) {
                [self._fields removeObjectForKey:@"password"];
            }
            if ([self.entity isEqualToString:@"user"] && [method isEqualToString:@"POST"]) {
                [Backbeam logout]; // logout previous user
                if ([status isEqualToString:@"Success"]) { // not PendingValidation
                    // TODO: set current user
                    NSLog(@"set current user!");
                    [self._session setLoggedUser:self];
                }
                success(object);
            } else {
                success(object);
            }
        } failure:failure];
    } failure:^(id result, NSError* err) {
        [self processResponse:result error:err failure:failure];
    }];
    return YES;
}

- (BOOL)remove:(SuccessObjectBlock)success failure:(FailureObjectBlock)failure {
    if (!self._entity || !self._identifier) { return NO; }
    NSString* path = [NSString stringWithFormat:@"/data/%@/%@", self._entity, self._identifier];
    
    [self._session perform:@"DELETE" path:path params:nil body:nil success:^(id result) {
        [self processResponse:result success:^(NSString* status, BBObject* object) {
            // TODO: if (is current user) logout; return;
            success(self);
        } failure:failure];
    } failure:^(id result, NSError* err) {
        [self processResponse:result error:err failure:failure];
    }];
    return YES;
}

- (BOOL)refresh:(SuccessObjectBlock)success failure:(FailureObjectBlock)failure {
    if (!self._entity || !self._identifier) { return NO; }
    NSString* path = [NSString stringWithFormat:@"/data/%@/%@", self._entity, self._identifier];
    
    [self._session perform:@"GET" path:path params:nil body:nil success:^(id result) {
        [self processResponse:result success:^(NSString* status, BBObject* object) {
            success(object);
        } failure:failure];
    } failure:^(id result, NSError* err) {
        [self processResponse:result error:err failure:failure];
    }];
    return YES;
}

- (UIImage*)imageWithSize:(CGSize)size success:(SuccessImageBlock)success {
    return [self._session image:self._identifier withSize:size success:success];
}

@end
