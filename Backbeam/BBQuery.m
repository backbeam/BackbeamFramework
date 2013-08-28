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
@property (nonatomic, strong) NSArray* _parameters;
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
    self._parameters = [BBUtils stringsFromParams:params];
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
        if (self._parameters) {
            [params setObject:self._parameters forKey:@"params"];
        }
    }
    [params setObject:[NSString stringWithFormat:@"%d", limit]  forKey:@"limit"];
    [params setObject:[NSString stringWithFormat:@"%d", offset] forKey:@"offset"];
    
    [self._session perform:@"GET" path:path params:params fetchPolicy:self._fetchPolicy success:^(id result, BOOL fromCache) {
        if (![result isKindOfClass:[NSDictionary class]]) {
            if (failure) {
                failure([BBError errorWithStatus:@"InvalidResponse" result:result]);
            }
            return;
        }
        NSDictionary* objects = [result dictionaryForKey:@"objects"];
        if (!objects) {
            if (failure) {
                failure([BBError errorWithStatus:@"InvalidResponse" result:result]);
            }
            return;
        }
        NSMutableDictionary* refs = [BBObject objectsWithSession:self._session values:objects references:nil];
        NSArray* ids = [result arrayForKey:@"ids"];
        if (!ids) {
            if (failure) {
                failure([BBError errorWithStatus:@"InvalidResponse" result:result]);
            }
            return;
        }
        NSMutableArray* arr = [[NSMutableArray alloc] initWithCapacity:ids.count];
        for (NSString* identifier in ids) {
            BBObject* obj = [refs objectForKey:identifier];
            if (obj) { // should always exist
                [arr addObject:obj];
            }
        }
        NSNumber* totalCount = [result numberForKey:@"count"];
        
        if (success) {
            success(arr, totalCount.integerValue, fromCache);
        }
    } failure:^(id result, NSError* error) {
        if (result) {
            if (![result isKindOfClass:[NSDictionary class]]) {
                if (failure) {
                    failure([BBError errorWithStatus:@"InvalidResponse" result:result]);
                }
                return;
            }
            NSString* status = [result stringForKey:@"status"];
            if (![status isEqualToString:@"Success"]) {
                if (failure) {
                    failure([BBError errorWithStatus:status result:result]);
                }
                return;
            }
        } else if (failure) {
            failure(error);
        }
    }];
}

- (void)near:(NSString*)field
         lat:(double)lat
         lon:(double)lon
       limit:(NSInteger)limit
     success:(SuccessNearQueryBlock)success
     failure:(FailureQueryBlock)failure {
    
    NSString* path = [NSString stringWithFormat:@"/data/%@/near/%@", self._entity, field];
    NSMutableDictionary* params = [[NSMutableDictionary alloc] init];
    if (self._query) {
        [params setObject:self._query forKey:@"q"];
        if (self._parameters) {
            [params setObject:self._parameters forKey:@"params"];
        }
    }
    [params setObject:[NSString stringWithFormat:@"%f", lat]   forKey:@"lat"];
    [params setObject:[NSString stringWithFormat:@"%f", lon]   forKey:@"lon"];
    [params setObject:[NSString stringWithFormat:@"%d", limit] forKey:@"limit"];
    
    [self._session perform:@"GET" path:path params:params fetchPolicy:self._fetchPolicy success:^(id result, BOOL fromCache) {
        if (![result isKindOfClass:[NSDictionary class]]) {
            if (failure) {
                failure([BBError errorWithStatus:@"InvalidResponse" result:result]);
            }
            return;
        }
        NSDictionary* objects = [result dictionaryForKey:@"objects"];
        if (!objects) {
            if (failure) {
                failure([BBError errorWithStatus:@"InvalidResponse" result:result]);
            }
            return;
        }
        NSMutableDictionary* refs = [BBObject objectsWithSession:self._session values:objects references:nil];
        NSArray* ids = [result arrayForKey:@"ids"];
        if (!ids) {
            if (failure) {
                failure([BBError errorWithStatus:@"InvalidResponse" result:result]);
            }
            return;
        }
        NSMutableArray* arr = [[NSMutableArray alloc] initWithCapacity:ids.count];
        for (NSString* identifier in ids) {
            BBObject* obj = [refs objectForKey:identifier];
            if (obj) { // should always exist
                [arr addObject:obj];
            }
        }
        NSNumber* totalCount = [result numberForKey:@"count"];
        NSArray *distances = [result arrayForKey:@"distances"];
        
        if (success) {
            success(arr, totalCount.integerValue, distances, fromCache);
        }
    } failure:^(id result, NSError* error) {
        if (result) {
            if (![result isKindOfClass:[NSDictionary class]]) {
                if (failure) {
                    failure([BBError errorWithStatus:@"InvalidResponse" result:result]);
                }
                return;
            }
            NSString* status = [result stringForKey:@"status"];
            if (![status isEqualToString:@"Success"]) {
                if (failure) {
                    failure([BBError errorWithStatus:status result:result]);
                }
                return;
            }
        } else if (failure) {
            failure(error);
        }
    }];
}

