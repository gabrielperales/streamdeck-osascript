//==============================================================================
/**
@file       ESDConnectionManager.m

@brief      Wrapper to implement the communication with the Stream Deck application

@copyright  (c) 2018, Corsair Memory, Inc.
			This source code is licensed under the MIT-style license found in the LICENSE file.

**/
//==============================================================================

#import "ESDConnectionManager.h"

#import "SRWebSocket.h"

@interface ESDConnectionManager () <SRWebSocketDelegate>

@property (strong) SRWebSocket *socket;

@property (assign) int port;
@property (strong) NSString *pluginUUID;
@property (strong) NSString *registerEvent;
@property (strong) NSString *applicationVersion;
@property (strong) NSString *applicationPlatform;
@property (strong) NSString *applicationLanguage;
@property (strong) NSString *devicesInfo;

@property (weak) id<ESDEventsProtocol> delegate;

@end


@implementation ESDConnectionManager


- (instancetype)initWithPort:(int)inPort
	andPluginUUID:(NSString *)inPluginUUID
	andRegisterEvent:(NSString *)inRegisterEvent
	andInfo:(NSString *)inInfo
	andDelegate:(id<ESDEventsProtocol>)inDelegate
{
	self = [super init];
	if (self)
	{
		_port = inPort;
		_pluginUUID = inPluginUUID;
		_registerEvent = inRegisterEvent;
		_delegate = inDelegate;
		[_delegate setConnectionManager:self];

		NSError *error = nil;
		NSDictionary *json = [NSJSONSerialization JSONObjectWithData:[inInfo dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingMutableContainers error:&error];
		
		NSDictionary *applicationInfo = json[@kESDSDKApplicationInfo];
		_applicationVersion = applicationInfo[@kESDSDKApplicationInfoVersion];
		_applicationPlatform = applicationInfo[@kESDSDKApplicationInfoPlatform];
		_applicationLanguage = applicationInfo[@kESDSDKApplicationInfoLanguage];
		
		_devicesInfo = json[@kESDSDKDevicesInfo];

		NSURLRequest *urlRequest = [[NSURLRequest alloc] initWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"ws://127.0.0.1:%d", inPort]]];
		self.socket = [[SRWebSocket alloc] initWithURLRequest:urlRequest];
		self.socket.delegate = self;
		[self.socket open];
	}
	return self;
}


#pragma mark - APIs


-(void)setTitle:(nullable NSString *)inTitle withContext:(id)inContext withTarget:(ESDSDKTarget)inTarget
{
	if(inContext != nil)
	{
		NSDictionary *json = nil;

		if(inTitle != nil)
		{
			json = @{
					   @kESDSDKCommonEvent: @kESDSDKEventSetTitle,
					   @kESDSDKCommonContext: inContext,
					   @kESDSDKCommonPayload: @{
							@kESDSDKPayloadTitle: inTitle,
							@kESDSDKPayloadTarget: [NSNumber numberWithInt:inTarget]
						}
					   };
		}
		else
		{
			json = @{
					   @kESDSDKCommonEvent: @kESDSDKEventSetTitle,
					   @kESDSDKCommonContext: inContext,
					   @kESDSDKCommonPayload: @{
							@kESDSDKPayloadTarget: [NSNumber numberWithInt:inTarget]
						}
					   };
		}

		NSError *err = nil;
		NSData *jsonData = [NSJSONSerialization dataWithJSONObject:json options:NSJSONWritingPrettyPrinted error:&err];
		if (err == nil)
		{
			NSError *error = nil;
			[self.socket sendData:jsonData error:&error];
			if(error != nil)
			{
				NSLog(@"Failed to change the title due to error %@", error);
			}
		}
	}
}

-(void)setImage:(NSString*)inBase64ImageString withContext:(id)inContext withTarget:(ESDSDKTarget)inTarget
{
	if(inContext != nil)
	{
		NSDictionary *json = nil;
		
		if(inBase64ImageString == nil)
		{
			json = @{
						@kESDSDKCommonEvent: @kESDSDKEventSetImage,
						@kESDSDKCommonContext: inContext,
						@kESDSDKCommonPayload: @{
							@kESDSDKPayloadTarget: [NSNumber numberWithInt:inTarget]
						}
					};
		}
		else
		{
			json = @{
						@kESDSDKCommonEvent: @kESDSDKEventSetImage,
						@kESDSDKCommonContext: inContext,
						@kESDSDKCommonPayload: @{
							@kESDSDKPayloadImage: inBase64ImageString,
							@kESDSDKPayloadTarget: [NSNumber numberWithInt:inTarget]
						}
					};
		}

		NSError *err = nil;
		NSData *jsonData = [NSJSONSerialization dataWithJSONObject:json options:NSJSONWritingPrettyPrinted error:&err];
		if (err == nil)
		{
			NSError *error = nil;
			[self.socket sendData:jsonData error:&error];
			if(error != nil)
			{
				NSLog(@"Failed to change the image due to error %@", error);
			}
		}
	}
}

