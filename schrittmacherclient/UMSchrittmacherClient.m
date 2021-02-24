//
//  UMSchrittmacherClient.m
//  schrittmacher
//
//  Created by Andreas Fink on 26.05.2015.
//  Copyright © 2017 Andreas Fink (andreas@fink.org). All rights reserved.
//

#import "UMSchrittmacherClient.h"


@implementation SchrittmacherClient

- (SchrittmacherClient *)init
{
    self = [super init];
    if(self)
    {
        _addressType = 4;
        _localHost = [[UMHost alloc]initWithAddress:@"127.0.0.1"];
        _port = 7700; /* default port */
        _max_transiting_counter = 30;
    }
    return self;
}

- (void)start
{
    if(_uc)
    {
        [self stop];
    }
    if(_addressType==6)
    {
        _uc = [[UMSocket alloc]initWithType:UMSOCKET_TYPE_UDP6ONLY];
        _uc.objectStatisticsName = @"UMSocket(schrittmacher-client)";
    }
    else
    {
        _uc = [[UMSocket alloc]initWithType:UMSOCKET_TYPE_UDP4ONLY];
        _uc.objectStatisticsName = @"UMSocket(schrittmacher-client-ipv4-only)";
    }
    _uc.localHost =  _localHost;
    _uc.localPort = 0;
    _uc.RemoteHost = _localHost;
}

- (void) stop
{
    [_uc close];
    _uc = NULL;
}

- (void)sendStatus:(NSString *)status
{
    if(_resourceId==NULL)
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
    UMSocketError e = [_uc sendData:d toAddress:@"127.0.0.1" toPort:_port];
    if(e)
    {
        NSString *s = [UMSocket getSocketErrorString:e];
        NSLog(@"TX Error %d: %@",e,s);
    }
}


- (void)reportTransitingToHot
{
#if defined(SCHRITTMACHERCLIENT_DEBUG)
    fprintf(stderr,"SchrittmacherClient: reportTransitingToHot\n");
    fflush(stderr);
#endif
    _currentState = SchrittmacherClientCurrentState_transiting_to_hot;
    [self doHeartbeat];
}

- (void)reportTransitingToStandby
{
#if defined(SCHRITTMACHERCLIENT_DEBUG)
    fprintf(stderr,"SchrittmacherClient: reportTransitingToStandby\n");
    fflush(stderr);
#endif
    _currentState = SchrittmacherClientCurrentState_transiting_to_standby;
    [self doHeartbeat];
}

- (void)reportUnknown
{
#if defined(SCHRITTMACHERCLIENT_DEBUG)
    fprintf(stderr,"SchrittmacherClient: reportUnknown\n");
    fflush(stderr);
#endif
    _currentState = SchrittmacherClientCurrentState_unknown;
    [self doHeartbeat];
}


- (void)reportActive
{
#if defined(SCHRITTMACHERCLIENT_DEBUG)
    fprintf(stderr,"SchrittmacherClient: reportActive\n");
    fflush(stderr);
#endif

    _currentState = SchrittmacherClientCurrentState_active;
    [self doHeartbeat];
}

- (void)reportInactive
{
#if defined(SCHRITTMACHERCLIENT_DEBUG)
    fprintf(stderr,"SchrittmacherClient: reportInactive\n");
    fflush(stderr);
#endif
    _currentState = SchrittmacherClientCurrentState_inactive;
    [self doHeartbeat];
}

- (void)reportFailed:(NSString *)failureReason
{
#if defined(SCHRITTMACHERCLIENT_DEBUG)
    fprintf(stderr,"SchrittmacherClient: reportFailure:%s\n",failureReason.UTF8String);
    fflush(stderr);
#endif
    _failureReason = failureReason;
    [self sendStatus:MESSAGE_LOCAL_FAIL];
    _currentState = SchrittmacherClientCurrentState_failed;
    [self doHeartbeat];
}

