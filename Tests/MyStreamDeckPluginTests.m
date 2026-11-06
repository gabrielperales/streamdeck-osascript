//==============================================================================
/**
@file       MyStreamDeckPluginTests.m

@brief      Behaviour tests for MyStreamDeckPlugin, driven through the same
            event methods ESDConnectionManager calls. Scripts prove they ran
            by writing a marker file, so the tests run real AppleScript/JXA.

            Run with `make test` from the repository root. No Xcode needed.
**/
//==============================================================================

#import <Foundation/Foundation.h>
#import "MyStreamDeckPlugin.h"

static NSString * const kAction = @"com.gabrielperales.osascript.action";
static NSString * const kDevice = @"TEST-DEVICE";

static int sFailures = 0;
static int sTests = 0;
static NSString *sCurrentTest = nil;

#define CHECK(cond, ...) do { \
	if(!(cond)) { \
		sFailures++; \
		fprintf(stderr, "  FAIL %s (%s:%d): %s\n", sCurrentTest.UTF8String, __FILE__, __LINE__, \
			[[NSString stringWithFormat:__VA_ARGS__] UTF8String]); \
	} \
} while(0)


// MARK: - Helpers

static NSString * TempMarkerPath(void)
{
	NSString *name = [NSString stringWithFormat:@"osascript-test-%@", [NSUUID UUID].UUIDString];
	return [NSTemporaryDirectory() stringByAppendingPathComponent:name];
}

