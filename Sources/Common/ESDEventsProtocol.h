//==============================================================================
/**
@file       ESDEventsProtocol.h

@brief      Protocol used for the communication with the Stream Deck application

@copyright  (c) 2018, Corsair Memory, Inc.
			This source code is licensed under the MIT-style license found in the LICENSE file.

**/
//==============================================================================

#import <Foundation/Foundation.h>

@class ESDConnectionManager;

NS_ASSUME_NONNULL_BEGIN

@protocol ESDEventsProtocol <NSObject>

@required

- (void)setConnectionManager:(ESDConnectionManager *)connectionManager;


@optional

- (void)keyDownForAction:(NSString *)action withContext:(id)context withPayload:(NSDictionary *)payload forDevice:(NSString *)deviceID;
- (void)keyUpForAction:(NSString *)action withContext:(id)context withPayload:(NSDictionary *)payload forDevice:(NSString *)deviceID;

- (void)willAppearForAction:(NSString *)action withContext:(id)context withPayload:(NSDictionary *)payload forDevice:(NSString *)deviceID;
- (void)willDisappearForAction:(NSString *)action withContext:(id)context withPayload:(NSDictionary *)payload forDevice:(NSString *)deviceID;

- (void)deviceDidConnect:(NSString *)deviceID withDeviceInfo:(NSDictionary *)deviceInfo;
- (void)deviceDidDisconnect:(NSString *)deviceID;

- (void)applicationDidLaunch:(NSDictionary *)applicationInfo;
- (void)applicationDidTerminate:(NSDictionary *)applicationInfo;

@end


NS_ASSUME_NONNULL_END

