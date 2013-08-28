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

- (void)setQuery:(NSString*)query;

- (void)setQuery:(NSString*)query
      withParams:(NSArray*)params;

- (void)fetch:(NSInteger)limit
       offset:(NSInteger)offset
      success:(SuccessQueryBlock)success
      failure:(FailureQueryBlock)failure;

- (void)near:(NSString*)field
         lat:(double)lat
         lon:(double)lon
       limit:(NSInteger)limit
     success:(SuccessNearQueryBlock)success
     failure:(FailureQueryBlock)failure;

- (void)bounding:(NSString*)field
           swlat:(double)swlat
           swlon:(double)swlon
           nelat:(double)nelat
           nelon:(double)nelon
           limit:(NSInteger)limit
         success:(SuccessQueryBlock)success
         failure:(FailureQueryBlock)failure;

- (void)setFetchPolicy:(BBFetchPolicy)fetchPolicy;

- (void)removeObjects:(NSInteger)limit
               offset:(NSInteger)offset
              success:(SuccessRemoveBlock)success
              failure:(FailureRemoveBlock)failure;

- (void)removeAllObjects:(SuccessRemoveBlock)success
                 failure:(FailureRemoveBlock)failure;


@end
