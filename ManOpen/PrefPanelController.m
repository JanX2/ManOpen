/* PrefPanelController.m created by lindberg on Fri 08-Oct-1999 */

#import "PrefPanelController.h"
#import <stdlib.h> //for NULL
#import <Foundation/NSUserDefaults.h>
#import <Foundation/NSPathUtilities.h>
#import <Foundation/NSData.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSEnumerator.h>
#import <Foundation/NSArchiver.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSFileManager.h>
#import <AppKit/NSBox.h>
#import <AppKit/NSTableView.h>
#import <AppKit/NSTextField.h>
#import <AppKit/NSButton.h>
#import <AppKit/NSOpenPanel.h>
#import <AppKit/NSColor.h>
#import <AppKit/NSColorWell.h>
#import <AppKit/NSFont.h>
#import <AppKit/NSFontManager.h>
#import <AppKit/NSFontPanel.h>
#import <AppKit/NSPopUpButton.h>
#import "ManDocumentController.h"

static NSColor *ColorForKey(NSString *key)
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSData         *colorData = [defaults objectForKey:key];

    if (colorData == nil || ![colorData isKindOfClass:[NSData class]]) return nil;
    return [NSUnarchiver unarchiveObjectWithData:colorData];
}

NSColor *ManBackgroundColor()
{
    NSColor *color = ColorForKey(@"ManBackgroundColor");
    if (color == nil) color = ColorForKey(@"BackgroundColor"); // historical
    if (color == nil) color = [NSColor textBackgroundColor];
    return color;
}

NSColor *ManTextColor()
{
    NSColor *color = ColorForKey(@"ManTextColor");
    if (color == nil) color = ColorForKey(@"TextColor"); // historical
    if (color == nil) color = [NSColor textColor];
    return color;
}

NSColor *ManLinkColor()
{
    NSColor *color = ColorForKey(@"ManLinkColor");
    if (color == nil) color = ColorForKey(@"LinkColor"); // historical
    if (color == nil)
    color = [NSColor colorWithDeviceRed:0.1 green:0.1 blue:1.0 alpha:1.0];
    return color;
}

NSFont *ManFont()
{
    NSString *fontString = [[NSUserDefaults standardUserDefaults] stringForKey:@"ManFont"];

    if (fontString)
    {
        NSRange spaceRange = [fontString rangeOfString:@" "];
        if (spaceRange.length > 0)
        {
            float size = [[fontString substringToIndex:spaceRange.location] floatValue];
            NSString *name = [fontString substringFromIndex:NSMaxRange(spaceRange)];
            NSFont *font = [NSFont fontWithName:name size:size];
            if (font != nil) return font;
        }
    }

    return [NSFont userFixedPitchFontOfSize:12.0]; // Monaco
}

NSString *ManPath()
{
    return [[NSUserDefaults standardUserDefaults] stringForKey:@"ManPath"];
}

void RegisterManDefaults()
{
    NSFileManager *manager = [NSFileManager defaultManager];
    NSDictionary *defaults;
#ifdef OPENSTEP
    NSString *nroff   = @"tbl '%@' | nroff -man";
    NSString *manpath = @"/usr/local/man:/usr/man";
#else
    NSString *nroff   = @"nroff -mandoc '%@'";
    NSString *manpath = @"/usr/local/man:/usr/share/man";
#endif

    if ([manager fileExistsAtPath:@"/sw/share/man"])
        manpath = [@"/sw/share/man:" stringByAppendingString:manpath];
    if ([manager fileExistsAtPath:@"/usr/X11R6/man"])
        manpath = [manpath stringByAppendingString:@":/usr/X11R6/man"];

    defaults = [NSDictionary dictionaryWithObjectsAndKeys:
        @"NO",          @"QuitWhenLastClosed",
        @"NO",          @"UseItalics",
        @"YES",         @"UseBold",
        nroff,          @"NroffCommand",
        manpath,        @"ManPath",
        @"NO",          @"KeepPanelsOpen",
        nil];

    [[NSUserDefaults standardUserDefaults] registerDefaults:defaults];
}


@interface PrefPanelController (DefaultManAppPrivate)
- (void)setUpDefaultManViewerApp;
@end

@implementation PrefPanelController

+ (id)allocWithZone:(NSZone *)aZone
{
    return [self sharedInstance];
}

+ (id)sharedInstance
{
    static id instance = nil;
    if (instance == nil)
        instance = [[super allocWithZone:NULL] init];
    return instance;
}

