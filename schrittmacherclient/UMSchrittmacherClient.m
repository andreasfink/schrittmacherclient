//
//  UMSchrittmacherClient.m
//  schrittmacher
//
//  Created by Andreas Fink on 26.05.2015.
//  Copyright © 2017 Andreas Fink (andreas@fink.org). All rights reserved.
//

#import "UMSchrittmacherClient.h"


@implementation SchrittmacherClient

@synthesize resourceId;
@synthesize port;
@synthesize addressType;

- (SchrittmacherClient *)init
{
    self = [super init];
    if(self)
    {
        addressType = 4;
        localHost = [[UMHost alloc]initWithAddress:@"127.0.0.1"];
        port = 7700; /* default port */
    }
    return self;
}

- (void)start
{
    if(uc)
    {
        [self stop];
    }
    if(addressType==6)
    {
        uc = [[UMSocket alloc]initWithType:UMSOCKET_TYPE_UDP6ONLY];
        uc.objectStatisticsName = @"UMSocket(schrittmacher-client)";
    }
    else
    {
        uc = [[UMSocket alloc]initWithType:UMSOCKET_TYPE_UDP4ONLY];
        uc.objectStatisticsName = @"UMSocket(schrittmacher-client-ipv4-only)";
    }
    uc.localHost =  localHost;
    uc.localPort = 0;
    uc.RemoteHost = localHost;
}

- (void) stop
{
    [uc close];
    uc = NULL;
}

- (void)sendStatus:(NSString *)status
{
    if(resourceId==NULL)
    {
        @throw([NSException exceptionWithName:@"INV_RES_ID" reason:@"Schrittmacher resource-id is not set" userInfo:NULL]);
    }
    if(status==NULL)
    {
        @throw([NSException exceptionWithName:@"INV_DATA" reason:@"Schrittmacher invalid status requested" userInfo:NULL]);
    }

    NSDictionary *dict = @{ @"resource" : self.resourceId,
                            @"status"   : status,
                            @"priority" : @(0),
                            @"random"   : @(0)};
    
    NSString *msg = [dict jsonString];

    const char *utf8 = msg.UTF8String;
    size_t len = strlen(utf8);
    NSData *d = [NSData dataWithBytes:utf8 length:len];
    UMSocketError e = [uc sendData:d toAddress:@"127.0.0.1" toPort:port];
    if(e)
    {
        NSString *s = [UMSocket getSocketErrorString:e];
        NSLog(@"TX Error %d: %@",e,s);
    }
}

- (void)heartbeatHot
{
    [self sendStatus:MESSAGE_LOCAL_HOT];
}

- (void)heartbeatStandby
{
    [self sendStatus:MESSAGE_LOCAL_STANDBY];
}

- (void)heartbeatUnknown
{
    [self sendStatus:MESSAGE_LOCAL_UNKNOWN];
}


-(void)notifyFailure
{
    [self sendStatus:MESSAGE_LOCAL_FAIL];
}

@end

