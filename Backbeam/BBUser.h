//
//  BBUser.h
//  Callezeta
//
//  Created by Alberto Gimeno Brieba on 31/10/12.
//  Copyright (c) 2012 Level Apps S.L. All rights reserved.
//

#import "BBObject.h"

@interface BBUser : BBObject

- (id)init;
+ (void)loginWithEmail:(NSString*)email password:(NSString*)password success:(SuccessUserBlock)success failure:(FailureOperationBlock)failure;
+ (void)requestPasswordResetWithEmail:(NSString*)email success:(SuccessOperationBlock)success failure:(FailureOperationBlock)failure;

+ (BBUser*)loggedUser;
+ (BBUser*)logout;

@end
