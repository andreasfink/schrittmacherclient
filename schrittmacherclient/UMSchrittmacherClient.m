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
        _port = 7701; /* default port */
        _max_transiting_counter = 30;
        _pid = (long)getpid();
        _adminweb_port = 0;
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
    if(_loggingEnabled && (_logLevel <= UMLOG_DEBUG))
    {
        [_logFeed debugText:[NSString stringWithFormat:@"SchrittmacherClient: sending status %@",status]];
    }

    if(_resourceId==NULL)
    {
        @throw([NSException exceptionWithName:@"INV_RES_ID" reason:@"Schrittmacher resource-id is not set" userInfo:NULL]);
    }
    if(status==NULL)
    {
        @throw([NSException exceptionWithName:@"INV_DATA" reason:@"Schrittmacher invalid status requested" userInfo:NULL]);
    }

    NSMutableDictionary *dict = [[NSMutableDictionary alloc]init];
    dict[@"resource"] = self.resourceId,
    dict[@"status"] = status,
    dict[@"priority"] = @(0),
    if(_pid>0)
    {
        dict[@"pid"] = @(_pid);
    }
    if(_adminweb_port>0)
    {
        dict[@"adminweb-port" = @(_adminweb_port);
    }
    dict[@"random"] =@(0);
    
    NSString *msg = [dict jsonString];

    const char *utf8 = msg.UTF8String;
    size_t len = strlen(utf8);
    NSData *d = [NSData dataWithBytes:utf8 length:len];
    NSString *addr;
    if(_daemonAddress)
    {
        addr = _daemonAddress;
    }
    else
    {
        addr = @"127.0.0.1";
    }
    UMSocketError e = [_uc sendData:d toAddress:addr toPort:_port];
    if(e)
    {
        NSString *s = [UMSocket getSocketErrorString:e];
        NSLog(@"TX Error %d: %@",e,s);
    }
}


- (void)reportTransitingToHot
{
    if(_loggingEnabled && (_logLevel <= UMLOG_DEBUG))
    {
        [_logFeed debugText:@"SchrittmacherClient: reportTransitingToHot"];
    }
    _currentState = SchrittmacherClientCurrentState_transiting_to_hot;
    [self doHeartbeat];
}

- (void)reportTransitingToStandby
{
    if(_loggingEnabled && (_logLevel <= UMLOG_DEBUG))
    {
        [_logFeed debugText:@"SchrittmacherClient: reportTransitingToStandby"];
    }
    _currentState = SchrittmacherClientCurrentState_transiting_to_standby;
    [self doHeartbeat];
}

- (void)reportUnknown
{
    if(_loggingEnabled && (_logLevel <= UMLOG_DEBUG))
    {
        [_logFeed debugText:@"SchrittmacherClient: reportUnknown"];
    }
    _currentState = SchrittmacherClientCurrentState_unknown;
    [self doHeartbeat];
}


- (void)reportActive
{
    if(_loggingEnabled && (_logLevel <= UMLOG_DEBUG))
    {
        [_logFeed debugText:@"SchrittmacherClient: reportActive"];
    }
    _currentState = SchrittmacherClientCurrentState_active;
    [self doHeartbeat];
}

- (void)reportInactive
{
    if(_loggingEnabled && (_logLevel <= UMLOG_DEBUG))
    {
        [_logFeed debugText:@"SchrittmacherClient: reportInactive"];
    }
    _currentState = SchrittmacherClientCurrentState_inactive;
    [self doHeartbeat];
}

- (void)reportFailed:(NSString *)failureReason
{
    if(_loggingEnabled && (_logLevel <= UMLOG_DEBUG))
    {
        NSString *s = [NSString stringWithFormat:@"SchrittmacherClient: reportFailed:%@",failureReason];
        [_logFeed debugText:s];
    }
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
    if(_loggingEnabled && (_logLevel <= UMLOG_DEBUG))
    {
        [_logFeed debugText:@"SchrittmacherClient: signalGoHot - > new state: transiting_to_hot"];
    }
    _currentState = SchrittmacherClientCurrentState_transiting_to_hot;
    if(_go_hot_func)
    {
        (*_go_hot_func)();
    }
    else
    {
        [_logFeed majorErrorText:@"SchrittmacherClient: _go_hot_func is NULL"];
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
    if(_loggingEnabled && (_logLevel <= UMLOG_DEBUG))
    {
        [_logFeed debugText:@"SchrittmacherClient: signalGoStandby - > new state: transiting_to_standby"];
    }
    _currentState = SchrittmacherClientCurrentState_transiting_to_standby;
    if(_go_standby_func)
    {
        (*_go_standby_func)();
    }
    else
    {
        [_logFeed majorErrorText:@"SchrittmacherClient: _go_standby_func is NULL"];
    }
}

- (void)doHeartbeat
{
    switch(_currentState)
    {
        case SchrittmacherClientCurrentState_active:
            [self sendStatus:MESSAGE_LOCAL_HOT];
            _transiting_counter = 0;
            break;
            
        case SchrittmacherClientCurrentState_inactive:
            [self sendStatus:MESSAGE_LOCAL_STANDBY];
            _transiting_counter = 0;
            break;

        case SchrittmacherClientCurrentState_failed:
            [self sendStatus:MESSAGE_LOCAL_FAIL];
            _transiting_counter = 0;
            break;
            
        case SchrittmacherClientCurrentState_unknown:
            [self sendStatus:MESSAGE_LOCAL_UNKNOWN];
            _transiting_counter = 0;
            break;
        case SchrittmacherClientCurrentState_transiting_to_hot:
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

- (void)requestTakeover
{
    [self sendStatus:MESSAGE_LOCAL_REQUEST_TAKEOVER];
}

- (void)requestFailover
{
    [self sendStatus:MESSAGE_LOCAL_REQUEST_FAILOVER];
}

- (void)log:(NSString *)n
{
    if(_loggingEnabled == NO)
    {
        return;
    }
    [_logFeed infoText:n];
}


- (NSString *)wantedStateString
{
    switch(_wantedState)
    {
        case SchrittmacherClientWantedState_hot:
            return @"hot";
            break;
        case SchrittmacherClientWantedState_standby:
            return @"standby";
            break;
        default:
            return [NSString stringWithFormat:@"unknown wanted state %d",_wantedState];
    }
}

- (NSString *)currentStateString
{
    switch(_currentState)
    {
        case SchrittmacherClientCurrentState_inactive:
            return @"inactive";
            break;
        case SchrittmacherClientCurrentState_active:
            return @"active";
            break;
        case SchrittmacherClientCurrentState_failed:
            return @"failed";
            break;
        case SchrittmacherClientCurrentState_unknown:
            return @"unknown";
            break;
        case SchrittmacherClientCurrentState_transiting_to_hot:
            return @"transiting-to-hot";
            break;
        case SchrittmacherClientCurrentState_transiting_to_standby:
            return @"transiting-to-standby";
            break;
        default:
            return [NSString stringWithFormat:@"unknown current state %d",_currentState];
    }
}

@end

