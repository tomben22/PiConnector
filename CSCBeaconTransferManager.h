//
//  CSCBeaconTransferManager.h
//  RPi4Home
//
//  Created by TBendig on 29/09/15.
//  Copyright © 2015 CSC M&D. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CSCSingleton.h"
#import <CoreBluetooth/CoreBluetooth.h>
#import <CoreLocation/CoreLocation.h>

@interface CSCBeaconTransferManager : CSCSingleton
@property (atomic,strong) NSDate *lastTransferTimeStamp;

-(CLBeacon*) findBeaconWithHighestAccuracyInCLBeaconArray:(NSArray*)beaconArray;
-(BOOL)isTimeForUpdate;
-(BOOL)connectedToNetwork;

@end