- (id)init
{
    self = [super initWithWindowNibName:@"PrefPanel"];
    [self setWindowFrameAutosaveName:@"Preferences"];
    [self setShouldCascadeWindows:NO];
    manPathArray = [[NSMutableArray alloc] init];

    [[NSFontManager sharedFontManager] setDelegate:self];

    return self;
}

- (void)dealloc
{
    [generalView release];
    [appearanceView release];
    [defaultAppView release];
    [manPathArray release];
    [super dealloc];
}

- (void)windowDidLoad
{
    [super windowDidLoad];

    [movePathUpButton setBezelStyle:NSShadowlessSquareBezelStyle];
    [movePathDownButton setBezelStyle:NSShadowlessSquareBezelStyle];

    generalView = [[generalPaneBox contentView] retain];
    appearanceView = [[appearancePaneBox contentView] retain];
    defaultAppView = [[defaultAppPaneBox contentView] retain];

    [manPathTableView sizeLastColumnToFit];
    [self revertFromDefaults:nil];
}

- (void)setFontFieldToFont:(NSFont *)font
{
    if (!font) return;
    [fontField setFont:font];
    [fontField setStringValue:
        [NSString stringWithFormat:@"%@ %.1f", [font familyName], [font pointSize]]];
}

- (IBAction)switchPrefPane:(id)sender
{
    switch ([sender selectedTag])
    {
        case 0: [generalPaneBox setContentView:generalView]; break;
        case 1: [generalPaneBox setContentView:appearanceView]; break;
        case 2: [self setUpDefaultManViewerApp]; [generalPaneBox setContentView:defaultAppView]; break;
    }
}

- (IBAction)revertFromDefaults:(id)sender
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSEnumerator *manPathEnum;
    NSString *path;

    [lastClosedSwitch setState:[defaults boolForKey:@"QuitWhenLastClosed"]];
    [useItalicsSwitch setState:[defaults boolForKey:@"UseItalics"]];
    [useBoldSwitch    setState:[defaults boolForKey:@"UseBold"]];
    [keepOpenSwitch   setState:[defaults boolForKey:@"KeepPanelsOpen"]];
    [openOnStartupSwitch setState:[defaults boolForKey:@"OpenPanelOnStartup"]];
    [openOnNoWindowsSwitch setState:[defaults boolForKey:@"OpenPanelWhenNoWindows"]];
    [nroffCommandField setStringValue:[defaults stringForKey:@"NroffCommand"]];
    [self setFontFieldToFont:ManFont()];

    [backgroundColorWell setColor:ManBackgroundColor()];
    [textColorWell setColor:ManTextColor()];
    [linkColorWell setColor:ManLinkColor()];

    manPathEnum = [[ManPath() componentsSeparatedByString:@":"] objectEnumerator];
    while (path = [manPathEnum nextObject])
    {
        [manPathArray addObject:[path stringByAbbreviatingWithTildeInPath]];
    }

    [manPathTableView reloadData];
}

- (IBAction)saveToDefaults:(id)sender
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    int i, count = [manPathArray count];
    NSMutableArray *rawPathArray = [NSMutableArray arrayWithCapacity:count];

    [defaults setBool:[lastClosedSwitch state]      forKey:@"QuitWhenLastClosed"];
    [defaults setBool:[useItalicsSwitch state]      forKey:@"UseItalics"];
    [defaults setBool:[useBoldSwitch state]         forKey:@"UseBold"];
    [defaults setBool:[keepOpenSwitch state]        forKey:@"KeepPanelsOpen"];
    [defaults setBool:[openOnStartupSwitch state]   forKey:@"OpenPanelOnStartup"];
    [defaults setBool:[openOnNoWindowsSwitch state] forKey:@"OpenPanelWhenNoWindows"];
    [defaults setObject:[nroffCommandField stringValue] forKey:@"NroffCommand"];

    for (i=0; i<count; i++)
    {
        NSString *path = [manPathArray objectAtIndex:i];
        [rawPathArray addObject:[path stringByExpandingTildeInPath]];
    }

    [defaults setObject:[rawPathArray componentsJoinedByString:@":"] forKey:@"ManPath"];
}

- (IBAction)setColor:(id)sender
{
    NSString *key = nil;
    NSData   *colorData;

    if (sender == backgroundColorWell) key = @"ManBackgroundColor";
    if (sender == textColorWell)       key = @"ManTextColor";
    if (sender == linkColorWell)       key = @"ManLinkColor";

    colorData = [NSArchiver archivedDataWithRootObject:[sender color]];

    [[NSUserDefaults standardUserDefaults] setObject:colorData forKey:key];
}

