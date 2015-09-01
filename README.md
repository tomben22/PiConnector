# PiConnector
Connector to communicate with IBM Presence Insights

## upcoming tasks
- [ ] implement the other API methods 
- [ ] add exception handling

## usage of the controller methods

###### insert in your "-(void)viewDidLoad" method 
<pre><code>// init PICL
PresenceInsightsController * pICL = [[PresenceInsightsController alloc]init];</pre></code>

###### use these snippet to get the registered UUID fromthe PI backend and init the CLocationManager with for scanning beacons
<pre><code>NSString *regUUID = [pICL.registeredUUID lastObject];</pre></code>

###### insert into "-(void)locationManager:(CLLocationManager *)manager didEnterRegion:(CLRegion *)region"
<pre><code>[pICL initTimerForBackendTransfer];</pre></code>

###### insert in the "-(void)locationManager:(CLLocationManager *)manager didExitRegion:(CLRegion *)region" Method 
<pre><code>[pICL deleteTimerForBackendTransfer];</pre></code>

###### insert the following snippet in the method "-(void)locationManager:(CLLocationManager *)manager didRangeBeacons:(NSArray *)beacons inRegion:(CLBeaconRegion *)region" of your Viewcontroller
<pre><code>[pICL saveBeaconArrayForBackendTransfer:beacons];</pre></code>