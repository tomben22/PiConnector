//
//  PresenseInsightsController.h
//  RPi4Home
//
//  Created by TBendig <tbendig@csc.com> on 07.07.15.
//  Copyright (c) 2015 CSC M&D. All rights reserved.
//  Version: 0.4
//

#import <UIKit/UIKit.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import <CoreLocation/CoreLocation.h>
#import <dispatch/dispatch.h>
#import <SystemConfiguration/SystemConfiguration.h>
#import <netinet/in.h>

@interface PresenceInsightsController : NSObject

@property (strong, nonatomic) CLLocationManager *locationManager;
@property (strong, nonatomic) CLBeaconRegion *beaconRegion;
@property (strong, nonatomic) NSDictionary *configuration;
@property (strong, nonatomic) NSMutableArray *beaconArray;
@property (nonatomic, strong) NSTimer *updateTimer;
@property (nonatomic, strong) NSArray *registeredUUID;



/**
 *  save the beacon array of found beacons in the controller class
 *
 *  @param beacons <#beacons description#>
 */
- (void) saveBeaconArrayForBackendTransfer:(NSArray*)beacons;


/**
 *  init & start time for backend transfer
 */
- (void) initTimerForBackendTransfer;

/**
 *  delete time for backend transfer service
 */
- (void) deleteTimerForBackendTransfer;

/**
 *  Check if internet connection is available
 *
 *  @return <#return value description#>
 */
- (BOOL) connectedToNetwork;

@end
