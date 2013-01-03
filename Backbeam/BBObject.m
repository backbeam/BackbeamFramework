//
//  BBObject.m
//  Backbeam
//
//  Created by Alberto Gimeno Brieba on 16/08/12.
//  Copyright (c) 2012 Level Apps S.L. All rights reserved.
//

#import "BBObject.h"
#import "BBError.h"
#import "BBUtils.h"

@interface BBObject ()

@property (nonatomic, strong) NSString* _identifier;
@property (nonatomic, strong) NSString* _entity;
@property (nonatomic, strong) NSMutableDictionary* _fields;
@property (nonatomic, strong) NSMutableDictionary* _commands;
@property (nonatomic, strong) NSDate* _createdAt;
@property (nonatomic, strong) NSDate* _updatedAt;
@property (nonatomic, strong) BackbeamSession* _session;

@end

@implementation BBObject

- (id)initWith:(BackbeamSession*)session entity:(NSString*)entity
{
    self = [super init];
    if (self) {
        self._entity = entity;
        self._fields = [[NSMutableDictionary alloc] init];
        self._commands = [[NSMutableDictionary alloc] init];
        self._session = session;
    }
    return self;
}

- (id)initWith:(BackbeamSession*)session entity:(NSString*)entity identifier:(NSString*)identifier
{
    self = [super init];
    if (self) {
        self._entity = entity;
        self._identifier = identifier;
        self._fields = [[NSMutableDictionary alloc] init];
        self._commands = [[NSMutableDictionary alloc] init];
        self._session = session;
    }
    return self;
}

- (id)initWith:(BackbeamSession*)session entity:(NSString*)entity dictionary:(NSDictionary*)dict references:(NSDictionary *)references identifier:(NSString*)identifier
{
    self = [super init];
    if (self) {
        self._entity = entity;
        self._fields = [[NSMutableDictionary alloc] init];
        self._commands = [[NSMutableDictionary alloc] init];
        self._identifier = identifier;
        self._session = session;
        [self fillValuesWithDictionary:dict andReferences:references];
    }
    return self;
}

- (id)initWith:(BackbeamSession*)session entity:(NSString*)entity file:(NSString*)path
{
    self = [super init];
    if (self) {
        NSDictionary* dict = [NSKeyedUnarchiver unarchiveObjectWithFile:path];
        if (!dict) {
            return nil;
        }
        self._entity = entity;
        self._fields = [NSMutableDictionary dictionaryWithDictionary:[dict dictionaryForKey:@"fields"]];
        self._identifier = [dict stringForKey:@"id"];
        self._commands = [[NSMutableDictionary alloc] init];
        self._session = session;
    }
    return self;
}

- (BOOL)saveToFile:(NSString*)path {
    NSDictionary* dict = [NSDictionary dictionaryWithObjectsAndKeys:self._identifier, @"id", self._fields, @"fields", nil];
    return [NSKeyedArchiver archiveRootObject:dict toFile:path];
}

- (void)fillValuesWithDictionary:(NSDictionary*)dict andReferences:(NSDictionary*)references {
    [self._commands removeAllObjects];
    for (NSString* key in dict.allKeys) {
        NSObject* value = [dict objectForKey:key];
        if ([key isEqualToString:@"id"]) {
            self._identifier = [value description];
        } else if ([key isEqualToString:@"created_at"]) {
            self._createdAt = [BBObject dateFromValue:value];
        } else if ([key isEqualToString:@"updated_at"]) {
            self._updatedAt = [BBObject dateFromValue:value];
        } else if ([key isEqualToString:@"type"]) {
            self._entity = [value description];
        } else {
            NSRange range = [key rangeOfString:@"#"];
            if (range.location != NSNotFound) {
                NSString* _key = [key substringToIndex:range.location];
                NSString* type = [key substringFromIndex:range.location+1];
                if ([type isEqualToString:@"d"] && [value isKindOfClass:[NSNumber class]]) {
                    NSNumber* n = (NSNumber*)value;
                    value = [NSDate dateWithTimeIntervalSince1970:n.doubleValue/1000];
                } else if ([type isEqualToString:@"r"] && [value isKindOfClass:[NSDictionary class]]) {
                    NSDictionary* dict = (NSDictionary*)value;
                    BBJoinResult* result = [[BBJoinResult alloc] init];
                    result.count = [dict numberForKey:@"count"].integerValue;
                    NSArray* arr = [dict arrayForKey:@"result"];
                    NSMutableArray* refs = [[NSMutableArray alloc] initWithCapacity:arr.count];
                    for (NSString* identifier in arr) {
                        NSDictionary* obj = [references objectForKey:identifier];
                        if (obj) { // sanity check
                            [refs addObject:obj];
                        }
                    }
                    result.objects = refs;
                    value = result;
                } else if ([type isEqualToString:@"r"] && [value isKindOfClass:[NSString class]]) {
                    value = [references objectForKey:value];
                } else if ([type isEqualToString:@"l"] && [value isKindOfClass:[NSDictionary class]]) {
                    NSDictionary* dict = (NSDictionary*)value;
                    BBLocation* location = [[BBLocation alloc] init];
                    location.latitude  = [dict numberForKey:@"lat"].doubleValue;
                    location.longitude = [dict numberForKey:@"lon"].doubleValue;
                    location.altitude  = [dict numberForKey:@"alt"].doubleValue;
                    location.address   = [dict stringForKey:@"addr"];
                    value = location;
                }
                if (value) { // sanity check
                    [self._fields setObject:value forKey:_key];
                }
            }
        }
    }
}

