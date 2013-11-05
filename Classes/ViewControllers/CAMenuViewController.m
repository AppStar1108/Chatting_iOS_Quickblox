//
//  CAMenuViewController.m
//  ChattAR
//
//  Created by Igor Alefirenko on 04/09/2013.
//  Copyright (c) 2013 Stefano Antonelli. All rights reserved.
//
#import "SASlideMenuViewController.h"
#import "SASlideMenuRootViewController.h"
#import "CAMenuViewController.h"
#import "SplashViewController.h"
#import "SASlideMenuRootViewController.h"
#import "FBService.h"
#import <QuartzCore/QuartzCore.h>
#import "MenuCell.h"
#import "ProfileCell.h"
#import "FBStorage.h"
#import "Utilites.h"


@implementation CAMenuViewController

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation{
    return YES;
}

#pragma mark - 
#pragma mark ViewController Lifecycle

- (void)viewDidUnload{
    [self setFirstNameField:nil];
    [super viewDidUnload];
}

- (void)viewDidLoad{
    [super viewDidLoad];
    [self configureQButton];
}

- (void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:NO];
}

-(void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:NO];
    NSString *firstLastName = [NSString stringWithFormat:@"%@ %@", kGetFBFirstName,kGetFBLastName];
    [self.firstNameField setText:firstLastName];
    if (![Utilites deviceSupportsAR]) {
        NSArray *indexPaths = [NSArray arrayWithObject:[NSIndexPath indexPathForRow:4 inSection:0]];
        _isArNotAvailable = YES;
        [self.menuTable deleteRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationNone];
    }
    [self.menuTable selectRowAtIndexPath:[NSIndexPath indexPathForRow:2 inSection:0] animated:NO scrollPosition:UITableViewScrollPositionNone];
}

#pragma mark - QuickBlox Button

-(void)configureQButton{
    UIImage *img = [UIImage imageNamed:@"qb_mnu_grey.png"];
    UIButton *qbButton = [[UIButton alloc] init];
    qbButton.backgroundColor = [UIColor colorWithPatternImage:img];
    if (IS_HEIGHT_GTE_568) {
        qbButton.frame = CGRectMake(40, _menuTable.frame.size.height - (img.size.height+30), img.size.width, img.size.height);
    } else {
        qbButton.frame = CGRectMake(40, _menuTable.frame.size.height - (img.size.height+5), img.size.width, img.size.height);
    }
    [qbButton addTarget:self action:@selector(gotoQBSite) forControlEvents:UIControlEventTouchUpInside];
    [self.menuTable addSubview:qbButton];
}

// action
- (void)gotoQBSite{
    NSString* urlString = @"http://quickblox.com";
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:urlString]];
}

#pragma mark - TableView DataSource

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    NSInteger rows;
    if (_isArNotAvailable) {
        rows = 6;
    }else {
        rows = 7;
    }
    return rows;
}


#pragma mark -
#pragma mark SASlideMenuDataSource

// This is the indexPath selected at start-up
- (NSIndexPath*) selectedIndexPath{
    return [NSIndexPath indexPathForRow:2 inSection:0];
}

- (NSString*) segueIdForIndexPath:(NSIndexPath *)indexPath{
    NSString *segue = [NSString string];
    switch ([indexPath row]) {
        case 2:
            segue = kChatSegueIdentifier;
            break;
        case 3:
            segue = kMapSegueIdentifier;
            break;
        case 4:
            if (!_isArNotAvailable) {
                segue = kARSegueIdentifier;
            } else {
            segue = kDialogsSegueIdentifier;
            }
            break;
        case 5:
            if (!_isArNotAvailable) {
                segue = kDialogsSegueIdentifier;
            } else {
                segue = kAboutSegueIdentifier;
            }
            break;
        case 6:
            segue = kAboutSegueIdentifier;
            break;
            
        default:
            break;
    }
    return segue;
}

- (Boolean) allowContentViewControllerCachingForIndexPath:(NSIndexPath *)indexPath{
    return YES;
}

- (Boolean) disablePanGestureForIndexPath:(NSIndexPath *)indexPath{
    if (indexPath.row ==0) {
        return YES;
    }
    return NO;
}

// This is used to configure the menu button. The beahviour of the button should not be modified
- (void) configureMenuButton:(UIButton *)menuButton{
    menuButton.frame = CGRectMake(0, 0, 40, 29);
    [menuButton setImage:[UIImage imageNamed:@"mnubtn.png"] forState:UIControlStateNormal];
    [menuButton setBackgroundColor:[UIColor clearColor]];
}

- (void) configureSlideLayer:(CALayer *)layer{
    layer.shadowColor = [UIColor blackColor].CGColor;
    layer.shadowOpacity = 0.3;
    layer.shadowOffset = CGSizeMake(-15, 0);
    layer.shadowRadius = 10;
    layer.masksToBounds = NO;
    layer.shadowPath =[UIBezierPath bezierPathWithRect:layer.bounds].CGPath;
}

- (CGFloat) leftMenuVisibleWidth{
    return 250;
}
- (void)prepareForSwitchToContentViewController:(UINavigationController *)content{
}


#pragma mark -
#pragma mark SASlideMenuDelegate

-(void) slideMenuWillSlideIn{
    NSLog(@"slideMenuWillSlideIn");
}
-(void) slideMenuDidSlideIn{
    NSLog(@"slideMenuDidSlideIn");
}
-(void) slideMenuWillSlideToSide{
    NSLog(@"slideMenuWillSlideToSide");
}
-(void) slideMenuDidSlideToSide{
    NSLog(@"slideMenuDidSlideToSide");
    
}
-(void) slideMenuWillSlideOut{
    NSLog(@"slideMenuWillSlideOut");
    
}
-(void) slideMenuDidSlideOut{
    NSLog(@"slideMenuDidSlideOut");
}


#pragma mark -
#pragma mark Log Out ChattAR

- (IBAction)logOutChat:(id)sender {    
    
    // logout XMPP fb chat
    [[FBService shared] logOutChat];

    //log out from facebook
    if ([FBSession activeSession].state == FBSessionStateOpen) {
        [[FBSession activeSession] closeAndClearTokenInformation];
    }

    //log out from QBChat
    [[QBChat instance] logout];

    //Destroy QBSession
    [QBAuth destroySessionWithDelegate:nil];
    //clear  FBAccessToken and FBUser from DataManager
    [[FBStorage shared] clearFBAccess];
    [[FBStorage shared] clearFBUser];
}

@end