- (IBAction)openFontPanel:(id)sender
{
    [[self window] makeFirstResponder:nil];     // Make sure *we* get the changeFont: call
    [[NSFontManager sharedFontManager] setSelectedFont:[fontField font] isMultiple:NO];
    [[NSFontPanel sharedFontPanel] orderFront:self];   // Leave us as key
}

/* We only allow fixed-pitch fonts.  Does not seem to be called on OSX. */
- (BOOL)fontManager:(id)sender willIncludeFont:(NSString *)fontName
{
    return [sender fontNamed:fontName hasTraits:NSFixedPitchFontMask];
}

- (void)changeFont:(id)sender
{
    NSFont *font = [fontField font];
    NSString *fontString;

    font = [sender convertFont:font];
    [self setFontFieldToFont:font];
    fontString = [NSString stringWithFormat:@"%f %@", [font pointSize], [font fontName]];
    [[NSUserDefaults standardUserDefaults] setObject:fontString forKey:@"ManFont"];
}

- (IBAction)addPath:(id)sender
{
    NSOpenPanel *panel = [NSOpenPanel openPanel];

    [panel setAllowsMultipleSelection:NO];
    [panel setCanChooseDirectories:YES];
    [panel setCanChooseFiles:NO];

    if ([panel runModal])
    {
        NSString *path = [[panel filename] stringByAbbreviatingWithTildeInPath];
        if (![manPathArray containsObject:path])
        {
            int insertionIndex = [manPathTableView selectedRow];

            if (insertionIndex < 0)
                insertionIndex = [manPathArray count]; //add it on the end

            [manPathArray insertObject:path atIndex:insertionIndex];
            [manPathTableView reloadData];
            [self saveToDefaults:nil];
        }
    }
}

- (IBAction)removePath:(id)sender
{
    int selectedIndex = [manPathTableView selectedRow];

    if (selectedIndex >= 0)
    {
        [manPathArray removeObjectAtIndex:selectedIndex];
        [manPathTableView reloadData];
        [self saveToDefaults:nil];
    }
}

- (void)moveSelectedPathBy:(int)indexOffset
{
    int selectedRow = [manPathTableView selectedRow];
    int targetRow = selectedRow + indexOffset;
    
    if (selectedRow >= 0 && targetRow >= 0 && targetRow < [manPathArray count])
    {
        id path = [[manPathArray objectAtIndex:selectedRow] retain];
        [manPathArray removeObjectAtIndex:selectedRow];
        [manPathArray insertObject:path atIndex:targetRow];
        [path release];
        [manPathTableView reloadData];
		[manPathTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:targetRow] byExtendingSelection:NO];
        [self saveToDefaults:nil];
    }
}
- (IBAction)movePathUp:(id)sender
{
    [self moveSelectedPathBy:-1];
}

- (IBAction)movePathDown:(id)sender
{
    [self moveSelectedPathBy:1];
}

/** NSTableView data source **/

- (int)numberOfRowsInTableView:(NSTableView *)tableView
{
    return [manPathArray count];
}

- (id)tableView:(NSTableView *)tableView
   objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)row
{
    return [manPathArray objectAtIndex:row];
}

- (void)tableView:(NSTableView *)tableView setObjectValue:(id)object
   forTableColumn:(NSTableColumn *)tableColumn row:(int)row
{
}

@end

/* 
 * Add a preference pane so that the user can set the default x-man-page
 * application. Under Panther (10.3), Terminal.app supports this, so we should
 * too.  Unfortunately the LaunchServices functions to do this are private
 * and undocumented.
 */
#import <ApplicationServices/ApplicationServices.h>
#import <Foundation/NSURL.h>
#import <Foundation/NSBundle.h>
#import <AppKit/NSOpenPanel.h>
#import <AppKit/NSWorkspace.h>
#import <AppKit/NSImage.h>

static NSString *NiceNameForApp(NSString *bundleID)
{
    NSBundle *appBundle = [NSBundle bundleWithIdentifier:bundleID];
    NSDictionary *infoDict = [appBundle localizedInfoDictionary];
    NSString *appVersion = [infoDict objectForKey:@"CFBundleShortVersionString"];
    NSString *niceName = [infoDict objectForKey:@"CFBundleDisplayName"];

    if (appVersion != nil)
        niceName = [NSString stringWithFormat:@"%@ (%@)", niceName, appVersion];

    return niceName;
}

#define URL_SCHEME @"x-man-page"
#define URL_SCHEME_PREFIX URL_SCHEME @":"

static NSMutableArray *availableApps;
static NSMutableArray *appNames;
static NSString *currentApp = nil;


