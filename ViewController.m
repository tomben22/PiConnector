// Copyright 2015 IBM Corp. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import "ViewController.h"
#import <IMFCore/IMFCore.h>
#import <CoreLocation/CoreLocation.h>
#import "PIBeaconSensorSDK.framework/Headers/PIAdapter.h"
#import "PIBeaconSensorSDK.framework/Headers/PIBeaconSensor.h"

@interface ViewController (){
    NSArray *pIRegisteredUUIDS; // store the beacon UUIDS from PI
    BOOL showExitRegionAlert;
    BOOL showEnterRegionAlert;
}
@property (weak, nonatomic) IBOutlet UILabel *topLabel;
@property (weak, nonatomic) IBOutlet UILabel *bottomLabel;
@property (weak, nonatomic) IBOutlet UIButton *pingButton;
@property (weak, nonatomic) IBOutlet UILabel *errorLabel;
@property (weak, nonatomic) IBOutlet UITextView *errorTextView;
@property (strong, nonatomic) PresenceInsightsController *pICL;
@property (nonatomic) long int actTimeStamp;
@property (atomic, strong) CSCBeaconTransferManager *cbtm;
@end

@implementation ViewController


- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.cbtm = [CSCBeaconTransferManager sharedInstance];
    
    showEnterRegionAlert = NO;
    showExitRegionAlert = NO;
    
    // Do any additional setup after loading the view, typically from a nib.
    self.locationManager = [[CLLocationManager alloc] init];
    self.locationManager.delegate = self;
    
    [self.locationManager requestWhenInUseAuthorization];
    [self.locationManager requestAlwaysAuthorization];
    
    
    
    // init PICL
    _pICL = [[PresenceInsightsController alloc]init];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


#pragma mark Locationmanager methods

/**
 *  <#Description#>
 *
 *  @param manager <#manager description#>
 *  @param state   <#state description#>
 *  @param region  <#region description#>
 */
-(void) locationManager:(CLLocationManager *)manager didDetermineState:(CLRegionState)state forRegion:(CLRegion *)region{
    if (state == CLRegionStateInside) {
        CLBeaconRegion *beaconRegion = (CLBeaconRegion *)region;
        [self.locationManager startRangingBeaconsInRegion:beaconRegion];
        if(!showEnterRegionAlert){
            NSString *loc = [NSString stringWithFormat:@"Welcome in the %@ region", region.identifier];
           
            UILocalNotification* localNotification = [[UILocalNotification alloc] init];
            localNotification.fireDate = [NSDate dateWithTimeIntervalSinceNow:5];
            localNotification.alertBody = loc;
            localNotification.timeZone = [NSTimeZone defaultTimeZone];
            localNotification.applicationIconBadgeNumber = localNotification.applicationIconBadgeNumber + 1;
            [[UIApplication sharedApplication] scheduleLocalNotification:localNotification];
            
            
            showEnterRegionAlert = YES;
            showExitRegionAlert = NO;
        }
    }else if (state == CLRegionStateOutside){
        if(!showExitRegionAlert){
            
            
            UILocalNotification* localNotification = [[UILocalNotification alloc] init];
            localNotification.fireDate = [NSDate dateWithTimeIntervalSinceNow:5];
            localNotification.alertBody = @"You left the BLE Region, Good Bye, come back soon!";
            localNotification.timeZone = [NSTimeZone defaultTimeZone];
            localNotification.applicationIconBadgeNumber = localNotification.applicationIconBadgeNumber + 1;
            [[UIApplication sharedApplication] scheduleLocalNotification:localNotification];

            
            showExitRegionAlert = YES;
            showEnterRegionAlert = NO;
        }
        
    }else if (state == CLRegionStateUnknown){
        NSLog(@"CLRegionStateUnknown");
    }
}

/**
 *  <#Description#>
 *
 *  @param manager <#manager description#>
 *  @param status  <#status description#>
 */
-(void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
    
    if([CLLocationManager locationServicesEnabled]){
        switch (status) {
            case kCLAuthorizationStatusDenied:
            {
                UIAlertView *alert= [[UIAlertView alloc]
                                     initWithTitle:@"Error"
                                     message:@"App level settings has been denied"
                                     delegate:nil
                                     cancelButtonTitle:@"Ok"
                                     otherButtonTitles: nil];
                [alert show];
                alert= nil;
            }
                break;
            case kCLAuthorizationStatusAuthorizedAlways:
            {
                //                [self locationManager:self.locationManager didStartMonitoringForRegion:self.beaconRegion];
              
                [self.pICL retrieveUUIDsFromBackend:^(NSArray *UUIDS,BOOL success) {
                    if (success && UUIDS.count>0) {
                        [self startScanningforBeacons:UUIDS];
                    }
                }];
               
            }
                
                break;
            case kCLAuthorizationStatusRestricted:
            {
                UIAlertView *alert= [[UIAlertView alloc]
                                     initWithTitle:@"Error"
                                     message:@"The app is recstricted from using location services."
                                     delegate:nil
                                     cancelButtonTitle:@"Ok"
                                     otherButtonTitles: nil];
                [alert show];
                alert= nil;
            }
                break;
            case kCLAuthorizationStatusNotDetermined:
            {
                
            }
                break;
            case kCLAuthorizationStatusAuthorizedWhenInUse:
            {
                [self.pICL retrieveUUIDsFromBackend:^(NSArray *UUIDS,BOOL success) {
                    if (success && UUIDS.count>0) {
                        [self startScanningforBeacons:UUIDS];
                    }
                }];
            }
                break;
            default:
                break;
        }
    }else{
        UIAlertView *alert= [[UIAlertView alloc]
                             initWithTitle:@"Error"
                             message:@"The location services seems to be disabled from the settings."
                             delegate:nil
                             cancelButtonTitle:@"Ok"
                             otherButtonTitles: nil];
        [alert show];
        alert= nil;
    }}