-(void)showAlertForContext:(id)inContext
{
	if(inContext != nil)
	{
		NSDictionary *json = @{
					   @kESDSDKCommonEvent: @kESDSDKEventShowAlert,
					   @kESDSDKCommonContext: inContext,
					   };

		NSError *err = nil;
		NSData *jsonData = [NSJSONSerialization dataWithJSONObject:json options:NSJSONWritingPrettyPrinted error:&err];
		if (err == nil)
		{
			NSError *error = nil;
			[self.socket sendData:jsonData error:&error];
			if(error != nil)
			{
				NSLog(@"Failed to show the alert due to error %@", error);
			}
		}
	}
}

-(void)showOKForContext:(id)inContext
{
	if(inContext != nil)
	{
		NSDictionary *json = @{
					   @kESDSDKCommonEvent: @kESDSDKEventShowOK,
					   @kESDSDKCommonContext: inContext,
					   };

		NSError *err = nil;
		NSData *jsonData = [NSJSONSerialization dataWithJSONObject:json options:NSJSONWritingPrettyPrinted error:&err];
		if (err == nil)
		{
			NSError *error = nil;
			[self.socket sendData:jsonData error:&error];
			if(error != nil)
			{
				NSLog(@"Failed to show OK due to error %@", error);
			}
		}
	}
}

-(void)setSettings:(NSDictionary *)inSettings forContext:(id)inContext
{
	if(inSettings != nil && inContext != nil)
	{
		NSDictionary *json = @{
					   @kESDSDKCommonEvent: @kESDSDKEventSetSettings,
					   @kESDSDKCommonContext: inContext,
					   @kESDSDKCommonPayload: inSettings
					   };
		
		NSError *err = nil;
		NSData *jsonData = [NSJSONSerialization dataWithJSONObject:json options:0 error:&err];
		if (err == nil)
		{
			NSError *error = nil;
			[self.socket sendData:jsonData error:&error];
			if(error != nil)
			{
				NSLog(@"Failed to change the settings due to error %@", error);
			}
		}
	}
}

-(void)setState:(NSNumber *)inState forContext:(id)inContext
{
	if(inState != nil && inContext != nil)
	{
		NSDictionary *json = @{
				   @kESDSDKCommonEvent: @kESDSDKEventSetState,
				   @kESDSDKCommonContext: inContext,
				   @kESDSDKCommonPayload: @{
				   		@kESDSDKPayloadState: inState
					}
				   };
		
		NSError *err = nil;
		NSData *jsonData = [NSJSONSerialization dataWithJSONObject:json options:NSJSONWritingPrettyPrinted error:&err];
		if (err == nil)
		{
			NSError *error = nil;
			[self.socket sendData:jsonData error:&error];
			if(error != nil)
			{
				NSLog(@"Failed to change the state due to error %@", error);
			}
		}
	}
}

-(void)logMessage:(NSString *)inMessage
{
	if([inMessage length] > 0)
	{
		NSDictionary *json = @{
				   @kESDSDKCommonEvent: @kESDSDKEventLogMessage,
				   @kESDSDKCommonPayload: @{
				   		@kESDSDKPayloadMessage: inMessage
					}
				   };
		
		NSError *err = nil;
		NSData *jsonData = [NSJSONSerialization dataWithJSONObject:json options:NSJSONWritingPrettyPrinted error:&err];
		if (err == nil)
		{
			NSError *error = nil;
			[self.socket sendData:jsonData error:&error];
			if(error != nil)
			{
				NSLog(@"Failed to change the state due to error %@", error);
			}
		}
	}
}


#pragma mark - WebSocket events

