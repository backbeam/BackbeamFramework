//
//  BBFileUpload.m
//  Backbeam
//
//  Created by Alberto Gimeno Brieba on 8/27/13.
//  Copyright (c) 2013 Level Apps S.L. All rights reserved.
//

#import "BBFileUpload.h"
#import "Backbeam.h"

@implementation BBFileUpload

- (id)initWithFileAtPath:(NSString*)path
{
    self = [super init];
    if (self) {
        self.data = [NSData dataWithContentsOfFile:path];
        self.fileName = [path lastPathComponent];
        self.mimeType = [Backbeam mimeTypeForFile:self.fileName];
    }
    return self;
}

- (id)initWithData:(NSData*)data mimeType:(NSString*)mimeType fileName:(NSString*)fileName {
    self = [super init];
    if (self) {
        self.data = data;
        self.mimeType = mimeType;
        self.fileName = fileName;
    }
    return self;
}

@end
