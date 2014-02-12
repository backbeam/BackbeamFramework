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
    if (errorMessage) {
        [userInfo setObject:status forKey:NSLocalizedFailureReasonErrorKey];
        [userInfo setObject:errorMessage forKey:NSLocalizedDescriptionKey];
    } else {
        [userInfo setObject:status forKey:NSLocalizedDescriptionKey];
    }
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
    
    NSMutableDictionary* userInfo = [[NSMutableDictionary alloc] init];
    if (errorMessage) {
        [userInfo setObject:status forKey:NSLocalizedFailureReasonErrorKey];
        [userInfo setObject:errorMessage forKey:NSLocalizedDescriptionKey];
    } else {
        [userInfo setObject:status forKey:NSLocalizedDescriptionKey];
    }
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

/*
- (NSString *)localizedDescription {
    NSString* errorMessage = [self.userInfo objectForKey:@"errorMessage"];
    NSString* status = [self.userInfo objectForKey:@"status"];
    if (status) {
        if (errorMessage) {
            return [NSString stringWithFormat:@"Error type %@, errorMessage: %@", status, errorMessage];
        }
        return [NSString stringWithFormat:@"Error type %@", status];
    }
    NSError* rootError = [self.userInfo objectForKey:NSStringEncodingErrorKey];
    if (rootError) {
        // return [NSString stringWithFormat:@"Root error %@", [rootError localizedDescription]];
        return [rootError localizedDescription];
    }
    return [super localizedDescription];
}
 */

@end
