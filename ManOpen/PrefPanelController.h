/* PrefPanelController.h created by lindberg on Fri 08-Oct-1999 */

#import <AppKit/AppKit.h>

@class NSMutableArray;
@class NSFont, NSColor;
@class NSTableView, NSTextField, NSButton, NSPopUpButton, NSColorWell, NSView, NSBox;

@interface PrefPanelController : NSWindowController
{
    NSMutableArray *manPathArray;
    NSView *generalView;
    NSView *appearanceView;
    NSView *defaultAppView;
    IBOutlet NSPopUpButton *panePopup;
    IBOutlet NSTableView *manPathTableView;
    IBOutlet NSTextField *nroffCommandField;
    IBOutlet NSTextField *fontField;
    IBOutlet NSButtonCell    *useItalicsSwitch;
    IBOutlet NSButtonCell    *useBoldSwitch;
    IBOutlet NSButtonCell    *lastClosedSwitch;
    IBOutlet NSButtonCell    *keepOpenSwitch;
    IBOutlet NSButtonCell    *openOnStartupSwitch;
    IBOutlet NSButtonCell    *openOnNoWindowsSwitch;
    IBOutlet NSButton    *movePathUpButton;
    IBOutlet NSButton    *movePathDownButton;
    IBOutlet NSColorWell *backgroundColorWell;
    IBOutlet NSColorWell *textColorWell;
    IBOutlet NSColorWell *linkColorWell;
    IBOutlet NSPopUpButton *appPopup;
    IBOutlet NSBox       *generalPaneBox;
    IBOutlet NSBox       *appearancePaneBox;
    IBOutlet NSBox       *defaultAppPaneBox;
    
}

+ (id)sharedInstance;

- (IBAction)switchPrefPane:(id)sender;

- (IBAction)revertFromDefaults:(id)sender;
- (IBAction)saveToDefaults:(id)sender;

- (IBAction)setColor:(id)sender;

- (IBAction)addPath:(id)sender;
- (IBAction)removePath:(id)sender;
- (IBAction)movePathUp:(id)sender;
- (IBAction)movePathDown:(id)sender;

- (IBAction)openFontPanel:(id)sender;

@end

@interface PrefPanelController (DefaultManApp)
- (IBAction)chooseNewApp:(id)sender;
@end

extern void RegisterManDefaults();
extern NSFont *ManFont();
extern NSString *ManPath();
extern NSColor *ManTextColor();
extern NSColor *ManLinkColor();
extern NSColor *ManBackgroundColor();