- (void)webSocket:(SRWebSocket *)webSocket didReceiveMessage:(id)message
{
	@try
	{
		NSError *error = nil;
		NSDictionary *json = nil;
		if([message isKindOfClass:[NSString class]])
		{
			json = [NSJSONSerialization JSONObjectWithData:[message dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingMutableContainers error:&error];
		}
		else if([message isKindOfClass:[NSData class]])
		{
			json = [NSJSONSerialization JSONObjectWithData:message options:NSJSONReadingMutableContainers error:&error];
		}

		NSString *event = json[@kESDSDKCommonEvent];
		id context = json[@kESDSDKCommonContext];
		NSString *action = json[@kESDSDKCommonAction];
		NSDictionary *payload = json[@kESDSDKCommonPayload];
		NSString *deviceID = json[@kESDSDKCommonDevice];

	 	if([event isEqualToString:@kESDSDKEventKeyDown])
	 	{
	 		if([self.delegate respondsToSelector:@selector(keyDownForAction:withContext:withPayload:forDevice:)])
	 		{
				[self.delegate keyDownForAction:action withContext:context withPayload:payload forDevice:deviceID];
	 		}
	 	}
		else if([event isEqualToString:@kESDSDKEventKeyUp])
	 	{
			if([self.delegate respondsToSelector:@selector(keyUpForAction:withContext:withPayload:forDevice:)])
	 		{
				[self.delegate keyUpForAction:action withContext:context withPayload:payload forDevice:deviceID];
	 		}
	 	}
	 	else if([event isEqualToString:@kESDSDKEventWillAppear])
	 	{
			if([self.delegate respondsToSelector:@selector(willAppearForAction:withContext:withPayload:forDevice:)])
	 		{
				[self.delegate willAppearForAction:action withContext:context withPayload:payload forDevice:deviceID];
	 		}
	 	}
	 	else if([event isEqualToString:@kESDSDKEventWillDisappear])
	 	{
			if([self.delegate respondsToSelector:@selector(willDisappearForAction:withContext:withPayload:forDevice:)])
	 		{
				[self.delegate willDisappearForAction:action withContext:context withPayload:payload forDevice:deviceID];
	 		}
	 	}
	 	else if([event isEqualToString:@kESDSDKEventDeviceDidConnect])
	 	{
			if([self.delegate respondsToSelector:@selector(deviceDidConnect:withDeviceInfo:)])
	 		{
	 			NSDictionary *deviceInfo = json[@kESDSDKCommonDeviceInfo];
	 			if(deviceID != nil)
	 			{
					[self.delegate deviceDidConnect:deviceID withDeviceInfo:deviceInfo];
				}
	 		}
	 	}
	 	else if([event isEqualToString:@kESDSDKEventDeviceDidDisconnect])
	 	{
			if([self.delegate respondsToSelector:@selector(deviceDidDisconnect:)])
	 		{
				[self.delegate deviceDidDisconnect:deviceID];
	 		}
	 	}
	 	else if([event isEqualToString:@kESDSDKEventApplicationDidLaunch])
	 	{
			if([self.delegate respondsToSelector:@selector(applicationDidLaunch:)])
	 		{
	 			[self.delegate applicationDidLaunch:payload];
	 		}
	 	}
	 	else if([event isEqualToString:@kESDSDKEventApplicationDidTerminate])
	 	{
			if([self.delegate respondsToSelector:@selector(applicationDidTerminate:)])
	 		{
	 			[self.delegate applicationDidTerminate:payload];
	 		}
	 	}
	}
	@catch(...)
	{
		NSLog(@"Failed to parse the JSON data: %@", message);
	}
}

- (void)webSocketDidOpen:(SRWebSocket *)webSocket
{
	NSDictionary *registerJson = @{
				   @kESDSDKCommonEvent: self.registerEvent,
				   @kESDSDKRegisterUUID: self.pluginUUID };

	NSError *err = nil;
	NSData *jsonData = [NSJSONSerialization dataWithJSONObject:registerJson options:NSJSONWritingPrettyPrinted error:&err];
	if (err == nil)
	{
		NSError *error = nil;
		[self.socket sendData:jsonData error:&error];
		if(error != nil)
		{
			NSLog(@"Failed to register the plugin due to error %@", error);
		}
	}
}

- (void)webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error
{
	NSLog(@"The socket could not be opened due to the error %@", error);
}

- (void)webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean
{
	NSLog(@"Websocket closed with reason: %@", reason);
	
	// The socket has been closed so we just quit
	exit(0);
}


@end
