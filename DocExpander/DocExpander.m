//
//  DocExpander.m
//  DocExpander
//
//  Created by Brandon Titus on 3/19/13.
//  Copyright (c) 2013 Mercury. All rights reserved.
//

#import "DocExpander.h"

// Xcode Classes
//#import "IDEWorkspace.h"
//#import "IDEEditorDocument.h"

@interface DocExpander()
{
    BOOL replacing;
}
@end

@implementation DocExpander

static DocExpander *sharedPlugin = nil;

+ (instancetype)sharedPlugin
{
    return sharedPlugin;
}

+ (void)pluginDidLoad:(NSBundle *)plugin
{
	static dispatch_once_t onceToken;
    
	dispatch_once(&onceToken, ^{
		sharedPlugin = [[self alloc] init];
	});
}

- (id)init
{
    self = [super init];
    if (self) {
        // Register observer
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidFinishLaunching:) name:NSApplicationDidFinishLaunchingNotification object:nil];
    }
    return self;
}

- (void)dealloc
{
    [super dealloc];
}

#pragma mark - Setup

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSApplicationDidFinishLaunchingNotification object:nil];
    
    [self activate];
}


#pragma mark - Notification

- (void)activate
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(textDidChange:) name:NSTextDidChangeNotification object:nil];
    
}

- (void)deactivate
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSTextDidChangeNotification object:nil];
}

#pragma mark - Text View

- (void)textDidChange:(NSNotification *)notification
{
    if(!replacing)
    {
        if([[notification object] isKindOfClass:NSClassFromString(@"DVTSourceTextView")]) {
            NSTextView *textView = (NSTextView *)[notification object];
            self.textView = textView;
            
            [self replaceOurText:textView];
        }
    }
}

- (void)replaceOurText:(NSTextView *)textView
{
    NSArray *selectedRanges = textView.selectedRanges;
        
    if(selectedRanges.count > 0)
    {
        NSRange selectedRange = [selectedRanges[0] rangeValue];
        
        NSString *text = textView.textStorage.string;
        NSRange lineRange = [text lineRangeForRange:selectedRange];
        NSString *lineText = [text substringWithRange:lineRange];
        
        __block BOOL matched = NO;
        
        // Matches the top comment bracket
        NSString *regEx = @"/\\*{2,}\\n";
                
        __block NSRange entityRangeInLine;
        __block NSRange keyRangeInLine;
        
        NSRegularExpression *regularExpression = [NSRegularExpression regularExpressionWithPattern:regEx options:0 error:NULL];
                
        [regularExpression enumerateMatchesInString:lineText options:0 range:NSMakeRange(0, lineText.length) usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
            if(result.numberOfRanges == 1)
            {
                matched = YES;
                
                entityRangeInLine = [result rangeAtIndex:0];
                // This would match what we want to replace. In this case, a new line maybe?
                keyRangeInLine = [result rangeAtIndex:0];
            }
        }];
        
        if(matched) {
            // Check the next line for a function and parse it to get our template
            NSRange nextLineRange = [text lineRangeForRange:NSMakeRange(lineRange.location+lineRange.length, 1)];
            NSString *nextLineText = [text substringWithRange:nextLineRange];

            NSString *methodRegEx = @"[-+]\\s+\\(\\s*(.*)\\s*\\)\\s*([a-zA-Z_$][a-zA-Z0-9_$]*)(?::\\s*\\(\\s*(.*)\\s*\\)\\s*([a-zA-Z_$][a-zA-Z0-9_$]*))\\s*"; 
            
            NSRegularExpression *methodRegularExpression = [NSRegularExpression regularExpressionWithPattern:methodRegEx options:0 error:NULL];
            
            NSString *paramName = @"myParam";
            
            NSString *lineTemplate = @"\n * @param %@ [Description]";
           
            NSLog(@"Next line: %@", nextLineText);
            
            NSMutableString * commentString = [NSMutableString string];
            [commentString appendString:@"\n * [Method Description]"];
            
            __block BOOL isMethod = NO;
            
            [methodRegularExpression enumerateMatchesInString:nextLineText options:0 range:NSMakeRange(0, nextLineText.length) usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
                if(result.numberOfRanges >= 2)
               {
                   isMethod = YES;
                   
                   
                   // 0 = Full Match
                   // 1 = return type
                   // 2 = method name
                   NSString *returnType = [nextLineText substringWithRange:[result rangeAtIndex:1]];
                   NSString *methodName = [text substringWithRange:[result rangeAtIndex:2]];
                 
                   for(int i = 0; i< result.numberOfRanges; i++)
                   {
                       NSRange varRange = [result rangeAtIndex:i];
                       NSLog(@"Range: %li, %li", varRange.location, varRange.length);
                       if(varRange.location != NSNotFound)
                       {
                           NSString *paramName = [nextLineText substringWithRange:varRange];
                           NSLog(@"PARAM: %@", paramName);
                       }
                   }
                   
                   if(result.numberOfRanges > 3)
                   {
                       for(int i = 4; i < result.numberOfRanges; i = i+2)
                       {
                           NSRange nameRange = [result rangeAtIndex:i];
                           NSRange typeRange = [result rangeAtIndex:i-1];
                           if(nameRange.location != NSNotFound && typeRange.location != NSNotFound)
                           {
                               NSString *paramName = @"";
                               NSString *paramType = @"";
                               paramName = [nextLineText substringWithRange:nameRange];
                               paramType = [nextLineText substringWithRange:typeRange];
                               [commentString appendString:[NSString stringWithFormat:lineTemplate, paramName]];
                           }
                       }
                   }
                  
                   if(![returnType isEqualToString:@"void"])
                   {
                       [commentString appendString:[NSString stringWithFormat:@"\n * @return %@", returnType]];
                   }
               }
            }];
            
            if(isMethod)
            {
                [commentString appendString:@"\n **/"];
                
                
                replacing = YES;
                [self.textView insertText:commentString];
                replacing = NO;
            }
        }
    }
}

@end
