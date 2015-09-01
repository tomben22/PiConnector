//
//  PresenseInsightsController.m
//  RPi4Home
//
//  Created by TBendig <tbendig@csc.com> on 07.07.15.
//  Copyright (c) 2015 CSC M&D. All rights reserved.
//  Version: 0.3
//

#import "PresenceInsightsController.h"
@import CoreLocation;
#define AccuracyBugExists TRUE
#define POST 1
#define GET 2
#define PUT 3
#define DELETE 4


#pragma mark PI PayploadClass interface and implementation
/**
 *  PI Paypload Class for internal use
 */
@interface PresenceInsightsPayloadClass : NSObject

-(NSString*) getPayloadFormatStringforSendingBeaconData;
-(NSString*) getPayloadStringForRegisterDevices;

@end

@implementation PresenceInsightsPayloadClass

/**
 *  return the formatet payload string for register a device
 *  in the PI backend
 *  @return NSString *
 */
-(NSString*) getPayloadStringForRegisterDevices{
    return @"{\"name\": \"%@\",\"descriptor\": \"%@\",\"registered\": true,\"registrationType\": \"External\",\"data\": { \"email\": \"%@\", \"description\": \"%@\"},\"unencryptedData\": { \"devicetype\": \"%@\"}}";
}

/**
 *  get the payload string that is required to communicate with PI to send Beacondata
 *
 *  @return <#return value description#>
 */
-(NSString*) getPayloadFormatStringforSendingBeaconData{
    return @"{\"bnm\": [{\"descriptor\": \"%@\",\"detectedTime\": %lld,\"data\": {\"proximityUUID\": \"%@\",\"major\": \"%@\",\"minor\": \"%@\",\"accuracy\": %d,\"rssi\": %d,\"proximity\":\"%@\"} } ] }";
}


@end

#pragma mark private Presence Insights Controller variables and methods

@interface PresenceInsightsController(){
    dispatch_queue_t myQueue;
    NSString * appName;
    NSOperationQueue *queue;
    NSData *responseData;
    BOOL deviceRegistered;
}
@end


@implementation PresenceInsightsController
@synthesize configuration, beaconArray, updateTimer;


/**
 *  class init function that set configuration variables and try to connect
 *  to the PI Backend
 *
 *  @return id
 */
- (id)init {
    self = [super init];
    if (self) {
        // read app special config
        configuration = [NSDictionary dictionaryWithContentsOfFile:
                         [[NSBundle mainBundle]pathForResource:@"PiConfig"
                                                        ofType:@"plist"]];
        
        // create the PI Backend transfer queue
        myQueue = dispatch_queue_create([@"PR-Controller"
                                         cStringUsingEncoding:NSASCIIStringEncoding],
                                        NULL);
        
        
        queue = [[NSOperationQueue alloc] init];;
        
        appName = [NSString stringWithFormat:@"%@",
                   [[[NSBundle mainBundle] infoDictionary]
                    objectForKey:(NSString*)kCFBundleNameKey]];
        
        // get registration status from local storage
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        deviceRegistered = [defaults objectForKey:@"deviceRegistered"];
        
        NSLog(@"Presence Insights Controller startet");
    }
    return self;
}

/**
 *  Connect to the PI Backend, register the actual device and get the PI known UUIDS
 */
- (void)piConnect2Backend{
    
    // retrieve known UUIDS
    //  [self retrieveUUIDsFromBackend];
    
    //register device if it is not registered before
//    [self registerPiDeviceThroughRestAPI];
    
}



/**
 *  retrieve the known UUIDS from the PI Backend
 *  stores the UUIDS in the class viariable registerUUID
 */
-(void)retrieveUUIDsFromBackend{
    if(self.connectedToNetwork){
        
        
        //check if device is allready registered
        NSString *endpoint = [NSString stringWithFormat:@"/pi-config/v1/tenants/%@/orgs/%@/views/proximityUUID",
                              configuration[@"tenantcode"],
                              configuration[@"orgcode"]];
        
        NSData *response = [self sendRequestToPIBackendEndpointWithURL:endpoint
                                                     andAuthentication:YES
                                                      andOperationMode:GET
                                                            andPayload:Nil];
        
        self.registeredUUID = [NSJSONSerialization
                               JSONObjectWithData:response
                               options:NSJSONReadingMutableContainers
                               error:nil];
    }else{
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"No connection to PI-Service"
                                                        message:@"Please check your network connection."
                                                       delegate:self
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
    }
    
}




/**
 *  send found beacon data to backend
 *
 *  @param beacon CLBeacon Object
 */
