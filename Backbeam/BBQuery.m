//
//  BBQuery.m
//  Backbeam
//
//  Created by Alberto Gimeno Brieba on 16/08/12.
//  Copyright (c) 2012 Level Apps S.L. All rights reserved.
//

#import "BBQuery.h"
#import "BBError.h"
#import "BBUtils.h"

@interface BBQuery ()

@property (nonatomic, strong) NSString* _cursor; // to call [self next]
@property (nonatomic, strong) NSString* _entity;
@property (nonatomic, strong) NSString* _query;
@property (nonatomic, strong) NSMutableArray* _parameters;
@property (nonatomic, assign) BBFetchPolicy _fetchPolicy;
@property (nonatomic, strong) BackbeamSession* _session;

@end

@implementation BBQuery

- (id)initWith:(BackbeamSession*)session entity:(NSString*)entity
{
    self = [super init];
    if (self) {
        self._session = session;
        self._entity = entity;
        self._parameters = [[NSMutableArray alloc] init];
        self._fetchPolicy = BBFetchPolicyRemoteOnly;
    }
    return self;
}

- (void)setQuery:(NSString*)query {
    [self setQuery:query withParams:nil];
}

- (void)setQuery:(NSString*)query withParams:(NSArray*)params {
    self._query = query;
    self._cursor = nil;
    [self._parameters removeAllObjects];
    for (id param in params) {
        [self._parameters addObject:[BBUtils stringFromObject:param addEntity:YES]];
    }
    self._cursor = nil;
}

- (void)setFetchPolicy:(BBFetchPolicy)fetchPolicy {
    self._fetchPolicy = fetchPolicy;
}

- (void)fetch:(NSInteger)limit offset:(NSInteger)offset success:(SuccessQueryBlock)success failure:(FailureQueryBlock)failure {
    NSString* path = [NSString stringWithFormat:@"/data/%@", self._entity];
    NSMutableDictionary* params = [[NSMutableDictionary alloc] init];
    if (self._query) {
        [params setObject:self._query forKey:@"q"];
    }
    if (self._parameters) {
        [params setObject:self._parameters forKey:@"params"];
    }
    [params setObject:[NSString stringWithFormat:@"%d", limit]  forKey:@"limit"];
    [params setObject:[NSString stringWithFormat:@"%d", offset] forKey:@"offset"];
    
    [self._session perform:@"GET" path:path params:params fetchPolicy:self._fetchPolicy success:^(id result, BOOL fromCache) {
        if (![result isKindOfClass:[NSDictionary class]]) {
            failure([BBError errorWithStatus:@"InvalidResponse" result:result]);
            return;
        }
        NSDictionary* references = [result dictionaryForKey:@"references"];
        if (!references) {
            failure([BBError errorWithStatus:@"InvalidResponse" result:result]);
            return;
        }
        NSMutableDictionary* refs = [[NSMutableDictionary alloc] initWithCapacity:references.count];
        if (references) {
            for (NSString* identifier in references) {
                NSDictionary* object = [references objectForKey:identifier];
                NSString* type = [object objectForKey:@"_type"];
                BBObject* obj = [[BBObject alloc] initWith:self._session entity:type dictionary:object references:nil identifier:identifier];
                [refs setObject:obj forKey:identifier];
            }
        }
        
        NSArray* objects = [result arrayForKey:@"objects"];
        if (!objects) {
            failure([BBError errorWithStatus:@"InvalidResponse" result:result]);
            return;
        }
        NSMutableArray* arr = [[NSMutableArray alloc] initWithCapacity:objects.count];
        for (NSDictionary* dict in objects) {
            BBObject* obj = [[BBObject alloc] initWith:self._session entity:self._entity dictionary:dict references:refs identifier:nil];
            [arr addObject:obj];
        }
        NSNumber* totalCount = [result numberForKey:@"count"];
        
        success(arr, totalCount.integerValue);
    } failure:^(id result, NSError* error) {
        if (error) {
            failure(error);
            return;
        }
        if (![result isKindOfClass:[NSDictionary class]]) {
            failure([BBError errorWithStatus:@"InvalidResponse" result:result]);
            return;
        }
        NSString* status = [result stringForKey:@"status"];
        if (![status isEqualToString:@"Success"]) {
            failure([BBError errorWithStatus:status result:result]);
            return;
        }
    }];
}

- (void)next:(NSInteger)limit {
    
}

@end
