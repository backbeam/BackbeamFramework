//
//  BBTest.m
//  Backbeam
//
//  Created by Alberto Gimeno Brieba on 08/11/12.
//  Copyright (c) 2012 Level Apps S.L. All rights reserved.
//

#import "BBTest.h"

@interface BBTest ()

@property (nonatomic, copy) TestBlock _before;
@property (nonatomic, copy) TestBlock _after;
@property (nonatomic, copy) TestBlock _beforeEach;
@property (nonatomic, copy) TestBlock _afterEach;
@property (nonatomic, copy) TestBlock _empty;
@property (nonatomic, copy) DoneBlock _finish;
@property (nonatomic, strong) NSMutableArray* tests;
@property (nonatomic, strong) NSMutableArray* testNames;
@property (nonatomic, assign) NSInteger i;

@end

@implementation BBTest

- (id)init
{
    self = [super init];
    if (self) {
        self.tests = [[NSMutableArray alloc] init];
        self.testNames = [[NSMutableArray alloc] init];
        self._empty = ^(DoneBlock done) {
            done();
        };
        self._before = self._empty;
        self._beforeEach = self._empty;
        self._after = self._empty;
        self._afterEach = self._empty;
    }
    return self;
}

- (void)before:(TestBlock)before {
    self._before = before;
}

- (void)after:(TestBlock)after {
    self._after = after;
}

- (void)beforeEach:(TestBlock)beforeEach {
    self._beforeEach = beforeEach;
}

- (void)afterEach:(TestBlock)afterEach {
    self._afterEach = afterEach;
}

- (void)test:(NSString*)message done:(TestBlock)done {
    [self.testNames addObject:message];
    [self.tests addObject:[done copy]];
}

- (void)run:(DoneBlock)done {
    self.i = 0;
    self._finish = done;
    self._before(^{
        [self runNext];
    });
}

- (void)runNext {
    if (self.i < self.tests.count) {
        NSLog(@"Running: %@", [self.testNames objectAtIndex:self.i]);
        self._beforeEach(^{
            TestBlock test = (TestBlock) [self.tests objectAtIndex:self.i];
            test(^{
                self.i++;
                self._afterEach(^{
                    [self runNext];
                });
            });
        });
    } else {
        // TODO: after
        self._finish();
    }
}

- (void)failed:(NSString*)message file:(char*)filename line:(int)line {
    NSString* file = [NSString stringWithFormat:@"%s", filename];
    NSArray* arr = [file componentsSeparatedByString:@"/"];
    NSLog(@"Test failed: %@ at %@ line %d", message, [arr lastObject], line);
}

- (void)configure {
    
}

@end