-(void) sendFoundBeaconDatatoPresenceInsightsBackend:(CLBeacon*)beacon {
    
    if(!deviceRegistered){
        [self registerPiDeviceThroughRestAPI];
    }
    
    // send data to the Pi backend
    PresenceInsightsPayloadClass *piPC =  [PresenceInsightsPayloadClass alloc];
    NSString *payloadString = piPC.getPayloadFormatStringforSendingBeaconData;
    
    // create payload
    NSString *payload =@"";
    NSString *proximity = @"";
    if (beacon.proximity == CLProximityUnknown) {
        proximity =@"Unknown Proximity";
    } else if (beacon.proximity == CLProximityImmediate) {
        proximity = @"immediate";
    } else if (beacon.proximity == CLProximityNear) {
        proximity = @"near";
    } else if (beacon.proximity == CLProximityFar) {
        proximity = @"far";
    }
    
    
    // while accuracy Bug in PI exists we need to set the
    // accuracy to 0
    if(AccuracyBugExists){
        payload = [ NSString stringWithFormat:payloadString,
                   [[UIDevice currentDevice] name],
                   [[self getTimestamp]longLongValue],
                   [beacon.proximityUUID.UUIDString lowercaseString],
                   beacon.major,
                   beacon.minor,
                   0,
                   beacon.rssi,
                   proximity];
    }else{
        payload = [ NSString stringWithFormat:payloadString,
                   [[UIDevice currentDevice] name],
                   [[self getTimestamp]longLongValue],
                   [beacon.proximityUUID.UUIDString lowercaseString],
                   beacon.major,
                   beacon.minor,
                   beacon.accuracy,
                   beacon.rssi,
                   proximity];
    }
    
    // setup rest url
    NSString *endpoint = [NSString stringWithFormat:@"/conn-beacon/v1/tenants/%@/orgs/%@",
                          configuration[@"tenantcode"],
                          configuration[@"orgcode"]];
    
    [self sendRequestToPIBackendEndpointWithURL:endpoint
                              andAuthentication:YES
                               andOperationMode:POST
                                     andPayload:payload];
    
    piPC = nil;
}

#warning TODO make async call here

/**
 *  make the Presence Insights REST API Call and transfer the data
 *
 *  @param endpoint               <#endpoint description#>
 *  @param authenticationRequired <#authenticationRequired description#>
 *  @param operation              <#operation description#>
 *  @param payload                <#payload description#>
 *
 *  @return <#return value description#>
 */
-(NSData *) sendRequestToPIBackendEndpointWithURL:(NSString*) endpoint
                                andAuthentication:(BOOL)authenticationRequired
                                 andOperationMode:(int )operation
                                       andPayload:(NSString*) payload{
    
    // check if device is registered
    if(!deviceRegistered){
        [self registerPiDeviceThroughRestAPI];
    }
    
    // setup rest url
    NSString *backendUrlString = [NSString stringWithFormat:@"%@%@",
                                  configuration[@"restserviceroute"],
                                  endpoint];
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];  // the request
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setURL:[NSURL URLWithString:backendUrlString]];
    
    // create the custom REST methods with required specific data
    NSData * sendData;
    NSString * sendDataLength;
    
    switch (operation) {
        case POST:
            if([payload length] != 0){
                sendData = [payload dataUsingEncoding:NSASCIIStringEncoding
                                 allowLossyConversion:YES];
                sendDataLength = [NSString stringWithFormat:@"%lu",
                                  (unsigned long)[sendData length]];
                [request setValue:sendDataLength
               forHTTPHeaderField:@"Content-Length"];
            }
            
            [request setValue:sendDataLength forHTTPHeaderField:@"Content-Length"];
            [request setHTTPBody:sendData];
            [request setHTTPMethod:@"POST"];
            break;
        case GET:
            // GET
            [request setHTTPMethod:@"GET"];
            
            break;
        case PUT:
            //GET
            [request setHTTPMethod:@"PUT"];
            
            break;
        case DELETE:
            //delete
            [request setHTTPMethod:@"DELETE"];
            
            break;
        default:
            break;
    }
    
    
    // if authentication is required
    if(authenticationRequired){
        
        //username and password value
        NSString *username = configuration[@"piusername"];
        NSString *password = configuration[@"pipassword"];
        
        //HTTP Basic Authentication
        NSString *authenticationString = [NSString stringWithFormat:@"%@:%@", username, password];
        NSData *authenticationData = [authenticationString  dataUsingEncoding:NSUTF8StringEncoding];
        NSString *authenticationValue = [NSString stringWithFormat:@"Basic %@", [authenticationData base64Encoding]];
        [request setValue:authenticationValue forHTTPHeaderField:@"Authorization"];
    }
    
    // create the Request
    NSHTTPURLResponse *requestResponse;
    NSData *requestHandler;
    if(self.connectedToNetwork){
        requestHandler = [NSURLConnection sendSynchronousRequest:request
                                               returningResponse:&requestResponse
                                                           error:nil];
        
        NSLog(@"HTTP Statuscode: %li", (long)[requestResponse statusCode]);
        NSLog(@"%@",requestResponse);
        NSLog(@"########################  %@",payload);
        
    }
    else{
        NSLog(@"No Internet Connection available");
        
    }
    return requestHandler;
}



