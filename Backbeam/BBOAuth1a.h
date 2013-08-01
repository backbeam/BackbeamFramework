//
//  BBOAuth1a.h
//  Communities
//
//  Created by Alberto Gimeno Brieba on 01/08/13.
//  Copyright (c) 2013 Level Apps S.L. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface BBOAuth1a : NSObject

@property (nonatomic, strong) NSString* consumerKey;
@property (nonatomic, strong) NSString* consumerSecret;

@property (nonatomic, strong) NSString* oauthToken;
@property (nonatomic, strong) NSString* oauthTokenSecret;

- (NSURLRequest*)signedRequestWithMethod:(NSString*)method
                                 baseURL:(NSString*)baseUrl
                                  params:(NSDictionary*)params
                                    body:(NSDictionary*)body
                                callback:(NSString*)callback;

@end
