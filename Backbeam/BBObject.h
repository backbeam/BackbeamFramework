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

@interface BBObject : NSObject <NSCoding>

// constructors

- (id)initWith:(BackbeamSession*)session
        entity:(NSString*)entity;

- (id)initWith:(BackbeamSession*)session
        entity:(NSString*)entity
    identifier:(NSString*)identifier;

+ (NSMutableDictionary*)objectsWithSession:(BackbeamSession*)session
                                    values:(NSDictionary*)values
                                references:(NSMutableDictionary*)objects;

- (void)setSession:(BackbeamSession*)session;

// methods for reading default fields

- (NSString*)identifier;

- (NSString*)entity;

- (NSDate*)createdAt;

- (NSDate*)updatedAt;

- (NSString*)loginData:(NSString*)_key forProvider:(NSString*)provider;

- (NSString*)facebookData:(NSString*)key;

- (NSString*)twitterData:(NSString*)key;

- (NSString*)googlePlusData:(NSString*)key;

- (NSArray*)fieldNames;

// methods for reading fields

- (NSString*)stringForField:(NSString*)key;

- (NSDate*)dateForField:(NSString*)key;

- (NSNumber*)numberForField:(NSString*)key;

- (NSNumber*)booleanForField:(NSString*)key;

- (NSDateComponents*)dayForField:(NSString*)key;

- (id)JSONForField:(NSString*)key;

- (BBObject*)objectForField:(NSString*)key;

- (BBLocation*)locationForField:(NSString*)key;

- (BBJoinResult*)joinResultForField:(NSString*)key;

- (id)rawValueForField:(NSString*)key;

// methods for modifying fields

- (BOOL)setString:(NSString*)obj forField:(NSString*)key;

- (BOOL)setNumber:(NSNumber*)obj forField:(NSString*)key;

- (BOOL)setLocation:(BBLocation*)obj forField:(NSString*)key;

- (BOOL)setObject:(BBObject*)obj forField:(NSString*)key;

- (BOOL)setDate:(NSDate*)obj forField:(NSString*)key;

- (BOOL)setBoolean:(NSNumber*)obj forField:(NSString*)key;

- (BOOL)setDay:(NSDateComponents*)obj forField:(NSString*)key;

- (BOOL)setDayFromDate:(NSDate*)date forField:(NSString*)key;

- (BOOL)setJSON:(id)obj forField:(NSString*)key;

- (BOOL)setRawValue:(id)obj forField:(NSString*)key;

- (void)removeField:(NSString*)key;

- (BOOL)addObject:(BBObject*)object
         forField:(NSString*)key;

- (BOOL)removeObject:(BBObject*)object
            forField:(NSString*)key;

- (void)incrementField:(NSString*)field
                    by:(NSInteger)value;

// methods that interact with the API

- (void)save:(SuccessObjectBlock)success
     failure:(FailureObjectBlock)failure;

- (void)remove:(SuccessObjectBlock)success
       failure:(FailureObjectBlock)failure;

- (void)refresh:(SuccessObjectBlock)success
        failure:(FailureObjectBlock)failure;

- (void)refresh:(NSString*)joins
         params:(NSArray*)params
        success:(SuccessObjectBlock)success
        failure:(FailureObjectBlock)failure;

// methods for files

#if defined(__IPHONE_OS_VERSION_MIN_REQUIRED)
- (UIImage*)imageWithSize:(CGSize)size
                  success:(SuccessImageBlock)success;

- (UIImage*)imageWithSize:(CGSize)size
                  success:(SuccessImageBlock)success
                  failure:(FailureObjectBlock)failure;

- (UIImage*)imageWithSize:(CGSize)size
                 progress:(ProgressDataBlock)progress
                  success:(SuccessImageBlock)success
                  failure:(FailureObjectBlock)failure;
#endif

// upload data

- (BOOL)uploadDataWithProgress:(NSData*)data
                      fileName:fileName
                      mimeType:mimeType
                      progress:(ProgressDataBlock)progress
                       success:(SuccessObjectBlock)success
                       failure:(FailureObjectBlock)failure;

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

// helper methods

- (BOOL)isEmpty;

- (BOOL)idDirty;

- (BOOL)isNew;

@end
