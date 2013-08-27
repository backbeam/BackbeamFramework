//
//  BBFileUpload.h
//  Backbeam
//
//  Created by Alberto Gimeno Brieba on 8/27/13.
//  Copyright (c) 2013 Level Apps S.L. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface BBFileUpload : NSObject

@property (nonatomic, strong) NSData *data;
@property (nonatomic, strong) NSString *mimeType;
@property (nonatomic, strong) NSString *fileName;

- (id)initWithFileAtPath:(NSString*)path;

- (id)initWithData:(NSData*)data mimeType:(NSString*)mimeType fileName:(NSString*)fileName;

@end
