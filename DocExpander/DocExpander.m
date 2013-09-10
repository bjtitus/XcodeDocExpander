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
           
            
            NSString *methodRegEx = @"[-+]\\s+\\(\\s*([a-zA-Z0-9_\\s\\*$]*)\\s*\\)(.*)";
            
            NSRegularExpression *methodRegularExpression = [NSRegularExpression regularExpressionWithPattern:methodRegEx options:0 error:NULL];
            
           
            __block NSMutableString * commentString = [NSMutableString string];
            [commentString appendString:@"\n * [Method Description]"];
            
            __block BOOL isMethod = NO;
            
            __block BOOL isFinished = NO;
            
            int numLines = 0;
            
            __block NSString *returnType = nil;
            
            // Check the next line for a function and parse it to get our template
            NSRange nextLineRange = [text lineRangeForRange:NSMakeRange(lineRange.location+lineRange.length, 1)];

            NSString *nextLineText = [text substringWithRange:nextLineRange];
            
            [methodRegularExpression enumerateMatchesInString:nextLineText options:0 range:NSMakeRange(0, nextLineText.length) usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
                if(result.numberOfRanges == 3)
               {
                   isMethod = YES;
                   
                   NSString *remainingContent = nil;
                   
                   if(numLines == 0)
                   {
                       // 0 = Full Match
                       // 1 = return type
                       // 2 = remaining content
                       returnType = [nextLineText substringWithRange:[result rangeAtIndex:1]];
                       remainingContent = [nextLineText substringWithRange:[result rangeAtIndex:2]];
                   }
                   
                   [commentString appendString:[self scanText:remainingContent finished:&isFinished]];
                   
               }
                
            }];
            
            while(!isFinished)
            {
                nextLineRange = [text lineRangeForRange:NSMakeRange(nextLineRange.location+nextLineRange.length, 1)];
                
                nextLineText = [text substringWithRange:nextLineRange];
                
                [commentString appendString:[self scanText:nextLineText finished:&isFinished]];
            }
            
            if(![returnType isEqualToString:@"void"])
            {
                [commentString appendString:[NSString stringWithFormat:@"\n * @return [Description]"]];
            }
            
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

- (NSString *)scanText:(NSString *)text finished:(BOOL *)finished {
    
    NSMutableString *commentString = [[NSMutableString alloc] init];
    NSString *lineTemplate = @"\n * @param %@ [Description]";
    
    int num = 0;
    int currentGroup = 0;
    
    NSCharacterSet *argumentDescriptorSeparator = [NSCharacterSet characterSetWithCharactersInString:@":"];
    NSCharacterSet *argumentTypeOpener = [NSCharacterSet characterSetWithCharactersInString:@"("];
    NSCharacterSet *argumentTypeCloser = [NSCharacterSet characterSetWithCharactersInString:@")"];
    NSCharacterSet *methodEnding = [NSCharacterSet characterSetWithCharactersInString:@"; "];
    
    NSScanner *scanner = [NSScanner scannerWithString:text];
    
    while(![scanner isAtEnd])
    {
        NSString *currentItem = nil;
        
        if(floor(num/3) > currentGroup)
        {
            currentGroup++;
        }
        
        int itemNum = num - (currentGroup*3);
        

        if(itemNum == 0)
        {
            if([scanner.string rangeOfCharacterFromSet:argumentDescriptorSeparator].location != NSNotFound)
            {
                [scanner scanUpToCharactersFromSet:argumentDescriptorSeparator intoString:&currentItem];
            }
            else
            {
                [scanner scanUpToCharactersFromSet:methodEnding intoString:&currentItem];
            }
        }
        else if(itemNum == 1)
        {
            [scanner scanCharactersFromSet:argumentTypeOpener intoString:nil];
            [scanner scanUpToCharactersFromSet:argumentTypeCloser intoString:&currentItem];
        }
        else
        {
            [scanner scanCharactersFromSet:argumentTypeCloser intoString:nil];
            [scanner scanUpToCharactersFromSet:methodEnding intoString:&currentItem];
        }
        
        if([scanner scanCharactersFromSet:methodEnding intoString:nil])
        {
            *finished = YES;
        }
        
        //itemNum0 is the part of the method name that corresponds to that argument
        //itemNum1 is the type for the argument
        
        // The internal argument name
        if(itemNum == 2)
        {
            [commentString appendString:[NSString stringWithFormat:lineTemplate, [currentItem stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]]];
        }
        
        num++;
    }
    
    return commentString;
}

@end
