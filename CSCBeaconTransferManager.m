//
//  CSCBeaconTransferManager.m
//  RPi4Home
//
//  Created by TBendig on 29/09/15.
//  Copyright © 2015 CSC M&D. All rights reserved.
//

#import "CSCBeaconTransferManager.h"
#import <SystemConfiguration/SystemConfiguration.h>
#import <netinet/in.h>

@implementation CSCBeaconTransferManager

-(CLBeacon*) findBeaconWithHighestAccuracyInCLBeaconArray:(NSArray*)beaconArray{
   
    if (beaconArray.count == 1) {
        return [beaconArray objectAtIndex:0];
    }
    NSArray *sortedArray;
    sortedArray = [beaconArray sortedArrayUsingComparator:^NSComparisonResult(id a, id b) {
        NSNumber *first = [NSNumber numberWithDouble:[(CLBeacon*)a accuracy]];
        NSNumber *second = [NSNumber numberWithDouble:[(CLBeacon*)b accuracy]];
        return [first compare:second];
    }];
    
    return [sortedArray objectAtIndex:0];
}

-(NSNumber *)getTransferIntervallFromSettings{
    NSDictionary *configuration = [NSDictionary dictionaryWithContentsOfFile:
    [[NSBundle mainBundle]pathForResource:@"PiConfig"
                                   ofType:@"plist"]];
    
    if(configuration[@"TimerdelayForBackendCall"]){
        return configuration[@"TimerdelayForBackendCall"];
    }else{
        return @60; // todo
    }
}

-(BOOL)isTimeForUpdate{
    if(!self.lastTransferTimeStamp){
        self.lastTransferTimeStamp = [NSDate date];
        return YES;
    }
    
    NSTimeInterval updateIntervall = [self.lastTransferTimeStamp timeIntervalSince1970] + [[self getTransferIntervallFromSettings]doubleValue];

   if ([[NSDate dateWithTimeIntervalSince1970:updateIntervall] compare:[NSDate date]] == NSOrderedDescending) {
       // NSLog(@"date1 is earlier than date2");
       return NO;
   }
    
    self.lastTransferTimeStamp = [NSDate date];
    return YES;
}

# pragma mark internet check methods
/**
 *  check if internet connection  is available
 *
 *  @return Boolean
 */
-(BOOL)connectedToNetwork {
    struct sockaddr_in zeroAddress;
    bzero(&zeroAddress, sizeof(zeroAddress));
    zeroAddress.sin_len = sizeof(zeroAddress);
    zeroAddress.sin_family = AF_INET;
    
    // call accessibility flag
    SCNetworkReachabilityRef defaultRouteReachability =
    SCNetworkReachabilityCreateWithAddress(NULL, (struct sockaddr *) &zeroAddress);
    SCNetworkReachabilityFlags flags;
    
    BOOL didReceiveFlags = SCNetworkReachabilityGetFlags(defaultRouteReachability, &flags);
    CFRelease(defaultRouteReachability);
    
    if(!didReceiveFlags)
    {
        return NO;
    }
    BOOL isReachable = ((flags & kSCNetworkFlagsReachable) != 0);
    BOOL needsConnection = ((flags & kSCNetworkFlagsConnectionRequired) != 0);
    
    if(isReachable && !needsConnection){
        return YES;
    }
    else
    {
        return NO;
    }
}


@end
