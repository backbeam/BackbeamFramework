// public domain

@interface NSData (MBBase64)

+ (NSData*)dataFromBase64String:(NSString *)string;     //  Padding '=' characters are optional. Whitespace is ignored.
- (NSString *)base64EncodedString;

@end