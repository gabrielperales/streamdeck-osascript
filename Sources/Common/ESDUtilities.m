//==============================================================================
/**
@file       ESDUtilities.m

@brief      Various filesystem and other utility functions

@copyright  (c) 2018, Corsair Memory, Inc.
			This source code is licensed under the MIT-style license found in the LICENSE file.

**/
//==============================================================================

#include "ESDUtilities.h"


@implementation ESDUtilities


+(nullable NSString *)pluginPath
{
	static NSString *sPluginPath = nil;
	
	if(sPluginPath == nil)
	{
		CFBundleRef bundleRef = CFBundleGetMainBundle();
		if(bundleRef != NULL)
		{
			CFURLRef executableURL = CFBundleCopyExecutableURL(bundleRef);
			if(executableURL != NULL)
			{
				CFURLRef checkURL = CFURLCreateCopyDeletingLastPathComponent(kCFAllocatorDefault, executableURL);
				while(checkURL != NULL)
				{
					CFStringRef lastPathComponent = CFURLCopyLastPathComponent(checkURL);
					if(lastPathComponent == NULL || (CFStringCompare(lastPathComponent, CFSTR("/"), 0) == kCFCompareEqualTo) || (CFStringCompare(lastPathComponent, CFSTR(".."), 0) == kCFCompareEqualTo))
					{
						if(lastPathComponent != NULL)
						{
							CFRelease(lastPathComponent);
						}
						
						CFRelease(checkURL);
						checkURL = NULL;
						break;
					}
					
					CFRelease(lastPathComponent);
					
					CFStringRef pathExtension = CFURLCopyPathExtension(checkURL);
					if(pathExtension != NULL)
					{
						if(CFStringCompare(pathExtension, CFSTR("sdPlugin"), 0) == kCFCompareEqualTo)
						{
							CFStringRef path = CFURLCopyFileSystemPath(checkURL, kCFURLPOSIXPathStyle);
							if(path != NULL)
							{
								sPluginPath = [[NSString alloc] initWithString:(__bridge NSString *)(path)];
								CFRelease(path);
							}
						}
						
						CFRelease(pathExtension);
					}
					
					CFURLRef previousURL = checkURL;
					checkURL = CFURLCreateCopyDeletingLastPathComponent(kCFAllocatorDefault, previousURL);
					CFRelease(previousURL);
					
					if(sPluginPath != nil)
					{
						CFRelease(checkURL);
						checkURL = NULL;
						break;
					}
				}
				
				CFRelease(executableURL);
			}
		}
	}
	
	return sPluginPath;
}


@end

