//
//  PresenseInsightsController.m
//  RPi4Home
//
//  Created by TBendig <tom@tomben.de> on 07.07.15.
//  Copyright (c) 2015 Thomas Bendig All rights reserved.
//  Version: 0.2b
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
    IMFLogger *logger;
    NSString * appName;
}
- (void) piConnect2Backend;
- (void) startBackgroundTaskForTransfer:(id)sender;
- (void) retrieveUUIDsFromBackend;
- (void) sendFoundBeaconDatatoPresenceInsightsBackend:(CLBeacon*)beacon;
- (void) registerPiDeviceThroughRestAPI;
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
        myQueue = dispatch_queue_create([[NSString stringWithFormat:@"%@",
                                          [[NSBundle mainBundle] bundleIdentifier]]
                                         cStringUsingEncoding:NSASCIIStringEncoding],
                                        NULL);
        
        
        appName = [NSString stringWithFormat:@"%@",
                   [[[NSBundle mainBundle] infoDictionary]
                    objectForKey:(NSString*)kCFBundleNameKey]];
        
        [self piConnect2Backend];
    }
    return self;
}


/**
 *  Connect to the PI Backend, register the actual device and get the PI known UUIDS
 */
- (void)piConnect2Backend{
    //Logging is currently set to Info level. You can set the level below
    // based on how much output you want to see:
    logger=[IMFLogger loggerForName:appName];
    [IMFLogger setLogLevel:IMFLogLevelInfo];
    [logger logInfoWithMessages:@"Create Connection to PI"];
    
    // retrieve known UUIDS
    [self retrieveUUIDsFromBackend];
    
    //register device if it is not registered before
    [self registerPiDeviceThroughRestAPI];
    
    [IMFLogger send];
}


/**
 *  retrieve the known UUIDS from the PI Backend
 *  stores the UUIDS in the class viariable registerUUID
 */
-(void)retrieveUUIDsFromBackend{
    
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

}



/**
 *  send found beacon data to backend
 *
 *  @param beacon CLBeacon Object
 */
-(void) sendFoundBeaconDatatoPresenceInsightsBackend:(CLBeacon*)beacon {
    
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
    NSData *requestHandler = [NSURLConnection sendSynchronousRequest:request
                                                   returningResponse:&requestResponse
                                                               error:nil];
    
    NSLog(@"HTTP Statuscode: %li", (long)[requestResponse statusCode]);
    [logger logInfoWithMessages:@"HTTP Statuscode: %li", (long)[requestResponse statusCode]];
    [IMFLogger send];
    
    return requestHandler;
}


/**
 *  register the actuak device for PI, before register device the method check
 *  if the device is allready known
 */
-(void)registerPiDeviceThroughRestAPI{
    
    //check if device is allready registered
    NSString *endpoint = [NSString stringWithFormat:@"/pi-config/v1/tenants/%@/orgs/%@/devices",
                          configuration[@"tenantcode"],
                          configuration[@"orgcode"]];
    
    NSData *response = [self sendRequestToPIBackendEndpointWithURL:endpoint
                                                 andAuthentication:YES
                                                  andOperationMode:GET
                                                        andPayload:Nil];
    
    NSDictionary *jsonResponse = [self getJSONResponsefromBackendRequest:response];
    
    BOOL isRegistered = NO;
    
    NSArray *allKeys = [jsonResponse objectForKey:@"rows"];
    
    // check if device allready registered
    for (int x = 0; x < [allKeys count]; ++x) {
        NSDictionary *dict = [allKeys objectAtIndex:x];
        if([[dict objectForKey:@"name"] isEqualToString:[[UIDevice currentDevice] name]] && [dict objectForKey:@"registered"]){
            isRegistered = YES;
            [logger logInfoWithMessages:@"Device is still registered in your organisation"];
            break;
        };
    }
    
    //if device is not registered, try to register
    if(!isRegistered){
        PresenceInsightsPayloadClass *piPC =  [PresenceInsightsPayloadClass alloc];
        NSString *payloadString = piPC.getPayloadStringForRegisterDevices;
        
        
        NSString *payload = [NSString stringWithFormat:payloadString,
                             [[UIDevice currentDevice] name],
                             [[[UIDevice currentDevice]identifierForVendor]UUIDString],
                             configuration[@"deviceusermailaddress"],
                             [[[UIDevice currentDevice]identifierForVendor]UUIDString],
                             [[UIDevice currentDevice]model]];
        
        [self sendRequestToPIBackendEndpointWithURL:endpoint
                                  andAuthentication:YES
                                   andOperationMode:POST
                                         andPayload:payload];
        
        [IMFLogger send]; // send logs to bluemix backend
    }
}


/**
 *  convert response into NSDictionary
 *  @param data <#data description#>
 *  @return NSDictionary object with the encoded JSON data
 */
-(NSDictionary * )getJSONResponsefromBackendRequest:(NSData*)data{
    NSMutableData *responseData = [[NSMutableData alloc] init];
    [responseData appendData:data];
    
    NSString *responseString = [[NSString alloc] initWithData:responseData
                                                     encoding:NSUTF8StringEncoding];
    NSError *e = nil;
    NSData *jsonData = [responseString dataUsingEncoding:NSUTF8StringEncoding];
    return [NSJSONSerialization JSONObjectWithData:jsonData
                                           options: NSJSONReadingMutableContainers
                                             error: &e];
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
 *  save the beacon array of found beacons in the controller class
 *
 *  @param beacons <#beacons description#>
 */
-(void) saveBeaconArrayForBackendTransfer:(NSArray*)beacons{
    self.beaconArray = [[NSMutableArray alloc] initWithArray:beacons];
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

@end
