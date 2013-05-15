//
//  BBUtils.h
//  Backbeam
//
//  Created by Alberto Gimeno Brieba on 16/08/12.
//  Copyright (c) 2012 Level Apps S.L. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface BBUtils : NSObject

+ (NSString*)urlEncode:(NSString*)str;
+ (NSString*)urlDecode:(NSString*)str;

+ (NSString*)queryString:(NSDictionary*)dict;
+ (NSDictionary*)parseQueryString:(NSString*)str;

+ (NSString*)hexString:(NSData*)data;
+ (NSData*)sha1:(NSData*)rawData;
+ (NSData*)hmacSha1:(NSData*)data withKey:(NSData*)key;

+ (NSArray*)stringsFromParams:(NSArray*)params;
+ (NSString*)stringFromObject:(id)obj addEntity:(BOOL)addEntity;

+ (NSString*)nonce;

@end