- (void)bounding:(NSString*)field
           swlat:(double)swlat
           swlon:(double)swlon
           nelat:(double)nelat
           nelon:(double)nelon
           limit:(NSInteger)limit
         success:(SuccessQueryBlock)success
         failure:(FailureQueryBlock)failure {
    
    NSString* path = [NSString stringWithFormat:@"/data/%@/bounding/%@", self._entity, field];
    NSMutableDictionary* params = [[NSMutableDictionary alloc] init];
    if (self._query) {
        [params setObject:self._query forKey:@"q"];
        if (self._parameters) {
            [params setObject:self._parameters forKey:@"params"];
        }
    }
    [params setObject:[NSString stringWithFormat:@"%f", swlat] forKey:@"swlat"];
    [params setObject:[NSString stringWithFormat:@"%f", swlon] forKey:@"swlon"];
    [params setObject:[NSString stringWithFormat:@"%f", nelat] forKey:@"nelat"];
    [params setObject:[NSString stringWithFormat:@"%f", nelon] forKey:@"nelon"];
    [params setObject:[NSString stringWithFormat:@"%d", limit] forKey:@"limit"];
    
    [self._session perform:@"GET" path:path params:params fetchPolicy:self._fetchPolicy success:^(id result, BOOL fromCache) {
        if (![result isKindOfClass:[NSDictionary class]]) {
            if (failure) {
                failure([BBError errorWithStatus:@"InvalidResponse" result:result]);
            }
            return;
        }
        NSDictionary* objects = [result dictionaryForKey:@"objects"];
        if (!objects) {
            if (failure) {
                failure([BBError errorWithStatus:@"InvalidResponse" result:result]);
            }
            return;
        }
        NSMutableDictionary* refs = [BBObject objectsWithSession:self._session values:objects references:nil];
        NSArray* ids = [result arrayForKey:@"ids"];
        if (!ids) {
            if (failure) {
                failure([BBError errorWithStatus:@"InvalidResponse" result:result]);
            }
            return;
        }
        NSMutableArray* arr = [[NSMutableArray alloc] initWithCapacity:ids.count];
        for (NSString* identifier in ids) {
            BBObject* obj = [refs objectForKey:identifier];
            if (obj) { // should always exist
                [arr addObject:obj];
            }
        }
        NSNumber* totalCount = [result numberForKey:@"count"];
        
        if (success) {
            success(arr, totalCount.integerValue, fromCache);
        }
    } failure:^(id result, NSError* error) {
        if (result) {
            if (![result isKindOfClass:[NSDictionary class]]) {
                if (failure) {
                    failure([BBError errorWithStatus:@"InvalidResponse" result:result]);
                }
                return;
            }
            NSString* status = [result stringForKey:@"status"];
            if (![status isEqualToString:@"Success"]) {
                if (failure) {
                    failure([BBError errorWithStatus:status result:result]);
                }
                return;
            }
        } else if (failure) {
            failure(error);
        }
    }];
}

- (void)_removeObjects:(NSString*)limit offset:(NSInteger)offset success:(SuccessRemoveBlock)success failure:(FailureRemoveBlock)failure {
    
    NSString* path = [NSString stringWithFormat:@"/data/%@", self._entity];
    NSMutableDictionary* params = [[NSMutableDictionary alloc] init];
    if (self._query) {
        [params setObject:self._query forKey:@"q"];
        if (self._parameters) {
            [params setObject:self._parameters forKey:@"params"];
        }
    }
    [params setObject:[NSString stringWithFormat:@"%d", offset] forKey:@"offset"];
    [params setObject:[NSString stringWithFormat:@"%@", limit] forKey:@"limit"];
    
    [self._session perform:@"DELETE" path:path params:params fetchPolicy:self._fetchPolicy success:^(id result, BOOL fromCache) {
        if (![result isKindOfClass:[NSDictionary class]]) {
            if (failure) {
                failure([BBError errorWithStatus:@"InvalidResponse" result:result]);
            }
            return;
        }
        NSNumber* removedCount = [result numberForKey:@"removed"];
        
        if (success) {
            success(removedCount.integerValue);
        }
    } failure:^(id result, NSError* error) {
        if (result) {
            if (![result isKindOfClass:[NSDictionary class]]) {
                if (failure) {
                    failure([BBError errorWithStatus:@"InvalidResponse" result:result]);
                }
                return;
            }
            NSString* status = [result stringForKey:@"status"];
            if (![status isEqualToString:@"Success"]) {
                if (failure) {
                    failure([BBError errorWithStatus:status result:result]);
                }
                return;
            }
        } else if (failure) {
            failure(error);
        }
    }];
}

- (void)removeObjects:(NSInteger)limit offset:(NSInteger)offset success:(SuccessRemoveBlock)success failure:(FailureRemoveBlock)failure {
    NSString *_limit = [NSString stringWithFormat:@"%d", limit];
    [self _removeObjects:_limit offset:offset success:success failure:failure];
}

- (void)removeAllObjects:(SuccessRemoveBlock)success failure:(FailureRemoveBlock)failure {
    [self _removeObjects:@"all" offset:0 success:success failure:failure];
}

@end
