//
//  BBQuery.h
//  Callezeta
//
//  Created by Alberto Gimeno Brieba on 16/08/12.
//  Copyright (c) 2012 Level Apps S.L. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void(^SuccessQueryBlock)(NSArray* objects, NSDictionary* references);
typedef void(^FailureQueryBlock)(NSError* err);

@interface BBQuery : NSObject

+ (BBQuery*)queryForEntity:(NSString*)entity;
- (void)setQuery:(NSString*)query;
- (void)addParam:(NSObject*)param;
- (void)setParams:(NSArray*)params;
- (void)fetch:(NSInteger)limit offset:(NSInteger)offset success:(SuccessQueryBlock)success failure:(FailureQueryBlock)failure;
- (void)next:(NSInteger)limit;

@end
