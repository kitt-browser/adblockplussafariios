//
//  ActionViewController.m
//  AdblockPlusSafariActionExtension
//
//  Created by Jan Dědeček on 21/10/15.
//  Copyright © 2015 Eyeo GmbH. All rights reserved.
//

#import "ActionViewController.h"
#import "AdblockPlusShared.h"
#import "NSString+AdblockPlus.h"
#import "NSAttributedString+MarkdownRenderer.h"

#import <MobileCoreServices/MobileCoreServices.h>

@import SafariServices;

@interface ActionViewController ()

@property(strong, nonatomic) AdblockPlusShared *adblockPlus;
@property(strong, nonatomic) NSString *website;

@property(strong, nonatomic) IBOutlet UILabel *adblockPlusLabel;
@property(strong, nonatomic) IBOutlet UILabel *whitelistedWebsiteLabel;
@property(strong, nonatomic) IBOutlet UILabel *descriptionLabel;

@end

@implementation ActionViewController

- (void)viewDidLoad
{
  self.view.hidden = YES;
  [super viewDidLoad];

  CGFloat fontSize = self.adblockPlusLabel.font.pointSize;
  UIFont *font = [UIFont fontWithName:@"SourceSansPro-Bold" size:fontSize];
  if (font) {
    self.adblockPlusLabel.attributedText = [self.adblockPlusLabel.attributedText markdownSpanMarkerChar:@"*"
                                                                                           renderAsFont:font];
  }

  fontSize = self.descriptionLabel.font.pointSize;
  font = [UIFont fontWithName:@"SourceSansPro-Light" size:fontSize];
  if (font) {
    NSMutableAttributedString *string = [self.descriptionLabel.attributedText mutableCopy];
    [string addAttribute:NSFontAttributeName value:font range:NSMakeRange(0, string.length)];
    self.descriptionLabel.attributedText = string;
  }

  self.adblockPlus = [[AdblockPlusShared alloc] init];

  for (NSExtensionItem *item in self.extensionContext.inputItems) {
    for (NSItemProvider *itemProvider in item.attachments) {
      __weak typeof(self) wSelf = self;
      [itemProvider loadItemForTypeIdentifier:kUTTypePropertyList options:nil completionHandler:^(NSDictionary *item, NSError *error) {
        NSDictionary *results = (NSDictionary *)item;
        NSString *baseURI = [[results objectForKey:NSExtensionJavaScriptPreprocessingResultsKey] objectForKey:@"baseURI"];
        wSelf.website = baseURI;
        wSelf.whitelistedWebsiteLabel.text = [baseURI whitelistedHostname];
      }];
    }
  }
}

-(void)viewDidAppear:(BOOL)animated
{
  [super viewDidAppear:animated];

  [UIView transitionWithView:self.view
                    duration:0.4
                     options:UIViewAnimationOptionTransitionCrossDissolve|UIViewAnimationOptionShowHideTransitionViews
                  animations:^{ self.view.hidden = NO; }
                  completion:nil];
}

#pragma mark - Action

-(IBAction)onEditButtonTouched:(id)sender
{
  if (self.website.length == 0) {
    return;
  }

  NSURLComponents *components = [[NSURLComponents alloc] init];
  components.scheme = @"adblockplussafari";
  components.host = @"x-callback-url";
  components.path = @"/whitelist";
  components.query = [@"website=" stringByAppendingString:[self.website whitelistedHostname]];

  UIResponder *responder = self;
  while ((responder = [responder nextResponder]) != nil) {
    if([responder respondsToSelector:@selector(openURL:)] == YES) {
      NSURL *url = components.URL;
      [responder performSelector:@selector(openURL:) withObject:url];
      break;
    }
  }

  [UIView transitionWithView:self.view
                    duration:0.4
                     options:UIViewAnimationOptionTransitionCrossDissolve|UIViewAnimationOptionShowHideTransitionViews
                  animations:^{ self.view.hidden = YES; }
                  completion:^(BOOL finished){
                    [self.extensionContext completeRequestReturningItems:nil
                                                       completionHandler:nil];
                  }];
}

-(IBAction)onConfirmButtonTouched:(id)sender
{
  void(^completeAndExit)() = ^() {
    [self.extensionContext completeRequestReturningItems:nil
                                       completionHandler:nil];

    // Session must be created with new identifier, see Apple documentation:
    // https://developer.apple.com/library/prerelease/ios/documentation/General/Conceptual/ExtensibilityPG/ExtensionScenarios.html
    // Section - Performing Uploads and Downloads
    // Because only one process can use a background session at a time,
    // you need to create a different background session for the containing app and each of its app extensions.
    // (Each background session should have a unique identifier.)
    NSString *identifier = [self.adblockPlus generateBackgroundNotificationSessionConfigurationIdentifier];

    NSURLSession *session = [self.adblockPlus backgroundNotificationSessionWithIdentifier:identifier delegate:nil];

    // Fake URL, request will definitely fail, hopefully the invalid url will be denied by iOS itself.
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://localhost/invalidimage-%d.png", (int)[NSDate timeIntervalSinceReferenceDate]]];

    // Start download request with fake URL
    NSURLSessionDownloadTask *task = [session downloadTaskWithURL:url];
    [task resume];

    [session finishTasksAndInvalidate];

    // Let the host application to handle the result of download task
    exit(0);
  };

  [self.adblockPlus whitelistWebsite:self.website index:nil];

  [UIView transitionWithView:self.view
                    duration:0.4
                     options:UIViewAnimationOptionTransitionCrossDissolve|UIViewAnimationOptionShowHideTransitionViews
                  animations:^{ self.view.hidden = YES; }
                  completion:^(BOOL finished) {
                    dispatch_async(dispatch_get_main_queue(), completeAndExit);
                  }];
}


@end
