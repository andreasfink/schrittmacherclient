//
//  SchrittmacherClient.h
//  schrittmacher
//
//  Created by Andreas Fink on 26.05.2015.
//  Copyright (c) 2016 Andreas Fink
//

#import <ulib/ulib.h>

#define MESSAGE_LOCAL_HOT           @"LHOT"
#define MESSAGE_LOCAL_STANDBY       @"LSBY"
#define MESSAGE_LOCAL_UNKNOWN       @"LUNK"
#define MESSAGE_LOCAL_FAIL          @"LFAI"

@interface SchrittmacherClient : UMObject
{
    NSString *resourceId;
    int port;
    int addressType;
    UMSocket *uc;
    UMHost *localHost;
}

@property(readwrite,strong)     NSString *resourceId;
@property(readwrite,assign)     int port;
@property(readwrite,strong)     id  delegate;
@property(readwrite,assign)     int addressType;

- (void)heartbeatHot;
- (void)heartbeatStandby;
- (void)heartbeatUnknown;
- (void)notifyFailure;
- (void)start;
- (void)stop;
- (void)sendStatus:(NSString *)status;

@end

