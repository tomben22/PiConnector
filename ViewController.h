//
//  ViewController.h
//  RPi4Home
//
//  Created by TBendig <dev@tomben.de> on 07.07.15.
//  Copyright (c) 2015 TBendig. All rights reserved.
//  Version: 0.4
//


#import <UIKit/UIKit.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import <CoreLocation/CoreLocation.h>
#import "PresenceInsightsController.h"
#import "CSCBeaconTransferManager.h"

@interface ViewController : UIViewController <CLLocationManagerDelegate>

@property (strong, nonatomic) CLLocationManager *locationManager;
@property (strong, nonatomic) CLBeaconRegion *beaconRegion;


@end