+ (NSDate*)dateFromValue:(id)value {
    NSTimeInterval time = [(NSNumber*)value doubleValue]/1000;
    return [NSDate dateWithTimeIntervalSince1970:time];;
}

- (NSString*)identifier {
    return self._identifier;
}

- (NSString*)entity {
    return self._entity;
}

- (NSDate*)createdAt {
    return self._createdAt;
}

- (NSDate*)updatedAt {
    return self._updatedAt;
}

- (NSString*)stringForKey:(NSString*)key {
    return [self._fields stringForKey:key];
}

- (NSDate*)dateForKey:(NSString*)key {
    return [self._fields dateForKey:key];
}

- (NSNumber*)numberForKey:(NSString*)key {
    return [self._fields numberForKey:key];
}

- (BBObject*)referenceForKey:(NSString*)key {
    id obj = [self._fields objectForKey:key];
    if ([obj isKindOfClass:[BBObject class]]) {
        return (BBObject*)obj;
    }
    return nil;
}

- (BBLocation*)locationForKey:(NSString*)key {
    id obj = [self._fields objectForKey:key];
    if ([obj isKindOfClass:[BBLocation class]]) {
        return (BBLocation*)obj;
    }
    return nil;
}

- (BBJoinResult*)joinResultForKey:(NSString*)key {
    id obj = [self._fields objectForKey:key];
    if ([obj isKindOfClass:[BBJoinResult class]]) {
        return (BBJoinResult*)obj;
    }
    return nil;
}

- (BOOL)setObject:(id)obj forKey:(NSString*)key {
    NSString* commandValue = [BBUtils stringFromObject:obj addEntity:NO];
    if (!commandValue) return NO;
    
    NSString* command = [NSString stringWithFormat:@"set-%@", key];
    [self._fields setObject:obj forKey:key];
    [self._commands setObject:commandValue forKey:command];
    return YES;
}

- (BOOL)addReference:(BBObject*)object forKey:(NSString*)key {
    if (!object.identifier) return NO;
    
    NSString* command = [NSString stringWithFormat:@"add-%@", key];
    NSMutableArray* arr = [self._commands objectForKey:command];
    if (!arr) {
        arr = [NSMutableArray array];
        [self._commands setObject:arr forKey:command];
    }
    [arr addObject:object.identifier];
    return YES;
}

- (BOOL)removeReference:(BBObject*)object forKey:(NSString*)key {
    if (!object.identifier) return NO;
    
    NSString* command = [NSString stringWithFormat:@"rem-%@", key];
    NSMutableArray* arr = [self._commands objectForKey:command];
    if (!arr) {
        arr = [NSMutableArray array];
        [self._commands setObject:arr forKey:command];
    }
    [arr addObject:object.identifier];
    return YES;
}

- (id)objectForKey:(NSString*)key {
    return [self._fields objectForKey:key];
}

- (void)removeObjectForKey:(NSString*)key {
    NSString* command = [NSString stringWithFormat:@"set-%@", key];
    [self._fields removeObjectForKey:key];
    [self._commands setObject:@"-" forKey:command]; // TODO, not tested. REST API could change
}

