//
//  PresenseInsightsController.h
//  RPi4Home
//
//  Created by TBendig <dev@tomben.de> on 07.07.15.
//  Copyright (c) 2015 TBendig. All rights reserved.
//  Version: 0.4
//

#import <UIKit/UIKit.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import <CoreLocation/CoreLocation.h>
#import <dispatch/dispatch.h>

typedef void (^PICompletionHandler)(NSData *response, BOOL success);
typedef void (^PIUUIDCompletionHandler) (NSArray *registeredUUIDS,BOOL success);

@interface PresenceInsightsController : NSObject

@property (strong, nonatomic) CLLocationManager *locationManager;
@property (strong, nonatomic) CLBeaconRegion *beaconRegion;
@property (strong, nonatomic) NSDictionary *configuration;
@property (strong, nonatomic) NSMutableArray *beaconArray;
//@property (nonatomic, strong) NSTimer *updateTimer;



/**
 *  save the beacon array of found beacons in the controller class
 *
 *  @param beacons <#beacons description#>
 */
- (void) saveBeaconArrayForBackendTransfer:(NSArray*)beacons;


-(void)retrieveUUIDsFromBackend:(PIUUIDCompletionHandler)completionHandler;


-(void) sendFoundBeaconDatatoPresenceInsightsBackend:(CLBeacon*)beacon;

/**
 *  init & start time for backend transfer
 */
//- (void) initTimerForBackendTransfer;

/**
 *  delete time for backend transfer service
 */
//- (void) deleteTimerForBackendTransfer;

@end
