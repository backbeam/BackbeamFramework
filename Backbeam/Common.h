//
//  Common.h
//  Backbeam
//
//  Created by Alberto Gimeno Brieba on 22/10/12.
//  Copyright (c) 2012 Level Apps S.L. All rights reserved.
//

@class BBObject;
@class BBUser;
@class BBError;

// internal use
typedef void(^SuccessOperationBlock)(id result);
typedef void(^FailureOperationBlock)(id result, NSError* err);
typedef void(^SuccessOperationObjectBlock)(NSString* status, BBObject* object);

// public use
typedef void(^SuccessBlock)();
typedef void(^FailureBlock)(NSError* err);

typedef void(^SuccessImageBlock)(UIImage* img);

typedef void(^SuccessQueryBlock)(NSArray* objects);
typedef void(^FailureQueryBlock)(NSError* err);

typedef void(^SuccessObjectBlock)(BBObject* object);
typedef void(^FailureObjectBlock)(BBObject* object, NSError* err);

typedef void(^SuccessUserBlock)(BBUser* user);
typedef void(^FailureUserBlock)(BBUser* user, NSError* err);