// TODO: support many increments without overriding previous command
- (void)increment:(NSString*)key by:(NSInteger)value {
    NSNumber* n = [self numberForKey:key];
    if (n) {
        n = [NSNumber numberWithInteger:n.integerValue+value];
    } else {
        n = [NSNumber numberWithInteger:value];
    }
    [self._fields setObject:n forKey:key];
    NSString* command = [NSString stringWithFormat:@"incr-%@", key];
    [self._commands setObject:[NSString stringWithFormat:@"%d", value] forKey:command];
}

- (void)processResponse:(id)result success:(SuccessOperationObjectBlock)success failure:(FailureObjectBlock)failure {
    if (![result isKindOfClass:[NSDictionary class]]) {
        failure(self, [BBError errorWithStatus:@"InvalidResponse" result:result]);
        return;
    }
    
    NSString* status     = [result stringForKey:@"status"];
    NSDictionary* object = [result dictionaryForKey:@"object"];
    
    if (!status || !object) {
        failure(self, [BBError errorWithStatus:@"InvalidResponse" result:result]);
        return;
    }
    
    if (![status isEqualToString:@"Success"] && ![status isEqualToString:@"PendingValidation"]) {
        failure(self, [BBError errorWithStatus:status result:result]);
        return;
    }
    
    [self fillValuesWithDictionary:object andReferences:nil];
    success(status, self);
}

- (void)processResponse:(id)result error:(NSError*)err failure:(FailureObjectBlock)failure {
    if (![result isKindOfClass:[NSDictionary class]]) {
        failure(self, [BBError errorWithStatus:@"InvalidResponse" result:result]);
        return;
    }
    
    NSString* status = [result stringForKey:@"status"];
    if (status) {
        failure(self, [BBError errorWithStatus:status result:result]);
        return;
    }
    
    failure(self, [BBError errorWithError:err]);
}

- (BOOL)save:(SuccessObjectBlock)success failure:(FailureObjectBlock)failure {
    if (!self._entity) { return NO; }
    
    NSString* path = nil;
    NSString* method = nil;
    if (self._identifier) {
        method = @"PUT";
        path = [NSString stringWithFormat:@"/data/%@/%@", self._entity, self._identifier];
    } else {
        method = @"POST";
        path = [NSString stringWithFormat:@"/data/%@", self._entity];
    }
    
    [self._session perform:method path:path params:self._commands success:^(id result) {
        // [self._commands removeAllObjects];
        [self processResponse:result success:^(NSString* status, BBObject* object) {
            if ([self.entity isEqualToString:@"user"]) {
                [self._fields removeObjectForKey:@"password"];
            }
            if ([self.entity isEqualToString:@"user"] && [method isEqualToString:@"POST"]) {
                [Backbeam logout]; // logout previous user
                if ([status isEqualToString:@"Success"]) { // not PendingValidation
                    [self._session setLoggedUser:self];
                }
            }
            success(object);
        } failure:failure];
    } failure:^(id result, NSError* err) {
        [self processResponse:result error:err failure:failure];
    }];
    return YES;
}

- (BOOL)remove:(SuccessObjectBlock)success failure:(FailureObjectBlock)failure {
    if (!self._entity || !self._identifier) { return NO; }
    NSString* path = [NSString stringWithFormat:@"/data/%@/%@", self._entity, self._identifier];
    
    [self._session perform:@"DELETE" path:path params:nil success:^(id result) {
        [self processResponse:result success:^(NSString* status, BBObject* object) {
            // TODO: if (is current user) logout; return;
            success(self);
        } failure:failure];
    } failure:^(id result, NSError* err) {
        [self processResponse:result error:err failure:failure];
    }];
    return YES;
}

- (BOOL)refresh:(SuccessObjectBlock)success failure:(FailureObjectBlock)failure {
    if (!self._entity || !self._identifier) { return NO; }
    NSString* path = [NSString stringWithFormat:@"/data/%@/%@", self._entity, self._identifier];
    
    [self._session perform:@"GET" path:path params:nil success:^(id result) {
        [self processResponse:result success:^(NSString* status, BBObject* object) {
            success(object);
        } failure:failure];
    } failure:^(id result, NSError* err) {
        [self processResponse:result error:err failure:failure];
    }];
    return YES;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"entity=%@ identifier=%@ fields=%@", self.entity, self.identifier, self._fields];
}

- (UIImage*)imageWithSize:(CGSize)size
                  success:(SuccessImageBlock)success {
    
    NSNumber* version = [self numberForKey:@"version"];
    return [self._session image:self._identifier version:version withSize:size progress:nil success:success failure:^(NSError* error) {
        // ignore
    }];
}

