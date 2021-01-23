//
//  SchrittmacherClient.h
//  schrittmacher
//
//  Created by Andreas Fink on 26.05.2015.
//  Copyright © 2017 Andreas Fink (andreas@fink.org). All rights reserved.
//

#import <ulib/ulib.h>

#define MESSAGE_LOCAL_HOT           @"LHOT"
#define MESSAGE_LOCAL_STANDBY       @"LSBY"
#define MESSAGE_LOCAL_UNKNOWN       @"LUNK"
#define MESSAGE_LOCAL_FAIL          @"LFAI"

typedef enum SchrittmacherClientWantedState
{
    SchrittmacherClientWantedState_inactive,
    SchrittmacherClientWantedState_active,
} SchrittmacherClientWantedState;

typedef enum SchrittmacherClientCurrentState
{
    SchrittmacherClientCurrentState_inactive,
    SchrittmacherClientCurrentState_active,
    SchrittmacherClientCurrentState_failed,
    SchrittmacherClientCurrentState_unknown,
    SchrittmacherClientCurrentState_transiting_to_hot,
    SchrittmacherClientCurrentState_transiting_to_standby,
} SchrittmacherClientCurrentState;


typedef void (*schrittmacher_func_ptr)(void);

@interface SchrittmacherClient : UMObject
{
    NSString                        *_resourceId;
    int                             _port;
    int                             _addressType;
    UMSocket                        *_uc;
    UMHost                          *_localHost;
    SchrittmacherClientWantedState  _wantedState;
    SchrittmacherClientCurrentState _currentState;
    schrittmacher_func_ptr          _go_hot_func;
    schrittmacher_func_ptr          _go_standby_func;
    int                             _max_transiting_counter;
    int                             _transiting_counter;
}

@property(readwrite,strong)     NSString *resourceId;
@property(readwrite,assign)     int port;
@property(readwrite,strong)     id  delegate;
@property(readwrite,assign)     int addressType;
@property(readwrite,assign)     SchrittmacherClientWantedState  wantedState;
@property(readwrite,assign)     SchrittmacherClientCurrentState currentState;
@property(readwrite,assign)     schrittmacher_func_ptr          go_hot_func;
@property(readwrite,assign)     schrittmacher_func_ptr          go_standby_func;
@property(readwrite,assign)     int max_transiting_counter;
@property(readwrite,assign)     int transiting_counter;

- (void)heartbeatHot;
- (void)heartbeatStandby;
- (void)heartbeatUnknown;
- (void)notifyFailure;
- (void)start;
- (void)stop;
- (void)sendStatus:(NSString *)status;
- (void)signalGoHot;
- (void)signalGoStandby;
- (void)doHeartbeat;

@end

