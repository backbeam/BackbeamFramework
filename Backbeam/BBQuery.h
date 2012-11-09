//
//  BBQuery.h
//  Backbeam
//
//  Created by Alberto Gimeno Brieba on 16/08/12.
//  Copyright (c) 2012 Level Apps S.L. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Common.h"
#import "Backbeam.h"

@class BackbeamSession;

@interface BBQuery : NSObject

- (id)initWith:(BackbeamSession*)session
        entity:(NSString*)entity;

- (void)setQuery:(NSString*)query
      withParams:(NSArray*)params;

- (void)fetch:(NSInteger)limit
       offset:(NSInteger)offset
      success:(SuccessQueryBlock)success
      failure:(FailureQueryBlock)failure;

- (void)next:(NSInteger)limit;

@end
