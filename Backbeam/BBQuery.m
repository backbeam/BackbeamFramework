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

@property (nonatomic, strong) NSString* cursor; // to call [self next]
@property (nonatomic, strong) NSString* entity;
@property (nonatomic, strong) NSString* query;
@property (nonatomic, strong) NSMutableArray* parameters;

@end

@implementation BBQuery

+ (BBQuery*)queryForEntity:(NSString*)entity {
    BBQuery* query = [[BBQuery alloc] init];
    query.parameters = [[NSMutableArray alloc] init];
    query.entity = entity;
    return query;
}

- (void)setQuery:(NSString*)query {
    self.query = query;
    self.cursor = nil;
}

- (void)addParam:(NSObject*)param {
    [self.parameters addObject:param];
    self.cursor = nil;
}

- (void)setParams:(NSArray*)params {
    self.parameters = [[NSMutableArray alloc] initWithArray:params];
    self.cursor = nil;
}

- (void)fetch:(NSInteger)limit offset:(NSInteger)offset success:(SuccessQueryBlock)success failure:(FailureQueryBlock)failure {
    
    NSString* path = [NSString stringWithFormat:@"/%@", self.entity];
    [[Backbeam instance] perform:@"GET" path:path params:nil body:nil success:^(id result) {
        if (![result isKindOfClass:[NSDictionary class]]) {
            failure([NSError errorWithDomain:@"Backbeam" code:400 userInfo:nil]);
            return;
        }
        
        NSArray* objects = [result objectForKey:@"objects"];
        NSMutableArray* arr = [[NSMutableArray alloc] initWithCapacity:objects.count];
        for (NSDictionary* dict in objects) {
            BBObject* obj = [[BBObject alloc] initWithEntity:self.entity dictionary:dict];
            [arr addObject:obj];
        }
        
        success(arr, nil);
    } failure:^(NSError* err) {
        NSLog(@"error %@", err);
        failure(err);
    }];
    
}

- (void)next:(NSInteger)limit {
    
}

@end
