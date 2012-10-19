//
//  BBQuery.m
//  Callezeta
//
//  Created by Alberto Gimeno Brieba on 16/08/12.
//  Copyright (c) 2012 Level Apps S.L. All rights reserved.
//

#import "BBQuery.h"
#import "Backbeam.h"

@interface BBQuery ()

@property (nonatomic, strong) NSString* _cursor; // to call [self next]
@property (nonatomic, strong) NSString* _entity;
@property (nonatomic, strong) NSString* _query;
@property (nonatomic, strong) NSMutableArray* _parameters;

@end

@implementation BBQuery

+ (BBQuery*)queryForEntity:(NSString*)entity {
    BBQuery* query = [[BBQuery alloc] init];
    query._parameters = [[NSMutableArray alloc] init];
    query._entity = entity;
    return query;
}

- (void)setQuery:(NSString*)query withParams:(NSArray*)params {
    self._query = query;
    self._cursor = nil;
    [self._parameters removeAllObjects];
    for (NSObject* param in params) {
        [self._parameters addObject:[self stringFromParam:param]];
    }
    self._cursor = nil;
}

- (NSString*)stringFromParam:(NSObject*)obj {
    return [obj description];
}

- (void)fetch:(NSInteger)limit offset:(NSInteger)offset success:(SuccessQueryBlock)success failure:(FailureQueryBlock)failure {
    
    NSString* path = [NSString stringWithFormat:@"/%@", self._entity];
    NSMutableDictionary* params = [[NSMutableDictionary alloc] init];
    if (self._query) {
        [params setObject:self._query forKey:@"q"];
    }
    if (self._parameters) {
        [params setObject:self._parameters forKey:@"params"];
    }
    [params setObject:[NSString stringWithFormat:@"%d", limit]  forKey:@"limit"];
    [params setObject:[NSString stringWithFormat:@"%d", offset] forKey:@"offset"];
    
    [[Backbeam instance] perform:@"GET" path:path params:params body:nil success:^(id result) {
        if (![result isKindOfClass:[NSDictionary class]]) {
            failure([NSError errorWithDomain:@"Backbeam" code:400 userInfo:nil]);
            return;
        }
        
        NSDictionary* references = [result objectForKey:@"references"];
        NSMutableDictionary* refs = [[NSMutableDictionary alloc] initWithCapacity:references.count];
        if (references) {
            for (NSString* identifier in references) {
                NSDictionary* object = [references objectForKey:identifier];
                NSString* type = [object objectForKey:@"_type"];
                BBObject* obj = [[BBObject alloc] initWithEntity:type dictionary:object references:nil identifier:identifier];
                [refs setObject:obj forKey:identifier];
            }
        }
        
        NSArray* objects = [result objectForKey:@"objects"];
        NSMutableArray* arr = [[NSMutableArray alloc] initWithCapacity:objects.count];
        for (NSDictionary* dict in objects) {
            BBObject* obj = [[BBObject alloc] initWithEntity:self._entity dictionary:dict references:refs identifier:nil];
            [arr addObject:obj];
        }
        
        success(arr);
    } failure:^(NSError* err) {
        NSLog(@"error %@", err);
        failure(err);
    }];
    
}

- (void)next:(NSInteger)limit {
    
}

@end