static NSString * ReadMarker(NSString *path)
{
	return [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
}

// AppleScript that writes `value` to `path`.
static NSString * AppleScriptWriting(NSString *value, NSString *path)
{
	return [NSString stringWithFormat:@"do shell script \"printf %@ > \" & quoted form of \"%@\"", value, path];
}

// JXA that writes `value` to `path`.
static NSString * JXAWriting(NSString *value, NSString *path)
{
	return [NSString stringWithFormat:
		@"ObjC.import('Foundation');\n"
		@"$('%@').writeToFileAtomicallyEncodingError('%@', true, $.NSUTF8StringEncoding, null);",
		value, path];
}

// Payload shape Stream Deck sends with willAppear.
static NSDictionary * AppearPayload(NSDictionary *settings)
{
	return @{
		@"settings": settings,
		@"coordinates": @{@"column": @0, @"row": @0},
		@"isInMultiAction": @NO,
	};
}

static void Appear(MyStreamDeckPlugin *plugin, NSString *context, NSDictionary *settings)
{
	[plugin willAppearForAction:kAction withContext:context withPayload:AppearPayload(settings) forDevice:kDevice];
}

static void Press(MyStreamDeckPlugin *plugin, NSString *context)
{
	NSDictionary *payload = @{@"settings": @{}, @"coordinates": @{@"column": @0, @"row": @0}};
	[plugin keyDownForAction:kAction withContext:context withPayload:payload forDevice:kDevice];
	[plugin keyUpForAction:kAction withContext:context withPayload:payload forDevice:kDevice];
}


// MARK: - Tests

static void testRunsAppleScriptOnKeyDown(void)
{
	MyStreamDeckPlugin *plugin = [[MyStreamDeckPlugin alloc] init];
	NSString *marker = TempMarkerPath();

	Appear(plugin, @"ctx", @{@"language": @"AppleScript", @"scriptText": AppleScriptWriting(@"applescript", marker)});
	CHECK(ReadMarker(marker) == nil, @"script must not run on willAppear");

	Press(plugin, @"ctx");
	CHECK([ReadMarker(marker) isEqualToString:@"applescript"], @"marker was %@", ReadMarker(marker));
}

static void testRunsJavaScriptOnKeyDown(void)
{
	MyStreamDeckPlugin *plugin = [[MyStreamDeckPlugin alloc] init];
	NSString *marker = TempMarkerPath();

	Appear(plugin, @"ctx", @{@"language": @"JavaScript", @"scriptText": JXAWriting(@"jxa", marker)});
	Press(plugin, @"ctx");

	CHECK([ReadMarker(marker) isEqualToString:@"jxa"], @"marker was %@", ReadMarker(marker));
}

static void testEachKeyRunsItsOwnScript(void)
{
	MyStreamDeckPlugin *plugin = [[MyStreamDeckPlugin alloc] init];
	NSString *markerA = TempMarkerPath();
	NSString *markerB = TempMarkerPath();

	Appear(plugin, @"key-a", @{@"language": @"AppleScript", @"scriptText": AppleScriptWriting(@"a", markerA)});
	Appear(plugin, @"key-b", @{@"language": @"JavaScript", @"scriptText": JXAWriting(@"b", markerB)});

	Press(plugin, @"key-b");
	CHECK(ReadMarker(markerA) == nil, @"pressing key B ran key A's script");
	CHECK([ReadMarker(markerB) isEqualToString:@"b"], @"key B marker was %@", ReadMarker(markerB));

	Press(plugin, @"key-a");
	CHECK([ReadMarker(markerA) isEqualToString:@"a"], @"key A marker was %@", ReadMarker(markerA));
}

static void testReappearingReplacesSettings(void)
{
	// Property Inspector edits reach the plugin when the key appears again.
	MyStreamDeckPlugin *plugin = [[MyStreamDeckPlugin alloc] init];
	NSString *marker = TempMarkerPath();

	Appear(plugin, @"ctx", @{@"language": @"AppleScript", @"scriptText": AppleScriptWriting(@"old", marker)});
	[plugin willDisappearForAction:kAction withContext:@"ctx" withPayload:AppearPayload(@{}) forDevice:kDevice];
	Appear(plugin, @"ctx", @{@"language": @"JavaScript", @"scriptText": JXAWriting(@"new", marker)});

	Press(plugin, @"ctx");
	CHECK([ReadMarker(marker) isEqualToString:@"new"], @"marker was %@", ReadMarker(marker));
}

static void testKeyDownForUnknownContextDoesNothing(void)
{
	MyStreamDeckPlugin *plugin = [[MyStreamDeckPlugin alloc] init];

	// Before any willAppear, and for a context that never appeared.
	Press(plugin, @"never-appeared");
	Appear(plugin, @"ctx", @{@"language": @"AppleScript", @"scriptText": @"return 1"});
	Press(plugin, @"other");
}

static void testKeyWithoutScriptDoesNothing(void)
{
	// A freshly dropped key has empty settings until the Property Inspector saves.
	MyStreamDeckPlugin *plugin = [[MyStreamDeckPlugin alloc] init];

	Appear(plugin, @"empty", @{});
	Press(plugin, @"empty");

	Appear(plugin, @"language-only", @{@"language": @"JavaScript"});
	Press(plugin, @"language-only");
}

static void testFailingScriptDoesNotStopLaterPresses(void)
{
	MyStreamDeckPlugin *plugin = [[MyStreamDeckPlugin alloc] init];
	NSString *marker = TempMarkerPath();

	Appear(plugin, @"broken-as", @{@"language": @"AppleScript", @"scriptText": @"this is not applescript ((("});
	Appear(plugin, @"throws-js", @{@"language": @"JavaScript", @"scriptText": @"throw new Error('boom')"});
	Appear(plugin, @"ok", @{@"language": @"AppleScript", @"scriptText": AppleScriptWriting(@"ok", marker)});

	Press(plugin, @"broken-as");
	Press(plugin, @"throws-js");
	Press(plugin, @"ok");

	CHECK([ReadMarker(marker) isEqualToString:@"ok"], @"marker was %@", ReadMarker(marker));
}


// MARK: - Runner

typedef void (*TestFn)(void);

int main(int argc, const char * argv[])
{
	@autoreleasepool
	{
		struct { const char *name; TestFn fn; } tests[] = {
			{"testRunsAppleScriptOnKeyDown", testRunsAppleScriptOnKeyDown},
			{"testRunsJavaScriptOnKeyDown", testRunsJavaScriptOnKeyDown},
			{"testEachKeyRunsItsOwnScript", testEachKeyRunsItsOwnScript},
			{"testReappearingReplacesSettings", testReappearingReplacesSettings},
			{"testKeyDownForUnknownContextDoesNothing", testKeyDownForUnknownContextDoesNothing},
			{"testKeyWithoutScriptDoesNothing", testKeyWithoutScriptDoesNothing},
			{"testFailingScriptDoesNotStopLaterPresses", testFailingScriptDoesNotStopLaterPresses},
		};

		for(size_t i = 0; i < sizeof(tests) / sizeof(tests[0]); i++)
		{
			@autoreleasepool
			{
				sCurrentTest = @(tests[i].name);
				int failuresBefore = sFailures;
				sTests++;
				@try
				{
					tests[i].fn();
				}
				@catch(NSException *exception)
				{
					sFailures++;
					fprintf(stderr, "  FAIL %s: uncaught %s: %s\n", tests[i].name,
						exception.name.UTF8String, exception.reason.UTF8String);
				}
				printf("%s %s\n", sFailures == failuresBefore ? "ok  " : "FAIL", tests[i].name);
			}
		}

		printf("\n%d tests, %d failures\n", sTests, sFailures);
	}
	return sFailures == 0 ? 0 : 1;
}
