//
//  PresenseInsightsController.h
//  RPi4Home
//
//  Created by TBendig <tom@tomben.de> on 07.07.15.
//  Copyright (c) 2015 Thomas Bendig All rights reserved.
//  Version: 0.2b
//

#import <IMFCore/IMFCore.h>
#import <dispatch/dispatch.h>

@interface PresenceInsightsController : NSObject

@property (strong, nonatomic) CLLocationManager *locationManager;
@property (strong, nonatomic) CLBeaconRegion *beaconRegion;
@property (strong, nonatomic) NSDictionary *configuration;
@property (strong, nonatomic) NSMutableArray *beaconArray;
@property (nonatomic, strong) NSTimer *updateTimer;
@property (nonatomic, strong) NSArray *registeredUUID;


- (void) saveBeaconArrayForBackendTransfer:(NSArray*)beacons;
- (void) initTimerForBackendTransfer;
- (void) deleteTimerForBackendTransfer;

@end