/**
 *  <#Description#>
 *
 *  @param manager <#manager description#>
 *  @param error   <#error description#>
 */
-(void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    NSLog( @"FAIL ERROR: %@", [error description] );
}

/**
 *  <#Description#>
 *
 *  @param manager <#manager description#>
 *  @param region  <#region description#>
 *  @param error   <#error description#>
 */
-(void)locationManager:(CLLocationManager *)manager rangingBeaconsDidFailForRegion: (CLBeaconRegion *)region withError:(NSError *)error {
    NSLog( @"RANGE BEACONS ERROR: %@", [error description] );
}

/**
 *  <#Description#>
 */
- (void)startScanningforBeacons:(NSArray*)UUIDS {

    NSString *regUUID = [UUIDS lastObject];
   
    if( regUUID != nil && [regUUID length] > 0 ){
    
        // the office beacon
        NSUUID *uuid1 = [[NSUUID alloc] initWithUUIDString:[regUUID uppercaseString]];
        
        self.beaconRegion = [[CLBeaconRegion alloc] initWithProximityUUID:uuid1 identifier:@"Office"];
        
        // set notifications
        self.beaconRegion.notifyEntryStateOnDisplay = YES;
        self.beaconRegion.notifyOnEntry = YES;
        self.beaconRegion.notifyOnExit = YES;
        
        // Register the beacon region with the location manager.
        [self.locationManager startMonitoringForRegion:self.beaconRegion];
        [self.locationManager requestStateForRegion:self.beaconRegion];

    }else{
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"ERROR"
                                                        message:@"Error occurred while registering region for scanning. Please check network connection and try again"
                                                       delegate:self
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
    }
}

/**
 *  <#Description#>
 *
 *  @param proximityUUID <#proximityUUID description#>
 *  @param identifier    <#identifier description#>
 */
- (void)registerBeaconRegionWithUUID:(NSUUID *)proximityUUID andIdentifier:(NSString*)identifier {
    
    NSLog(@"uuid registered with id: %@", proximityUUID.UUIDString);
    // Create the beacon region to be monitored.
    CLBeaconRegion *beaconRegion = [[CLBeaconRegion alloc]
                                    initWithProximityUUID:proximityUUID
                                    identifier:identifier];
    
    // Register the beacon region with the location manager.
    [self.locationManager startMonitoringForRegion:beaconRegion];
    [self.locationManager requestStateForRegion:beaconRegion];
}

/**
 *  <#Description#>
 *
 *  @param manager <#manager description#>
 *  @param region  <#region description#>
 */
- (void)locationManager:(CLLocationManager *)manager didStartMonitoringForRegion:(CLRegion *)region {
    NSLog(@"start monitoring for region %@", region.identifier);
    [self.locationManager startRangingBeaconsInRegion:self.beaconRegion];
//    [_pICL initTimerForBackendTransfer];
}

/**
 *  <#Description#>
 *
 *  @param manager <#manager description#>
 *  @param region  <#region description#>
 */
- (void)locationManager:(CLLocationManager *)manager didEnterRegion:(CLRegion *)region {
    
    self.actTimeStamp = [[NSDate date] timeIntervalSince1970];
    
    // start tracking beacons
    if ([region isKindOfClass:[CLBeaconRegion class]]) {
        CLBeaconRegion *beaconRegion = (CLBeaconRegion *)region;
        if ([beaconRegion.identifier isEqualToString:@"Office"]) {
            [self.locationManager startRangingBeaconsInRegion:beaconRegion];
        }
    }
    
    
    
    // dummy backend call
    CLBeacon *beacon = [[CLBeacon alloc]init];
    beacon.major = 2512;
    beacon.minor = 3;
    beacon.
    
    NSArray *b1 = nil;
    
    [self.pICL sendFoundBeaconDatatoPresenceInsightsBackend:b1];
//    [_pICL initTimerForBackendTransfer];
}

/**
 *  Method that entered
 *
 *  @param manager <#manager description#>
 *  @param region  <#region description#>
 */
-(void)locationManager:(CLLocationManager *)manager didExitRegion:(CLRegion *)region {
    if ([region isKindOfClass:[CLBeaconRegion class]]) {
        CLBeaconRegion *beaconRegion = (CLBeaconRegion *)region;
        if ([beaconRegion.identifier isEqualToString:@"Office"]) {
            [self.locationManager stopRangingBeaconsInRegion:beaconRegion];
        }
    }
//    [_pICL deleteTimerForBackendTransfer];
}


