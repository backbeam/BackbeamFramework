//
//  Common.h
//  Callezeta
//
//  Created by Alberto Gimeno Brieba on 22/10/12.
//  Copyright (c) 2012 Level Apps S.L. All rights reserved.
//

@class BBObject;
@class BBUser;

typedef void(^SuccessBlock)();
typedef void(^SuccessOperationBlock)(id result);
typedef void(^FailureOperationBlock)(NSError* err);

typedef void(^SuccessImageBlock)(UIImage* img);

typedef void(^SuccessQueryBlock)(NSArray* objects);
typedef void(^FailureQueryBlock)(NSError* err);

typedef void(^SuccessObjectBlock)(BBObject* object);
typedef void(^FailureObjectBlock)(BBObject* object, NSError* err);

typedef void(^SuccessUserBlock)(BBUser* user);
typedef void(^FailureUserBlock)(BBUser* user, NSError* err);