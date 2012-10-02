//
//  BBObject.m
//  Callezeta
//
//  Created by Alberto Gimeno Brieba on 16/08/12.
//  Copyright (c) 2012 Level Apps S.L. All rights reserved.
//

#import "BBObject.h"

@interface BBObject ()

@property (nonatomic, strong) NSString* _identifier;
@property (nonatomic, strong) NSString* _entity;
@property (nonatomic, strong) NSMutableDictionary* fields;
@property (nonatomic, strong) NSDate* _createdAt;
@property (nonatomic, strong) NSDate* _updatedAt;

@end

@implementation BBObject

- (id)initWithEntity:(NSString*)entity dictionary:(NSDictionary*)dict
{
    self = [super init];
    if (self) {
        self._entity = entity;
        self.fields = [[NSMutableDictionary alloc] init];
        
        for (NSString* key in dict.allKeys) {
            id value = [dict objectForKey:key];
            if ([key isEqualToString:@"_id"]) {
                self._identifier = value;
            } else if ([key isEqualToString:@"_created_at"]) {
                self._createdAt = [BBObject dateFromValue:value];
            } else if ([key isEqualToString:@"_updated_at"]) {
                self._updatedAt = [BBObject dateFromValue:value];
            } else if (![key hasPrefix:@"_"]) {
                [self.fields setObject:value forKey:key];
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
    id obj = [self.fields objectForKey:key];
    if ([obj isKindOfClass:[NSString class]]) {
        return (NSString*)obj;
    }
    return nil;
}

- (NSDate*)dateForKey:(NSString*)key {
    id obj = [self.fields objectForKey:key];
    if ([obj isKindOfClass:[NSDate class]]) {
        return (NSDate*)obj;
    }
    return nil;
}

- (NSNumber*)numberForKey:(NSString*)key {
    id obj = [self.fields objectForKey:key];
    if ([obj isKindOfClass:[NSNumber class]]) {
        return (NSNumber*)obj;
    }
    return nil;
}

- (BBObject*)referenceForKey:(NSString*)key {
    id obj = [self.fields objectForKey:key];
    if ([obj isKindOfClass:[NSNumber class]]) {
        return (BBObject*)obj;
    }
    return nil;
}

- (void)setObject:(id)obj forKey:(NSString*)key {
    [self.fields setObject:obj forKey:key];
}

- (id)objectForKey:(NSString*)key {
    return [self.fields objectForKey:key];
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
    [self.fields setObject:n forKey:key];
}

- (void)saveInBackground:(SuccessBlock)success failure:(FailureBlock)failure {
    
}

- (void)deleteInBackground:(SuccessBlock)success failure:(FailureBlock)failure {
    
}


@end