/**
 *  register the actuak device for PI, before register device the method check
 *  if the device is allready known
 */
-(void)registerPiDeviceThroughRestAPI{
    NSLog(@"Device registration startet- Status: %@", deviceRegistered?@"YES":@"NO");
    if(!deviceRegistered){
        NSString *endpoint = [NSString stringWithFormat:@"/pi-config/v1/tenants/%@/orgs/%@/devices",
                              configuration[@"tenantcode"],
                              configuration[@"orgcode"]];
        
        PresenceInsightsPayloadClass *piPC =  [PresenceInsightsPayloadClass alloc];
        NSString *payloadString = piPC.getPayloadStringForRegisterDevices;
        
        
        NSString *payload = [NSString stringWithFormat:payloadString,
                             [[UIDevice currentDevice] name],
                             [[[UIDevice currentDevice]identifierForVendor]UUIDString],
                             configuration[@"deviceusermailaddress"],
                             [[[UIDevice currentDevice]identifierForVendor]UUIDString],
                             [[UIDevice currentDevice]model]];
        NSLog(@"internet? %@", self.connectedToNetwork ? @"YES":@"NO");
        if(self.connectedToNetwork){
            
            [self sendRequestToPIBackendEndpointWithURL:endpoint
                                      andAuthentication:YES
                                       andOperationMode:POST
                                             andPayload:payload];
            // store to NSUserDefaults
            deviceRegistered = true;
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
            [defaults setValue:@"YES" forKey:@"deviceRegistered"];
            [defaults synchronize];
            
        }else{
            NSLog(@"Device is offline. No Backend data transfer initiated!");
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Check Internet Connection"
                                                            message:@"It seems that you are offline. Please check your internet connection."
                                                           delegate:self
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
            [alert show];
        }
    }
}


/**
 *  create the unique unix timestamp
 *
 *  @return NSString value of the unix timestamp
 */
-(NSString *)getTimestamp{
    return [NSString stringWithFormat:@"%f",
            ([[NSDate date] timeIntervalSince1970] * 1000.0) ];
}


/**
 *  add transfer-data-2-backend job to the global queue
 *
 *  @param sender unused
 */
-(void)startBackgroundTaskForTransfer:(id)sender {
    if([beaconArray count] > 0){
        for(CLBeacon *b in beaconArray){
            dispatch_async(myQueue, ^{
                [self sendFoundBeaconDatatoPresenceInsightsBackend: b];
            });
        }
    }
}

#pragma mark JSON convert methods

/**
 *  convert response into NSDictionary
 *  @param data <#data description#>
 *  @return NSDictionary object with the encoded JSON data
 */
-(NSDictionary * )getJSONResponsefromBackendRequest:(NSData*)data{
    NSMutableData *rData = [[NSMutableData alloc] init];
    [rData appendData:data];
    
    NSString *responseString = [[NSString alloc] initWithData:rData
                                                     encoding:NSUTF8StringEncoding];
    NSError *e = nil;
    NSData *jsonData = [responseString dataUsingEncoding:NSUTF8StringEncoding];
    return [NSJSONSerialization JSONObjectWithData:jsonData
                                           options: NSJSONReadingMutableContainers
                                             error: &e];
}


#pragma mark PresenceInsightsController public methods
/**
 *  save the beacon array of found beacons in the controller class
 *
 *  @param beacons <#beacons description#>
 */
-(void) saveBeaconArrayForBackendTransfer:(NSArray*)beacons{
    self.beaconArray = [[NSMutableArray alloc] initWithArray:beacons];
}

/**
 *  init & start time for backend transfer
 */
-(void)initTimerForBackendTransfer{
    updateTimer = [NSTimer  scheduledTimerWithTimeInterval:
                   [configuration[@"TimerdelayForBackendCall"] doubleValue]
                                                    target: self
                                                  selector: @selector(startBackgroundTaskForTransfer:)
                                                  userInfo: nil
                                                   repeats: YES];
}

/**
 *  delete time for backend transfer service
 */
-(void)deleteTimerForBackendTransfer{
    [updateTimer invalidate];
    updateTimer = nil;
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
