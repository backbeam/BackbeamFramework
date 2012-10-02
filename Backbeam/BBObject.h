//
//  BBObject.h
//  Callezeta
//
//  Created by Alberto Gimeno Brieba on 16/08/12.
//  Copyright (c) 2012 Level Apps S.L. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void(^SuccessBlock)();
typedef void(^FailureBlock)(NSError* err);

@interface BBObject : NSObject

- (id)initWithEntity:(NSString*)entity dictionary:(NSDictionary*)dict;

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

- (void)saveInBackground:(SuccessBlock)success failure:(FailureBlock)failure;
- (void)deleteInBackground:(SuccessBlock)success failure:(FailureBlock)failure;

@end
