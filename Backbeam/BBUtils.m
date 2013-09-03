//
//  BBUtils.m
//  Backbeam
//
//  Created by Alberto Gimeno Brieba on 16/08/12.
//  Copyright (c) 2012 Level Apps S.L. All rights reserved.
//

#import "BBUtils.h"
#import <CommonCrypto/CommonDigest.h>
#import <CommonCrypto/CommonCryptor.h>
#import <CommonCrypto/CommonHMAC.h>
#import "BBObject.h"
#import "BBCollectionConstraint.h"

@implementation BBUtils

+ (NSString*)urlEncode:(NSString*)str {
	NSString* encodedString = (__bridge NSString *)CFURLCreateStringByAddingPercentEscapes(
                                                                                  NULL,
                                                                                  (__bridge CFStringRef) str,
                                                                                  NULL,
                                                                                  (CFStringRef)@"!*'();:@&=+$,/?%#[]",
                                                                                  kCFStringEncodingUTF8 );
	return encodedString;
}

+ (NSString*)urlDecode:(NSString*)str {
    NSString *result = [str stringByReplacingOccurrencesOfString:@"+" withString:@" "];
    result = [result stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    return result;
}

+ (NSString*)queryString:(NSDictionary*)dict {
    NSMutableString* parameterString = [[NSMutableString alloc] init];
    for (NSString* key in dict.allKeys) {
        id value = [dict objectForKey:key];
        if ([value isKindOfClass:[NSArray class]]) {
            NSArray* arr = (NSArray*)value;
            for (NSObject* val in arr) {
                [parameterString appendFormat:@"&%@=%@", [BBUtils urlEncode:key], [BBUtils urlEncode:[val description]]];
            }
        } else {
            [parameterString appendFormat:@"&%@=%@", [BBUtils urlEncode:key], [BBUtils urlEncode:value]];
        }
    }
    if (parameterString.length > 0) {
        [parameterString deleteCharactersInRange:NSMakeRange(0, 1)];
    }
    return [parameterString copy];
}

// oauth_token=e3CKYrOSd59eVyXDXjFRDqwsNS74rh88QmbflE6WuY&oauth_token_secret=btUAdTductIyZf36tupzhHpPTpBMNWcRJUa5HKcfo&oauth_callback_confirmed=true
+ (NSDictionary*)parseQueryString:(NSString*)str {
    NSArray* components = [str componentsSeparatedByString:@"&"];
    NSMutableDictionary* dict = [[NSMutableDictionary alloc] initWithCapacity:components.count];
    for (NSString* component in components) {
        NSRange r = [component rangeOfString:@"="];
        if (r.location != NSNotFound) {
            NSString* key = [BBUtils urlDecode:[component substringToIndex:r.location]];
            NSString* value = [BBUtils urlDecode:[component substringFromIndex:r.location+r.length]];
            [dict setObject:value forKey:key];
        } else {
            [dict setObject:@"" forKey:[BBUtils urlDecode:component]];
        }
    }
    return dict;
}

+ (NSString*)hexString:(NSData*)data {
	NSMutableString *str = [NSMutableString stringWithCapacity:64];
	int length = [data length];
	char *bytes = malloc(sizeof(char) * length);
    
	[data getBytes:bytes length:length];
    
	int i = 0;
    
	for (; i < length; i++) {
		[str appendFormat:@"%02.2hhx", bytes[i]];
	}
	free(bytes);
    
	return str;
}

+ (NSData *)sha1:(NSData *)rawData {
    CC_SHA1_CTX ctx;
    uint8_t * hashBytes = NULL;
    NSData * hash = nil;
    
    // Malloc a buffer to hold hash.
    hashBytes = malloc( CC_SHA1_DIGEST_LENGTH * sizeof(uint8_t) );
    memset((void *)hashBytes, 0x0, CC_SHA1_DIGEST_LENGTH);
    
    // Initialize the context.
    CC_SHA1_Init(&ctx);
    // Perform the hash.
    CC_SHA1_Update(&ctx, (void *)[rawData bytes], [rawData length]);
    // Finalize the output.
    CC_SHA1_Final(hashBytes, &ctx);
    
    // Build up the SHA1 blob.
    hash = [NSData dataWithBytes:(const void *)hashBytes length:(NSUInteger)CC_SHA1_DIGEST_LENGTH];
    
    if (hashBytes) free(hashBytes);
    
    return hash;
}

+ (NSData*)hmacSha1:(NSData*)data withKey:(NSData*)key {
    unsigned char cHMAC[CC_SHA1_DIGEST_LENGTH];
    CCHmac(kCCHmacAlgSHA1, [key bytes], [key length], [data bytes], [data length], cHMAC);
    NSData *hmac = [[NSData alloc] initWithBytes:cHMAC
                                          length:sizeof(cHMAC)];
    return hmac;
}

+ (NSArray*)stringsFromParams:(NSArray*)params {
    NSMutableArray *arr = [[NSMutableArray alloc] initWithCapacity:params.count];
    for (id param in params) {
        [arr addObject:[BBUtils stringFromObject:param addEntity:YES]];
    }
    return arr;
}

+ (NSString*)stringFromObject:(id)obj addEntity:(BOOL)addEntity {
    NSString* value = nil;
    if ([obj isKindOfClass:[NSString class]]) {
        value = (NSString*)obj;
    } else if ([obj isKindOfClass:[NSNumber class]]) {
        value = [obj description];
    } else if ([obj isKindOfClass:[BBObject class]]) {
        BBObject* object = (BBObject*)obj;
        if (addEntity) {
            value = [NSString stringWithFormat:@"%@/%@", object.entity, object.identifier];
        } else {
            value = object.identifier;
        }
    } else if ([obj isKindOfClass:[NSDate class]]) {
        NSDate* date = (NSDate*)obj;
        value = [NSString stringWithFormat:@"%lld", (long long)([date timeIntervalSince1970]*1000)];
    } else if ([obj isKindOfClass:[BBLocation class]]) {
        BBLocation* location = (BBLocation*)obj;
        value = [NSString stringWithFormat:@"%f,%f,%f|%@",
                        location.latitude, location.longitude,
                        location.altitude, location.address];
    } else if ([obj isKindOfClass:[BBCollectionConstraint class]]) {
        return [obj description];
    } else if ([obj isKindOfClass:[NSDateComponents class]]) {
        NSDateComponents *dc = (NSDateComponents*)obj;
        char cString[11];
        sprintf(cString, "%04d-%02d-%02d", dc.year, dc.month, dc.day);
        return [[NSString alloc] initWithUTF8String:cString];
    }
    return value;
}

+ (NSString*)nonce {
    NSTimeInterval time = [[NSDate date] timeIntervalSince1970];
    int random = arc4random() % 1000;
    NSData* data = [[NSString stringWithFormat:@"%f:%d", time, random] dataUsingEncoding:NSUTF8StringEncoding];
    NSData* output = [BBUtils sha1:data];
    return [BBUtils hexString:output];
}

@end
