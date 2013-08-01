//
//  BBOAuth1a.m
//  Communities
//
//  Created by Alberto Gimeno Brieba on 01/08/13.
//  Copyright (c) 2013 Level Apps S.L. All rights reserved.
//

#import "BBOAuth1a.h"
#import "BBUtils.h"
#import "NSData+Base64.h"

@implementation BBOAuth1a

- (NSURLRequest*)signedRequestWithMethod:(NSString*)method baseURL:(NSString*)baseUrl params:(NSDictionary*)params body:(NSDictionary*)body callback:(NSString*)callback {
    
    NSMutableDictionary* authorization = [[NSMutableDictionary alloc] initWithCapacity:8];
    [authorization setObject:self.consumerKey forKey:@"oauth_consumer_key"];
    [authorization setObject:[BBUtils nonce] forKey:@"oauth_nonce"];
    [authorization setObject:@"HMAC-SHA1" forKey:@"oauth_signature_method"];
    [authorization setObject:[self timestamp] forKey:@"oauth_timestamp"];
    [authorization setObject:@"1.0" forKey:@"oauth_version"];
    if (self.oauthToken) {
        [authorization setObject:self.oauthToken forKey:@"oauth_token"];
    }
    if (callback) {
        [authorization setObject:callback forKey:@"oauth_callback"];
    }
    
    NSMutableDictionary* signatureParams = [[NSMutableDictionary alloc] initWithCapacity:params.count+body.count+authorization.count];
    [signatureParams addEntriesFromDictionary:params];
    [signatureParams addEntriesFromDictionary:body];
    [signatureParams addEntriesFromDictionary:authorization];
    
    NSMutableString* parameterString = [[NSMutableString alloc] init];
    NSArray* sortedKeys = [[signatureParams allKeys] sortedArrayUsingSelector:@selector(compare:)];
    for (NSString* key in sortedKeys) {
        NSString* value = [signatureParams objectForKey:key];
        [parameterString appendFormat:@"&%@=%@", [BBUtils urlEncode:key], [BBUtils urlEncode:value]];
    }
    [parameterString deleteCharactersInRange:NSMakeRange(0, 1)];
    
    NSString* signatureBaseString = [NSString stringWithFormat:@"%@&%@&%@", [method uppercaseString], [BBUtils urlEncode:baseUrl], [BBUtils urlEncode:parameterString]];
    NSString* signingKey = nil;
    if (self.oauthTokenSecret) {
        signingKey = [NSString stringWithFormat:@"%@&%@", [BBUtils urlEncode:self.consumerSecret], [BBUtils urlEncode:self.oauthTokenSecret]];
    } else {
        signingKey = [NSString stringWithFormat:@"%@&"  , [BBUtils urlEncode:self.consumerSecret]];
    }
    
    NSData* hmac = [BBUtils hmacSha1:[signatureBaseString dataUsingEncoding:NSUTF8StringEncoding] withKey:[signingKey dataUsingEncoding:NSUTF8StringEncoding]];
    
    NSString* signature = [hmac base64EncodedString];
    [authorization setObject:signature forKey:@"oauth_signature"];
    
    NSMutableString* authorizationString = [[NSMutableString alloc] init];
    for (NSString* key in authorization.allKeys) {
        NSString* value = [authorization objectForKey:key];
        [authorizationString appendFormat:@", %@=\"%@\"", [BBUtils urlEncode:key], [BBUtils urlEncode:value]];
    }
    [authorizationString deleteCharactersInRange:NSMakeRange(0, 2)];
    [authorizationString insertString:@"OAuth " atIndex:0];
    
    NSMutableURLRequest* request = [[NSMutableURLRequest alloc] init];
    [request setHTTPMethod:method];
    [request setValue:authorizationString forHTTPHeaderField:@"Authorization"];
    if (body.count > 0) {
        [request setHTTPBody:[[BBUtils queryString:body] dataUsingEncoding:NSUTF8StringEncoding]];
    }
    
    NSString* url = nil;
    if (params.count > 0) {
        url = [NSString stringWithFormat:@"%@?%@", baseUrl, [BBUtils queryString:params]];
    } else {
        url = baseUrl;
    }
    [request setURL:[NSURL URLWithString:url]];
    return request;
}

- (NSString*)timestamp {
    NSTimeInterval time = [[NSDate date] timeIntervalSince1970];
    return [NSString stringWithFormat:@"%.0f", time];
}

@end
