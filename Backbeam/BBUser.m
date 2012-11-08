//
//  BBUser.m
//  Callezeta
//
//  Created by Alberto Gimeno Brieba on 31/10/12.
//  Copyright (c) 2012 Level Apps S.L. All rights reserved.
//

#import "BBUser.h"
#import "Backbeam.h"

@implementation BBUser

- (id)init
{
    self = [super initWithEntity:@"user"];
    if (self) {
        
    }
    return self;
}

+ (void)loginWithEmail:(NSString*)email password:(NSString*)password success:(SuccessUserBlock)success failure:(FailureOperationBlock)failure {
    NSMutableDictionary* body = [[NSMutableDictionary alloc] init];
    [body setObject:email forKey:@"email"];
    [body setObject:password forKey:@"password"];
    // TODO: use all fields
    
    [[Backbeam instance] perform:@"POST" path:@"/user/email/login" params:nil body:body success:^(id result) {
        NSLog(@"result %@", result);
        success(nil);
    } failure:^(NSError* error) {
        failure(error);
    }];
}

+ (void)requestPasswordResetWithEmail:(NSString*)email success:(SuccessOperationBlock)success failure:(FailureOperationBlock)failure {
    // TODO
}

+ (BBUser*)loggedUser {
    return nil;
}

+ (BBUser*)logout {
    return nil;
}

@end