- (UIImage*)imageWithSize:(CGSize)size
                  success:(SuccessImageBlock)success
                  failure:(FailureObjectBlock)failure {
    
    NSNumber* version = [self numberForKey:@"version"];
    return [self._session image:self._identifier version:version withSize:size progress:nil success:success failure:^(NSError* error) {
        failure(self, error);
    }];
}


- (UIImage*)imageWithSize:(CGSize)size
                 progress:(ProgressDataBlock)progress
                  success:(SuccessImageBlock)success
                  failure:(FailureObjectBlock)failure {
    
    NSNumber* version = [self numberForKey:@"version"];
    return [self._session image:self._identifier version:version withSize:size progress:progress success:success failure:^(NSError* error) {
        failure(self, error);
    }];
}

// upload data

- (BOOL)uploadDataWithProgress:(NSData*)data
                      fileName:fileName
                      mimeType:mimeType
                      progress:(ProgressDataBlock)progress
                       success:(SuccessObjectBlock)success
                       failure:(FailureObjectBlock)failure {
    
    NSString* path = nil;
    NSString* httpMethod = nil;
    if (self._identifier) {
        httpMethod = @"PUT";
        path = [@"/data/file/upload/" stringByAppendingString:self._identifier];
    } else {
        httpMethod = @"POST";
        path = @"/data/file/upload";
    }
    
    [self._session upload:httpMethod
                     data:data
                 fileName:fileName
                 mimeType:mimeType
                     path:path
                   params:self._commands
                 progress:progress success:^(id result) {
        
                     NSDictionary* object = [result dictionaryForKey:@"object"];
                     if (object) {
                         [self fillValuesWithDictionary:object andReferences:nil];
                     }
        success(self);
    } failure:^(id result, NSError* error) {
        // TODO: response message?
        failure(self, error);
    }];
    
    return NO;
}

- (BOOL)uploadDataWithProgress:(NSData*)data
                      progress:(ProgressDataBlock)progress
                       success:(SuccessObjectBlock)success
                       failure:(FailureObjectBlock)failure {
    
    NSString* fileName = @"noname.dat";
    NSString* mimeType = @"application/octet-stream";
    
    return [self uploadDataWithProgress:data fileName:fileName mimeType:mimeType progress:progress success:success failure:failure];
}

- (BOOL)uploadFileWithProgress:(NSString*)path
                      progress:(ProgressDataBlock)progress
                       success:(SuccessObjectBlock)success
                       failure:(FailureObjectBlock)failure {
    
    NSData* data = [NSData dataWithContentsOfFile:path];
    if (!data) {
        failure(self, [BBError errorWithStatus:@"CannotReadFile" result:nil]);
        return NO;
    }
    NSString* fileName = [path lastPathComponent];
    return [self uploadDataWithProgress:data fileName:fileName mimeType:nil progress:progress success:success failure:failure];
}

- (BOOL)uploadData:(NSData*)data
           success:(SuccessObjectBlock)success
           failure:(FailureObjectBlock)failure {
    
    NSString* fileName = @"noname.dat";
    NSString* mimeType = @"application/octet-stream";
    
    return [self uploadDataWithProgress:data fileName:fileName mimeType:mimeType progress:nil success:success failure:failure];
}

- (BOOL)uploadFile:(NSString*)path
           success:(SuccessObjectBlock)success
           failure:(FailureObjectBlock)failure {
    
    return [self uploadFileWithProgress:path progress:nil success:success failure:failure];
}

// download data

- (BOOL)downloadDataWithProgress:(ProgressDataBlock)progress
                         success:(SuccessDownloadBlock)success
                         failure:(FailureObjectBlock)failure {
    
    if (!self._identifier) { return NO; }
    NSNumber* version = [self numberForKey:@"version"];
    if (!version) { return NO; }
    
    NSString* path = [NSString stringWithFormat:@"/data/file/download/%@/%@", self._identifier, version];
    [self._session downloadPath:path progress:progress success:^(NSData* data) {
        success(self, data);
    } failure:^(NSError* error) {
        failure(self, error);
    }];
    return YES;
}

- (BOOL)downloadData:(SuccessDownloadBlock)success
             failure:(FailureObjectBlock)failure {
    
    return [self downloadDataWithProgress:nil success:success failure:failure];
}

@end
