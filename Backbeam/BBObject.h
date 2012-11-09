//
//  BBObject.h
//  Backbeam
//
//  Created by Alberto Gimeno Brieba on 16/08/12.
//  Copyright (c) 2012 Level Apps S.L. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Common.h"
#import "Backbeam.h"

@class BBObject;
@class BackbeamSession;

@interface BBObject : NSObject

- (id)initWith:(BackbeamSession*)session entity:(NSString*)entity;
- (id)initWith:(BackbeamSession*)session entity:(NSString*)entity;
- (id)initWith:(BackbeamSession*)session entity:(NSString*)entity andIdentifier:(NSString*)identifier;
- (id)initWith:(BackbeamSession*)session entity:(NSString*)entity dictionary:(NSDictionary*)dict references:(NSDictionary *)references identifier:(NSString*)identifier;

- (NSString*)identifier;
- (NSString*)entity;
- (NSDate*)createdAt;
- (NSDate*)updatedAt;

- (NSString*)stringForKey:(NSString*)key;
- (NSDate*)dateForKey:(NSString*)key;
- (NSNumber*)numberForKey:(NSString*)key;
- (BBObject*)referenceForKey:(NSString*)key;
- (id)objectForKey:(NSString*)key;

- (void)setObject:(id)obj forKey:(NSString*)key;
- (void)removeObjectForKey:(NSString*)key;

- (void)increment:(NSString*)key by:(NSInteger)value;

- (BOOL)save:(SuccessObjectBlock)success failure:(FailureObjectBlock)failure;
- (BOOL)remove:(SuccessObjectBlock)success failure:(FailureObjectBlock)failure;
- (BOOL)refresh:(SuccessObjectBlock)success failure:(FailureObjectBlock)failure;

- (UIImage*)imageWithSize:(CGSize)size success:(SuccessImageBlock)success;

@end
