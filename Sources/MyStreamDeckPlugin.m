//==============================================================================
/**
@file       MyStreamDeckPlugin.m

@brief      A Stream Deck plugin displaying the number of unread emails in Apple's Mail

@copyright  (c) 2018, Corsair Memory, Inc.
			This source code is licensed under the MIT-style license found in the LICENSE file.

**/
//==============================================================================

@import OSAKit;
#import "MyStreamDeckPlugin.h"

#import "ESDSDKDefines.h"
#import "ESDConnectionManager.h"
#import "ESDUtilities.h"
#import <AppKit/AppKit.h>


// Size of the images
#define IMAGE_SIZE	144



// MARK: - Utility methods


//
// Utility function to get the fullpath of an resource in the bundle
//
static NSString * GetResourcePath(NSString *inFilename)
{
	NSString *outPath = nil;
	
	if([inFilename length] > 0)
	{
		NSString * bundlePath = [ESDUtilities pluginPath];
		if(bundlePath != nil)
		{
			outPath = [bundlePath stringByAppendingPathComponent:inFilename];
		}
	}
	
	return outPath;
}


//
// Utility function to create a CGContextRef
//
static CGContextRef CreateBitmapContext(CGSize inSize)
{
	CGFloat bitmapBytesPerRow = inSize.width * 4;
	CGFloat bitmapByteCount = (bitmapBytesPerRow * inSize.height);
	
	void *bitmapData = calloc(bitmapByteCount, 1);
	if(bitmapData == NULL)
	{
		return NULL;
	}
	
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	CGContextRef context = CGBitmapContextCreate(bitmapData, inSize.width, inSize.height, 8, bitmapBytesPerRow, colorSpace, kCGImageAlphaPremultipliedLast);
	if(context == NULL)
	{
		CGColorSpaceRelease(colorSpace);
		free(bitmapData);
		return NULL;
	}
	else
	{
		CGColorSpaceRelease(colorSpace);
		return context;
	}
}

//
// Utility method that takes the path of an image and create a base64 encoded string
//
static NSString * CreateBase64EncodedString(NSString *inImagePath)
{
	NSString *outBase64PNG = nil;
	
	NSImage* image = [[NSImage alloc] initWithContentsOfFile:inImagePath];
	if(image != nil)
	{
		// Find the best CGImageRef
		CGSize iconSize = CGSizeMake(IMAGE_SIZE, IMAGE_SIZE);
		NSRect theRect = NSMakeRect(0, 0, iconSize.width, iconSize.height);
		CGImageRef imageRef = [image CGImageForProposedRect:&theRect context:NULL hints:nil];
		if(imageRef != NULL)
		{
			// Create a CGContext
			CGContextRef context = CreateBitmapContext(iconSize);
			if(context != NULL)
			{
				// Draw the Mail.app icon
				CGContextDrawImage(context, theRect, imageRef);
				
				// Generate the final image
				CGImageRef completeImage = CGBitmapContextCreateImage(context);
				if(completeImage != NULL)
				{
					// Export the image to PNG
					CFMutableDataRef pngData = CFDataCreateMutable(kCFAllocatorDefault, 0);
					if(pngData != NULL)
					{
						CGImageDestinationRef destinationRef = CGImageDestinationCreateWithData(pngData, kUTTypePNG, 1, NULL);
						if (destinationRef != NULL)
						{
							CGImageDestinationAddImage(destinationRef, completeImage, nil);
							if (CGImageDestinationFinalize(destinationRef))
							{
								NSString *base64PNG = [(__bridge NSData *)pngData base64EncodedStringWithOptions:NSDataBase64EncodingEndLineWithCarriageReturn];
								if([base64PNG length] > 0)
								{
									outBase64PNG = [NSString stringWithFormat:@"data:image/png;base64,%@\">", base64PNG];
								}
							}
							
							CFRelease(destinationRef);
						}
						
						CFRelease(pngData);
					}
					
					CFRelease(completeImage);
				}
				
				CFRelease(context);
			}
		}
	}
	
	return outBase64PNG;
}


// MARK: - MyStreamDeckPlugin

@interface MyStreamDeckPlugin ()

// The list of visible contexts
@property (strong) NSMutableArray *knownContexts;

// The Mail icon encoded in base64
@property (strong) NSString *base64MailIconString;

@property (strong) NSMutableDictionary * settingsPayload;

@end


@implementation MyStreamDeckPlugin



// MARK: - Setup the instance variables if needed

- (void)setupIfNeeded
{
	// Create the array of known contexts
	if(_knownContexts == nil)
	{
		_knownContexts = [[NSMutableArray alloc] init];
	}
    
    if(_settingsPayload == nil){
        _settingsPayload = [[NSMutableDictionary alloc] init];
    }
	
	if(_base64MailIconString == nil)
	{
		_base64MailIconString = CreateBase64EncodedString(GetResourcePath(@"RunOSAScripticon.png"));
	}
}


// MARK: - Events handler

- (void)keyDownForAction:(NSString *)action withContext:(id)context withPayload:(NSDictionary *)payload forDevice:(NSString *)deviceID
{
    OSAScript * osa;     // empty osa object
    NSDictionary * errors = nil;     //errors

    NSDictionary * tempDict = self.settingsPayload[context]; //grab 'our' copy of the settings (for this specific context/button)

    ///  * language - A string containing the OSA language, either 'AppleScript' or 'JavaScript'.
    NSString * language = tempDict[@"language"];
    
    if(tempDict[@"scriptText"] != nil)
    {
        //Handler for inline scripts
        NSString * tempSource= tempDict[@"scriptText"];
        if(tempSource != nil){
            osa = [[OSAScript alloc] initWithSource:tempSource language: [OSALanguage languageForName:language]];
        }
    }

    // Run it!
    if(osa != nil)
    {
        [osa executeAndReturnError:&errors];

        if (errors) {
            NSLog(@"errors: %@", errors);
        }
    }
}

- (void)keyUpForAction:(NSString *)action withContext:(id)context withPayload:(NSDictionary *)payload forDevice:(NSString *)deviceID
{
	// Nothing to do
}

- (void)willAppearForAction:(NSString *)action withContext:(id)context withPayload:(NSDictionary *)payload forDevice:(NSString *)deviceID
{
	// Set up the instance variables if needed
	[self setupIfNeeded];
	
    NSLog(@"willAppear: %@", payload);

    //create a temp dictionary with the "context" for this 'fake instance' with contents of settings from App
    NSDictionary * tempSettings = @{context: payload[@"settings"]};

    //add that temp dictionary to our internal not-a-database
    [self.settingsPayload addEntriesFromDictionary:tempSettings];
    
	// Add the context to the list of known contexts
	[self.knownContexts addObject:context];
}

- (void)willDisappearForAction:(NSString *)action withContext:(id)context withPayload:(NSDictionary *)payload forDevice:(NSString *)deviceID
{
	// Remove the context from the list of known contexts
	[self.knownContexts removeObject:context];
}

- (void)deviceDidConnect:(NSString *)deviceID withDeviceInfo:(NSDictionary *)deviceInfo
{
	// Nothing to do
}

- (void)deviceDidDisconnect:(NSString *)deviceID
{
	// Nothing to do
}

- (void)applicationDidLaunch:(NSDictionary *)applicationInfo
{
    // Nothing to do
}

- (void)applicationDidTerminate:(NSDictionary *)applicationInfo
{
    // Nothing to do
}

@end
