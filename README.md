# PiConnector
Connector to communicate with IBM Presence Insights

## usage of the controller methods

##### insert in AppDelegete class in "- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions"
<pre><code>
	    //Read the file PiConfig.plist
    NSString *configurationPath = [[NSBundle mainBundle]pathForResource:@"PiConfig" ofType:@"plist"];
    NSDictionary *configuration = [NSDictionary dictionaryWithContentsOfFile:configurationPath];
    NSString *applicationId = configuration[@"applicationid"];
    NSString *applicationRoute = configuration[@"applicationroute"];
    
    // initialize MobileFirst SDK with IBM Bluemix application ID and route
    [[IMFClient sharedInstance] initializeWithBackendRoute: applicationRoute backendGUID:applicationId];
    
    //analytics and monitoring
    [IMFLogger captureUncaughtExceptions]; // capture and record exceptions
    [IMFLogger setLogLevel:IMFLogLevelInfo]; // setting the verbosity filter
    [[IMFAnalytics sharedInstance] startRecordingApplicationLifecycleEvents]; // automatically record app startup times and fg/bg events
    
        self.logger = [IMFLogger loggerForName:[NSString stringWithFormat:@"%@",
                                            [[[NSBundle mainBundle] infoDictionary]
                                             objectForKey:(NSString*)kCFBundleNameKey]]];
</code></pre>

##### insert in your "-(void)viewDidLoad" method 
<pre><code>
// init PICL
PresenceInsightsController * pICL = [[PresenceInsightsController alloc]init];
</pre></code>

##### use these snippet to get the registered UUID fromthe PI backend and init the CLocationManager with for scanning beacons
<pre><code>
NSString *regUUID = [pICL.registeredUUID lastObject];
</pre></code>

##### insert into "-(void)locationManager:(CLLocationManager *)manager didEnterRegion:(CLRegion *)region"
<pre><code>
[pICL initTimerForBackendTransfer];
</pre></code>

##### insert in the "-(void)locationManager:(CLLocationManager *)manager didExitRegion:(CLRegion *)region" Method 
<pre><code>
   [pICL deleteTimerForBackendTransfer];
</pre></code>

##### insert the following snippet in the method "-(void)locationManager:(CLLocationManager *)manager didRangeBeacons:(NSArray *)beacons inRegion:(CLBeaconRegion *)region" of your Viewcontroller
<pre><code>
   [pICL saveBeaconArrayForBackendTransfer:beacons];
</pre></code>