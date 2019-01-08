//==============================================================================
/**
@file       main.m

@brief      Parse the arg parameters and start the plugin

@copyright  (c) 2018, Corsair Memory, Inc.
			This source code is licensed under the MIT-style license found in the LICENSE file.

**/
//==============================================================================

#import <Foundation/Foundation.h>
#import "ESDConnectionManager.h"
#import "ESDSDKDefines.h"

#import "MyStreamDeckPlugin.h"

int main(int argc, const char * argv[])
{
	@autoreleasepool
	{
		if (argc != 9)
		{
			fprintf(stderr, "Invalid number of parameters %d instead of 9", argc);
			return 1;
		}

		int port = 0;
		NSString *pluginUUID = nil;
		NSString *registerEvent = nil;
		NSString *info = nil;

		for(int argumentIndex = 0 ; argumentIndex < 4 ; argumentIndex++)
		{
			NSString *parameter = [NSString stringWithUTF8String:argv[1 + 2 * argumentIndex]];
			NSString *value = [NSString stringWithUTF8String:argv[1 + 2 * argumentIndex + 1]];

			if ([parameter isEqualToString:@kESDSDKPortParameter])
			{
				port = [value intValue];
			}
			else if ([parameter isEqualToString:@kESDSDKPluginUUIDParameter])
			{
				pluginUUID = value;
			}
			else if ([parameter isEqualToString:@kESDSDKRegisterEventParameter])
			{
				registerEvent = value;
			}
			else if ([parameter isEqualToString:@kESDSDKInfoParameter])
			{
				info = value;
			}
		}

		if(port == 0)
		{
			fprintf(stderr, "Invalid port number");
			return 1;
		}

		if([pluginUUID length] <= 0)
		{
			fprintf(stderr, "Invalid plugin UUID");
			return 1;
		}

		if([registerEvent length] <= 0)
		{
			fprintf(stderr, "Invalid registerEvent");
			return 1;
		}

		// Create MyStreamDeckPlugin
		MyStreamDeckPlugin *eventsManager = [[MyStreamDeckPlugin alloc] init];

		// Create the connection manager
		ESDConnectionManager * __unused connectionManager = [[ESDConnectionManager alloc] initWithPort:port andPluginUUID:pluginUUID andRegisterEvent:registerEvent andInfo:info andDelegate:eventsManager];


		// Start the runloop
		BOOL keepRunning = YES;
		while(keepRunning && [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]])
		{

		}
	}

	return 0;
}