@implementation PrefPanelController (DefaultManApp)

- (void)setAppPopupToCurrent
{
    int currIndex = [availableApps indexOfObject:currentApp];

    if (currIndex == NSNotFound) {
        currIndex = 0;
    }

    if (currIndex < [appPopup numberOfItems])
        [appPopup selectItemAtIndex:currIndex];
}

- (void)resetAppPopup
{
    NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
    int i;

    [appPopup removeAllItems];
    [appPopup setImage:nil];

    for (i=0; i<[availableApps count]; i++)
    {
        NSString *currPath = [[availableApps objectAtIndex:i] path];
        NSImage *image = [[workspace iconForFile:currPath] copy];
        NSString *niceName = [appNames objectAtIndex:i];
        NSString *displayName = niceName;
        int num = 2;

        while ([appPopup indexOfItemWithTitle:displayName] >= 0) {
            displayName = [NSString stringWithFormat:@"%@[%d]", niceName, num++];
        }
        [appPopup addItemWithTitle:displayName];

        [image setScalesWhenResized:YES];
        [image setSize:NSMakeSize(16, 16)];
        [[appPopup itemAtIndex:i] setImage:image];
        [image release];
    }

    if ([availableApps count] > 0)
        [[appPopup menu] addItem:[NSMenuItem separatorItem]];
    [appPopup addItemWithTitle:@"Select... "];
    [self setAppPopupToCurrent];
}

- (void)resetCurrentApp
{
    NSString *currentBundleID = nil;

    currentBundleID = (NSString *)LSCopyDefaultHandlerForURLScheme((CFStringRef)URL_SCHEME);
	if (currentBundleID != nil)
    {
        BOOL resetPopup = (currentApp == nil); //first time

        [currentApp release];
        currentApp = [currentBundleID retain];
        [currentBundleID release];

        if ([availableApps indexOfObject:currentApp] == NSNotFound)
        {
            [availableApps addObject:currentApp];
            [appNames addObject:NiceNameForApp(currentApp)];
            resetPopup = YES;
        }
        if (resetPopup)
            [self resetAppPopup];
        else
            [self setAppPopupToCurrent];
    }
}

- (void)setManPageViewer:(NSString *)app
{
    int error;
    if ((error = LSSetDefaultHandlerForURLScheme((CFStringRef)URL_SCHEME, (CFStringRef)app)) != 0)
        NSLog(@"Could not set default " URL_SCHEME_PREFIX @" app: Launch Services error %d", error);

    [self resetCurrentApp];
}

- (void)setUpDefaultManViewerApp
{
    if (availableApps == nil)
    {
        NSURL *dummyURL = [NSURL URLWithString:URL_SCHEME_PREFIX];
        NSArray *apps = nil;
        availableApps = [[NSMutableArray alloc] init];
        appNames = [[NSMutableArray alloc] init];

		apps = (NSArray *)LSCopyApplicationURLsForURL((CFURLRef)dummyURL, kLSRolesViewer);
		
        if (apps != nil)
        {
            [availableApps setArray:apps];
            [apps release];

            [appNames removeAllObjects];
            for (NSString *thisApp in availableApps) {
                [appNames addObject:NiceNameForApp(thisApp)];
			}
        }
    }

    [self resetCurrentApp];
}

- (IBAction)chooseNewApp:(id)sender
{
    int choice = [appPopup indexOfSelectedItem];

    if (choice >= 0 && choice < [availableApps count]) {
        NSString *appID = [availableApps objectAtIndex:choice];
        if (appID != currentApp)
            [self setManPageViewer:appID];
    }
    else {
        NSOpenPanel *panel = [NSOpenPanel openPanel];
        [panel setTreatsFilePackagesAsDirectories:NO];
        [panel setAllowsMultipleSelection:NO];
        [panel setResolvesAliases:YES];
        [panel setCanChooseFiles:YES];
        [panel beginSheetForDirectory:nil file:nil types:[NSArray arrayWithObject:@"app"]
                       modalForWindow:[appPopup window] modalDelegate:self
                       didEndSelector:@selector(panelDidEnd:code:context:) contextInfo:NULL];
    }
}

- (void)panelDidEnd:(NSOpenPanel *)panel code:(int)returnCode context:(void *)context
{
    if (returnCode == NSOKButton) {
		NSBundle *appBundle = [NSBundle bundleWithPath:[[[panel URLs] objectAtIndex:0] path]];

        NSString *appID = [appBundle bundleIdentifier];
        if (appID != nil)
            [self setManPageViewer:appID];
    }
    [self setAppPopupToCurrent];
}
@end