/**
 *  <#Description#>
 *
 *  @param manager <#manager description#>
 *  @param beacons <#beacons description#>
 *  @param region  <#region description#>
 */
-(void)locationManager:(CLLocationManager *)manager didRangeBeacons:(NSArray *)beacons inRegion:(CLBeaconRegion *)region {
    
    
    
    //[_pICL saveBeaconArrayForBackendTransfer:beacons];
    if([self.cbtm connectedToNetwork]  && beacons.count > 0  ){
        if([self.cbtm isTimeForUpdate]){
            NSLog(@"YES-----#########################################");
            [self.pICL sendFoundBeaconDatatoPresenceInsightsBackend:[self.cbtm findBeaconWithHighestAccuracyInCLBeaconArray:beacons]];
        }
    }
    
//    for(CLBeacon *beacon in beacons){
//            NSLog(@"UUID = %@ || range: %@  || Major: %@ || Minor: %@",
//                  beacon.proximityUUID.UUIDString,
//                  [self stringForProximity:beacon.proximity],
//                  beacon.major,
//                  beacon.minor);
//    }
    
  
    //CLBeacon *b1 =[cbtm findBeaconWithHighestAccuracyInCLBeaconArray:beacons];
    
   }


/**
 *  <#Description#>
 *
 *  @param manager <#manager description#>
 *  @param error   <#error description#>
 */
-(void) locationManager:(CLLocationManager *)manager didFinishDeferredUpdatesWithError:(NSError *)error{
    NSLog(@"didFinishDeferredUpdatesWithError with errormessage: %@", error.description);
}


#pragma mark Bluemix methods

-(IBAction)testBluemixConnection:(id)sender{
    
    _pingButton.backgroundColor =[UIColor colorWithRed:0.0/255.0 green:174.0/255.0 blue:211.0/255.0 alpha:1];
    
    //Logging is currently set to Info level. You can set the level below based on how much output you want to see:
    IMFLogger *logger=[IMFLogger loggerForName:@"BluemixTest"];
    [IMFLogger setLogLevel:IMFLogLevelInfo];
    [logger logInfoWithMessages:@"Testing connection to Bluemix"];
    
    //Testing the connection to Bluemix by attempting to obatain authorization
    // header from AMA. This test will also ensure the correct Bundle Identifier,
    // Bundle Version, ApplicationRoute and ApplicationID have been set.
    IMFAuthorizationManager *authManager = [IMFAuthorizationManager sharedInstance];
    [authManager obtainAuthorizationHeaderWithCompletionHandler:^(IMFResponse *response, NSError *error) {
        if (error==nil)
        {
            NSLog(@"You have connected to Bluemix successfully");
            _topLabel.text = @"Yay!";
            _bottomLabel.text = @"You Are Connected";
            _errorTextView.text = @"";
            
            
        }else{
            NSLog(@"%@",error);
            _topLabel.text = @"Bummer";
            _bottomLabel.text = @"Something Went Wrong";
            if (error.localizedDescription!=nil){
                NSString *errorMsg =  [NSString stringWithFormat: @"%@ Please verify the Bundle Identifier, Bundle Version, ApplicationRoute and ApplicationID.", error.localizedDescription];
                _errorTextView.text = errorMsg;
            }
        }
        _pingButton.backgroundColor=[UIColor colorWithRed:28.0/255.0 green:178.0/255.0 blue:153.0/255.0 alpha:1];
        
    }];
    [IMFLogger send];
}

/**
 *  <#Description#>
 *
 *  @param proximity <#proximity description#>
 *
 *  @return <#return value description#>
 */
- (NSString *)stringForProximity:(CLProximity)proximity {
    switch (proximity) {
        case CLProximityUnknown:    return @"Unknown";
        case CLProximityFar:        return @"Far";
        case CLProximityNear:       return @"Near";
        case CLProximityImmediate:  return @"Immediate";
        default:
            return nil;
    }
}

/**
 *  print beacon data to console for debbuging purpose
 *
 *  @param beacon <#beacon description#>
 */
-(void)printBeaconDataToConsole:(CLBeacon*) beacon{
    
    NSLog(@"#################################################################");
    NSLog(@"proximityUUID = %@", beacon.proximityUUID.UUIDString);
    NSLog(@"major = %@", beacon.major);
    NSLog(@"minor = %@", beacon.minor);
    NSLog(@"accuracy = %f", beacon.accuracy);
    if (beacon.proximity == CLProximityUnknown) {
        NSLog(@"Unknown Proximity");
    } else if (beacon.proximity == CLProximityImmediate) {
        NSLog(@"Immediate");
    } else if (beacon.proximity == CLProximityNear) {
        NSLog(@"Near");
    } else if (beacon.proximity == CLProximityFar) {
        NSLog(@"Far");
    }
    NSLog(@"rssiLabel = %@", [NSString stringWithFormat:@"%li", (long)beacon.rssi]);
}


@end
