//==============================================================================
/**
@file       ESDConnectionManager.h

@brief      Wrapper to implement the communication with the Stream Deck application

@copyright  (c) 2018, Corsair Memory, Inc.
			This source code is licensed under the MIT-style license found in the LICENSE file.

**/
//==============================================================================

#import <Foundation/Foundation.h>

#import "ESDEventsProtocol.h"
#import "ESDSDKDefines.h"


NS_ASSUME_NONNULL_BEGIN


@interface ESDConnectionManager : NSObject

- (instancetype)initWithPort:(int)inPort
		andPluginUUID:(NSString *)inPluginUUID
		andRegisterEvent:(NSString *)inRegisterEvent
		andInfo:(NSString *)inInfo
		andDelegate:(id<ESDEventsProtocol>)inDelegate;


-(void)setTitle:(nullable NSString *)inTitle withContext:(id)inContext withTarget:(ESDSDKTarget)inTarget;
-(void)setImage:(nullable NSString*)inBase64ImageString withContext:(id)inContext withTarget:(ESDSDKTarget)inTarget;
-(void)showAlertForContext:(id)inContext;
-(void)showOKForContext:(id)inContext;
-(void)setSettings:(NSDictionary *)inSettings forContext:(id)inContext;
-(void)setState:(NSNumber *)inState forContext:(id)inContext;
-(void)logMessage:(NSString *)inMessage;

@end

NS_ASSUME_NONNULL_END

