//
//  DocExpander.h
//  DocExpander
//
//  Created by Brandon Titus on 3/19/13.
//  Copyright (c) 2013 Mercury. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <AppKit/AppKit.h>

@class IDEIndex;

@interface DocExpander : NSObject


@property (nonatomic, retain) NSTextView *textView;

+ (instancetype)sharedPlugin;
+ (void)pluginDidLoad:(NSBundle *)plugin;

@end
