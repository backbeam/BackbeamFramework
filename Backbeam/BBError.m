//
//  BBError.m
//  Callezeta
//
//  Created by Alberto Gimeno Brieba on 08/11/12.
//  Copyright (c) 2012 Level Apps S.L. All rights reserved.
//

#import "BBError.h"

#define kBackbeamErrorDomain @"Backbeam"

@implementation BBError

+ (BBError*)errorWithStatus:(NSString*)status result:(id)result {
    NSMutableDictionary* userInfo = [[NSMutableDictionary alloc] initWithObjectsAndKeys:status, @"status", nil];
    if (result) {
        [userInfo setObject:result forKey:@"result"];
    }
    BBError* err = [[BBError alloc] initWithDomain:kBackbeamErrorDomain code:1000 userInfo:userInfo];
    return err;
}

+ (BBError*)errorWithError:(NSError*)error {
    NSDictionary* userInfo = nil;
    if (error) {
        userInfo = [NSDictionary dictionaryWithObject:error forKey:@"rootError"];
    }
    BBError* err = [[BBError alloc] initWithDomain:kBackbeamErrorDomain code:1000 userInfo:userInfo];
    return err;
}

- (NSString *)localizedDescription {
    NSString* status = [self.userInfo objectForKey:@"status"];
    if (status) {
        return [NSString stringWithFormat:@"Server responded with status %@", status];
    }
    NSError* rootError = [self.userInfo objectForKey:@"rootError"];
    if (rootError) {
        // return [NSString stringWithFormat:@"Root error %@", [rootError localizedDescription]];
        return [rootError localizedDescription];
    }
    return [super localizedDescription];
}

@end
