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
@class BBLocation;
@class BBJoinResult;
@class BackbeamSession;

@interface BBObject : NSObject

// constructors

- (id)initWith:(BackbeamSession*)session
        entity:(NSString*)entity;

- (id)initWith:(BackbeamSession*)session
        entity:(NSString*)entity;

- (id)initWith:(BackbeamSession*)session
        entity:(NSString*)entity
    identifier:(NSString*)identifier;

- (id)initWith:(BackbeamSession*)session
        entity:(NSString*)entity
    dictionary:(NSDictionary*)dict
    references:(NSDictionary *)references
    identifier:(NSString*)identifier;

- (id)initWith:(BackbeamSession*)session
        entity:(NSString*)entity
          file:(NSString*)path;

- (BOOL)saveToFile:(NSString*)path;

// methods for reading default fields

- (NSString*)identifier;

- (NSString*)entity;

- (NSDate*)createdAt;

- (NSDate*)updatedAt;

// methods for reading fields

- (NSString*)stringForKey:(NSString*)key;

- (NSDate*)dateForKey:(NSString*)key;

- (NSNumber*)numberForKey:(NSString*)key;

- (BBObject*)referenceForKey:(NSString*)key;

- (BBLocation*)locationForKey:(NSString*)key;

- (BBJoinResult*)joinResultForKey:(NSString*)key;

- (id)objectForKey:(NSString*)key;

// methods for modifying fields

- (BOOL)setObject:(id)obj
           forKey:(NSString*)key;

- (void)removeObjectForKey:(NSString*)key;

- (BOOL)addReference:(BBObject*)object
              forKey:(NSString*)key;

- (BOOL)removeReference:(BBObject*)object
                 forKey:(NSString*)key;

- (void)increment:(NSString*)key
               by:(NSInteger)value;

// methods that interact with the API

- (BOOL)save:(SuccessObjectBlock)success
     failure:(FailureObjectBlock)failure;

- (BOOL)remove:(SuccessObjectBlock)success
       failure:(FailureObjectBlock)failure;

- (BOOL)refresh:(SuccessObjectBlock)success
        failure:(FailureObjectBlock)failure;

// methods for files

- (UIImage*)imageWithSize:(CGSize)size
                  success:(SuccessImageBlock)success;

- (UIImage*)imageWithSize:(CGSize)size
                  success:(SuccessImageBlock)success
                  failure:(FailureObjectBlock)failure;

- (UIImage*)imageWithSize:(CGSize)size
                 progress:(ProgressDataBlock)progress
                  success:(SuccessImageBlock)success
                  failure:(FailureObjectBlock)failure;

// upload data

- (BOOL)uploadDataWithProgress:(NSData*)data
                      progress:(ProgressDataBlock)progress
                       success:(SuccessObjectBlock)success
                       failure:(FailureObjectBlock)failure;

- (BOOL)uploadFileWithProgress:(NSString*)path
                      progress:(ProgressDataBlock)progress
                       success:(SuccessObjectBlock)success
                       failure:(FailureObjectBlock)failure;

- (BOOL)uploadData:(NSData*)data
           success:(SuccessObjectBlock)success
           failure:(FailureObjectBlock)failure;

- (BOOL)uploadFile:(NSString*)path
           success:(SuccessObjectBlock)success
           failure:(FailureObjectBlock)failure;

// download data

- (BOOL)downloadDataWithProgress:(ProgressDataBlock)progress
                         success:(SuccessDownloadBlock)success
                         failure:(FailureObjectBlock)failure;

- (BOOL)downloadData:(SuccessDownloadBlock)success
             failure:(FailureObjectBlock)failure;

// TODO: methods for users

@end
