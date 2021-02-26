//
//  SchrittmacherClient.h
//  schrittmacher
//
//  Created by Andreas Fink on 26.05.2015.
//  Copyright © 2017 Andreas Fink (andreas@fink.org). All rights reserved.
//

#import <ulib/ulib.h>

#define MESSAGE_LOCAL_HOT                   @"LHOT"
#define MESSAGE_LOCAL_STANDBY               @"LSBY"
#define MESSAGE_LOCAL_UNKNOWN               @"LUNK"
#define MESSAGE_LOCAL_FAIL                  @"LFAI"
#define MESSAGE_LOCAL_TRANSITING_TO_HOT     @"L2HT"
#define MESSAGE_LOCAL_TRANSITING_TO_STANDBY @"L2SB"
#define MESSAGE_LOCAL_REQUEST_FAILOVER      @"LRFO"
#define MESSAGE_LOCAL_REQUEST_TAKEOVER      @"LRTO"

typedef enum SchrittmacherClientWantedState
{
    SchrittmacherClientWantedState_hot                      = 101,
    SchrittmacherClientWantedState_standby                  = 102,
} SchrittmacherClientWantedState;

typedef enum SchrittmacherClientCurrentState
{
    SchrittmacherClientCurrentState_inactive                = 200,
    SchrittmacherClientCurrentState_active                  = 201,
    SchrittmacherClientCurrentState_failed                  = 202,
    SchrittmacherClientCurrentState_unknown                 = 203,
    SchrittmacherClientCurrentState_transiting_to_hot       = 204,
    SchrittmacherClientCurrentState_transiting_to_standby   = 205,
} SchrittmacherClientCurrentState;


typedef void (*schrittmacher_func_ptr)(void);

@interface SchrittmacherClient : UMObject
{
    NSString                        *_resourceId;
    int                             _port;
    int                             _addressType;
    UMSocket                        *_uc;
    UMHost                          *_localHost;
    NSString                        *_daemonAddress;
    SchrittmacherClientWantedState  _wantedState;
    SchrittmacherClientCurrentState _currentState;
    schrittmacher_func_ptr          _go_hot_func;
    schrittmacher_func_ptr          _go_standby_func;
    int                             _max_transiting_counter;
    int                             _transiting_counter;
    NSString                        *_failureReason;
    BOOL                            _loggingEnabled;
    UMLogLevel                      _logLevel;
}

- (NSString *)wantedStateString;
- (NSString *)currentStateString;
@property(readwrite,strong)     NSString *daemonAddress;

@property(readwrite,strong)     NSString *resourceId;
@property(readwrite,assign)     int port;
@property(readwrite,assign)     int addressType;
@property(readwrite,strong)     id  delegate;
@property(readwrite,assign)     SchrittmacherClientWantedState  wantedState;
@property(readwrite,assign)     SchrittmacherClientCurrentState currentState;
@property(readwrite,assign)     schrittmacher_func_ptr          go_hot_func;
@property(readwrite,assign)     schrittmacher_func_ptr          go_standby_func;
@property(readwrite,assign)     int max_transiting_counter;
@property(readwrite,assign)     int transiting_counter;
@property(readwrite,strong)     NSString                        *failureReason;
@property(readwrite,assign)     BOOL                            loggingEnabled;
@property(readwrite,assign)     UMLogLevel                      logLevel;

- (void)reportActive;
- (void)reportInactive;
- (void)reportFailed:(NSString *)failureReason;
- (void)reportTransitingToHot;
- (void)reportTransitingToStandby;
- (void)reportUnknown;
- (void)start;
- (void)stop;
- (void)signalGoHot;
- (void)signalGoStandby;
- (void)doHeartbeat;
- (void)log:(NSString *)n;
- (void)requestTakeover;
- (void)requestFailover;

//- (void)sendStatus:(NSString *)status;

@end

