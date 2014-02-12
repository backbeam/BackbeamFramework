//
//  BBError.m
//  Backbeam
//
//  Created by Alberto Gimeno Brieba on 08/11/12.
//  Copyright (c) 2012 Level Apps S.L. All rights reserved.
//

#import "BBError.h"

#define kBackbeamErrorDomain @"Backbeam"

@implementation BBError

+ (BBError*)errorWithStatus:(NSString*)status result:(id)result {
    NSMutableDictionary* userInfo = [[NSMutableDictionary alloc] init];
    NSString* errorMessage = [result stringForKey:@"errorMessage"];
    if (!errorMessage) errorMessage = status;
    [userInfo setObject:status forKey:NSLocalizedFailureReasonErrorKey];
    [userInfo setObject:errorMessage forKey:NSLocalizedDescriptionKey];
    BBError* err = [[BBError alloc] initWithDomain:kBackbeamErrorDomain code:1000 userInfo:userInfo];
    return err;
}

+ (BBError*)errorWithResult:(id)result error:(NSError*)error {
    if (![result isKindOfClass:[NSDictionary class]]) {
        return [BBError errorWithError:error];
    }
    
    NSString* status = [result stringForKey:@"status"];
    if (!status) {
        return [BBError errorWithError:error];
    }
    
    NSString* errorMessage = [result stringForKey:@"errorMessage"];
    if (!errorMessage) errorMessage = status;
    
    NSMutableDictionary* userInfo = [[NSMutableDictionary alloc] init];
    [userInfo setObject:status forKey:NSLocalizedFailureReasonErrorKey];
    [userInfo setObject:errorMessage forKey:NSLocalizedDescriptionKey];
    BBError* err = [[BBError alloc] initWithDomain:kBackbeamErrorDomain code:1000 userInfo:userInfo];
    return err;
}

+ (BBError*)errorWithError:(NSError*)error {
    NSDictionary* userInfo = nil;
    if (error) {
        userInfo = [NSDictionary dictionaryWithObject:error forKey:NSStringEncodingErrorKey];
    }
    BBError* err = [[BBError alloc] initWithDomain:kBackbeamErrorDomain code:1000 userInfo:userInfo];
    return err;
}

@end