- (void)signalGoHot
{
    _wantedState = SchrittmacherClientWantedState_hot;
    if(_currentState == SchrittmacherClientCurrentState_active)
    {
        return;
    }
    if(_currentState == SchrittmacherClientCurrentState_transiting_to_hot)
    {
        return;
    }
    
#if defined(SCHRITTMACHERCLIENT_DEBUG)
    fprintf(stderr,"SchrittmacherClient: signalGoHot - > new state: transiting_to_hot\n");
    fflush(stderr);
#endif

    _currentState = SchrittmacherClientCurrentState_transiting_to_hot;
    if(_go_hot_func)
    {
        (*_go_hot_func)();
    }
}

- (void)signalGoStandby
{
    _wantedState = SchrittmacherClientWantedState_standby;
    if(_currentState == SchrittmacherClientCurrentState_inactive)
    {
        return;
    }

    if(_currentState == SchrittmacherClientCurrentState_transiting_to_standby)
    {
        return;
    }
    
#if defined(SCHRITTMACHERCLIENT_DEBUG)
    fprintf(stderr,"SchrittmacherClient: signalGoStandby - > new state: transiting_to_standby\n");
    fflush(stderr);
#endif
    _currentState = SchrittmacherClientCurrentState_transiting_to_standby;
    if(_go_standby_func)
    {
        (*_go_standby_func)();
    }
}

- (void)doHeartbeat
{
    switch(_currentState)
    {
        case SchrittmacherClientCurrentState_active:
#if defined(SCHRITTMACHERCLIENT_DEBUG)
            fprintf(stderr,"SchrittmacherClient: heartbeat: hot\n");
            fflush(stderr);
#endif
            [self sendStatus:MESSAGE_LOCAL_HOT];
            _transiting_counter = 0;
            break;
            
        case SchrittmacherClientCurrentState_inactive:
#if defined(SCHRITTMACHERCLIENT_DEBUG)
            fprintf(stderr,"SchrittmacherClient: heartbeat: standby\n");
            fflush(stderr);
#endif
            [self sendStatus:MESSAGE_LOCAL_STANDBY];
            _transiting_counter = 0;
            break;

        case SchrittmacherClientCurrentState_failed:
#if defined(SCHRITTMACHERCLIENT_DEBUG)
            fprintf(stderr,"SchrittmacherClient: heartbeat: fail\n");
            fflush(stderr);
#endif
            [self sendStatus:MESSAGE_LOCAL_FAIL];
            _transiting_counter = 0;
            break;
            
        case SchrittmacherClientCurrentState_unknown:
#if defined(SCHRITTMACHERCLIENT_DEBUG)
            fprintf(stderr,"SchrittmacherClient: heartbeat: unknown\n");
            fflush(stderr);
#endif
            [self sendStatus:MESSAGE_LOCAL_UNKNOWN];
            _transiting_counter = 0;
            break;
        case SchrittmacherClientCurrentState_transiting_to_hot:
#if defined(SCHRITTMACHERCLIENT_DEBUG)
            fprintf(stderr,"SchrittmacherClient: heartbeat: transitingToHot\n");
            fflush(stderr);
#endif
            
            _transiting_counter++;
            if(_transiting_counter > _max_transiting_counter)
            {
                _currentState = SchrittmacherClientCurrentState_failed;
                [self sendStatus:MESSAGE_LOCAL_FAIL];
                _transiting_counter=0;
            }
            else
            {
                [self sendStatus:MESSAGE_LOCAL_TRANSITING_TO_HOT];
            }
            break;

        case SchrittmacherClientCurrentState_transiting_to_standby:
#if defined(SCHRITTMACHERCLIENT_DEBUG)
            fprintf(stderr,"SchrittmacherClient: heartbeat: transitingToStandby\n");
            fflush(stderr);
#endif
            _transiting_counter++;
            if(_transiting_counter > _max_transiting_counter)
            {
                _currentState = SchrittmacherClientCurrentState_failed;
                [self sendStatus:MESSAGE_LOCAL_FAIL];
                _transiting_counter=0;
            }
            else
            {
                [self sendStatus:MESSAGE_LOCAL_TRANSITING_TO_STANDBY];
            }
            break;
    }
}

- (void)log:(NSString *)n
{
    if(_loggingEnabled == NO)
    {
        return;
    }
    [_logFeed infoText:n];
}

@end

