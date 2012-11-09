//
//  BBError.h
//  Backbeam
//
//  Created by Alberto Gimeno Brieba on 08/11/12.
//  Copyright (c) 2012 Level Apps S.L. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface BBError : NSError

+ (BBError*)errorWithStatus:(NSString*)status result:(id)result;
+ (BBError*)errorWithError:(NSError*)error;
+ (BBError*)errorWithResult:(id)result error:(NSError*)error;

@end
