//
//  WhitelistedWebsitesController.m
//  AdblockPlusSafari
//
//  Created by Jan Dědeček on 12/10/15.
//  Copyright © 2015 Eyeo GmbH. All rights reserved.
//

#import "WhitelistedWebsitesController.h"

const NSInteger TextFieldTag = 121212;

@interface WhitelistedWebsitesController ()<UITextFieldDelegate>

@property (nonatomic, strong) NSAttributedString *attributedPlaceholder;

@end

@implementation WhitelistedWebsitesController

- (void)awakeFromNib
{
  [super awakeFromNib];

  UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"AddingCell"];
  UITextField *textField = (UITextField *)[cell viewWithTag:TextFieldTag];
  NSString *placeholder = textField.placeholder;
  if (placeholder) {
    UIColor *color = [UIColor colorWithWhite:1.0 * 0xA1 / 0xFF alpha:1.0];
    self.attributedPlaceholder = [[NSAttributedString alloc] initWithString:placeholder attributes:@{NSForegroundColorAttributeName: color}];
  }
}

- (void)dealloc
{
  self.adblockPlus = nil;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
  if ([keyPath isEqualToString:NSStringFromSelector(@selector(whitelistedWebsites))]) {
    [self.tableView reloadData];
  } else {
    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
  }
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
  return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
  if (section == 0) {
    return 1;
  } else {
    return MAX(1, self.adblockPlus.whitelistedWebsites.count);
  }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
  if (section == 0) {
    return NSLocalizedString(@"ADD WEBSITE TO WHITELIST", @"Whitelisted Websites Controller");
  } else {
    return NSLocalizedString(@"YOUR WHITELIST", @"Whitelisted Websites Controller");
  }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
  UITableViewCell *cell;
  if (indexPath.section == 0) {
    cell = [tableView dequeueReusableCellWithIdentifier:@"AddingCell" forIndexPath:indexPath];
    UITextField *textField = (UITextField *)[cell viewWithTag:TextFieldTag];
    textField.attributedPlaceholder = self.attributedPlaceholder;
  } else if (self.adblockPlus.whitelistedWebsites.count == 0) {
    cell = [tableView dequeueReusableCellWithIdentifier:@"NoWebsiteCell" forIndexPath:indexPath];
  } else {
    cell = [tableView dequeueReusableCellWithIdentifier:@"WebsiteCell" forIndexPath:indexPath];
    cell.textLabel.text = self.adblockPlus.whitelistedWebsites[indexPath.row];

    UIButton *buttom = [UIButton buttonWithType:UIButtonTypeCustom];
    [buttom addTarget:self action:@selector(onTrashButtomTouched:) forControlEvents:UIControlEventTouchUpInside];
    [buttom setImage:[UIImage imageNamed:@"trash"] forState:UIControlStateNormal];
    buttom.imageEdgeInsets = UIEdgeInsetsMake(0, 30, 0, 0);
    buttom.bounds = CGRectMake(0, 0, 50, 44);

    cell.accessoryView = buttom;
  }
  return cell;
}

#pragma mark - UITextFieldDelegate

- (void)textFieldDidBeginEditing:(UITextField *)textField
{
  textField.attributedPlaceholder = nil;
}

- (void)textFieldDidEndEditing:(UITextField *)textField
{
  textField.attributedPlaceholder = self.attributedPlaceholder;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
  [textField resignFirstResponder];
  NSString *website = textField.text;
  textField.text = nil;
  [self whitelistWebsite:website];
  return NO;
}

#pragma makr - Action

- (IBAction)onAddWebsiteTouched:(UIButton *)sender
{
  id view = sender.superview;
  while (view != nil) {
    if ([view isKindOfClass:[UITableViewCell class]]) {
      UITextField *textField = (UITextField *)[view viewWithTag:TextFieldTag];
      NSString *website = textField.text;
      textField.text = nil;
      [textField resignFirstResponder];
      [self whitelistWebsite:website];
      return;
    }
    view = [view superview];
  }
}

- (void)onTrashButtomTouched:(UIButton *)sender
{
  id view = sender.superview;
  while (view != nil) {
    if ([view isKindOfClass:[UITableViewCell class]]) {
      NSIndexPath *indexPath = [self.tableView indexPathForCell:view];

      NSMutableArray *websites = [self.adblockPlus.whitelistedWebsites mutableCopy];
      [websites removeObjectAtIndex:indexPath.row];
      self.adblockPlus.whitelistedWebsites = websites;

      if (websites.count > 0) {
        [self.tableView deleteRowsAtIndexPaths:@[indexPath]
                              withRowAnimation:UITableViewRowAnimationFade];
      } else {
        [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:1]
                      withRowAnimation:UITableViewRowAnimationAutomatic];
      }

      return;
    }
    view = [view superview];
  }
}

#pragma mark - Properties

@dynamic whitelistedWebsite;

- (NSString *)whitelistedWebsite
{
  UITableViewCell *cell =  [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
  UITextField *textField = (UITextField *)[cell viewWithTag:TextFieldTag];
  return textField.text;
}

- (void)setWhitelistedWebsite:(NSString *)whitelistedWebsite
{
    UITableViewCell *cell =  [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
  UITextField *textField = (UITextField *)[cell viewWithTag:TextFieldTag];
  textField.text = whitelistedWebsite;
}

- (void)setAdblockPlus:(AdblockPlusExtras *)adblockPlus
{
  NSArray<NSString *> *keyPaths = @[NSStringFromSelector(@selector(whitelistedWebsites))];

  for (NSString *keyPath in keyPaths) {
    [_adblockPlus removeObserver:self
                      forKeyPath:keyPath];
  }
  _adblockPlus = adblockPlus;
  for (NSString *keyPath in keyPaths) {
    [_adblockPlus addObserver:self
                   forKeyPath:keyPath
                      options:NSKeyValueObservingOptionInitial|NSKeyValueObservingOptionNew
                      context:nil];
  }
}

#pragma mark - Private

- (void)whitelistWebsite:(NSString *)website
{
  NSInteger index;
  if ([self.adblockPlus whitelistWebsite:website index:&index]) {
    if (self.adblockPlus.whitelistedWebsites.count > 1) {
      [self.tableView insertRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:index inSection:1]]
                            withRowAnimation:UITableViewRowAnimationFade];
    } else {
      [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:1]
                    withRowAnimation:UITableViewRowAnimationAutomatic];
    }
  }
}

@end
