//
//  AugmentedRealityController.m
//  MashApp-location_users-ar-ios
//
//  Created by Igor Khomenko on 3/26/12.
//  Copyright (c) 2012 Injoit. All rights reserved.
//

#import "AugmentedRealityController.h"
#import "ARCoordinate.h"
#import "ARGeoCoordinate.h"
#import "ARMarkerView.h"
#import "MapChatARViewController.h"

#define kFilteringFactor 0.05
#define degreesToRadian(x) (M_PI * (x) / 180.0)
#define radianToDegrees(x) ((x) * 180.0/M_PI)

#define canvasFrame CGRectMake(0, 0, 320, 480)
#pragma mark -

@interface AugmentedRealityController (Private) 
- (void) updateCenterCoordinate;
- (void) startListening;
- (double) findDeltaOfRadianCenter:(double*)centerAzimuth coordinateAzimuth:(double)pointAzimuth betweenNorth:(BOOL*) isBetweenNorth;
- (CGPoint) pointInView:(UIView *)realityView withView:(UIView *)viewToDraw forCoordinate:(ARCoordinate *)coordinate;
- (BOOL) viewportContainsView:(UIView *)viewToDraw forCoordinate:(ARCoordinate *)coordinate;
@end

#pragma mark -

@implementation AugmentedRealityController

@synthesize locationManager, accelerometerManager, displayView, centerCoordinate, scaleViewsBasedOnDistance, transparenViewsBasedOnDistance, rotateViewsBasedOnPerspective, maximumScaleDistance, minimumScaleFactor, maximumRotationAngle, centerLocation, coordinates, currentOrientation, degreeRange;
@synthesize latestHeading, viewAngle, coordinateViews;
@synthesize captureSession;
@synthesize delegate, distanceSlider, distanceLabel;


#pragma mark - 
#pragma mark Init & dealloc 

- (id)initWithViewFrame:(CGRect) _viewFrame{
    self = [super init];
    if(!self){
        return nil;
    }
    
	coordinates		= [[NSMutableArray alloc] init];
	coordinateViews	= [[NSMutableArray alloc] init];
	latestHeading	= -1.0f;
    
	self.maximumScaleDistance = 1.3;
	self.minimumScaleFactor = 0.3;
    
	self.scaleViewsBasedOnDistance = YES;
    self.transparenViewsBasedOnDistance = YES;
	self.rotateViewsBasedOnPerspective = NO;
    
	self.maximumRotationAngle = M_PI / 6.0;
    
    self.currentOrientation = UIDeviceOrientationPortrait; 
    self.degreeRange = _viewFrame.size.width / 12; 
    
    viewFrame = _viewFrame;
    
    
    
    // 1 km (все, кто в радиусе 1 км)
    // 5 km
    // 10 km
    // 50 km
    // 150 km
    // 500 km 
    // 1000 km
    // 3000 km 
    // 20000 km
    sliderNumbers = [[NSMutableArray alloc] init];
    [sliderNumbers addObject:[NSNumber numberWithInt:1000]];
    [sliderNumbers addObject:[NSNumber numberWithInt:5000]];
    [sliderNumbers addObject:[NSNumber numberWithInt:10000]];
    [sliderNumbers addObject:[NSNumber numberWithInt:50000]];
    [sliderNumbers addObject:[NSNumber numberWithInt:150000]];
    [sliderNumbers addObject:[NSNumber numberWithInt:500000]];
    [sliderNumbers addObject:[NSNumber numberWithInt:1000000]];
    [sliderNumbers addObject:[NSNumber numberWithInt:3000000]];
    [sliderNumbers addObject:[NSNumber numberWithInt:maxARDistance]];
    
    
    return self;
}

- (void)loadView{
    // add canvas
	displayView = [[UIImageView alloc] initWithFrame:viewFrame]; 
    displayView.clipsToBounds = YES;
    [displayView setUserInteractionEnabled:YES];
	
    self.view = displayView;
    [displayView release];
    
	distanceSlider = [[UISlider alloc] init];
	[distanceSlider setFrame:CGRectMake(-127, 160, 300, 30)];
	[distanceSlider addTarget:self action:@selector(distanceDidChanged:) forControlEvents:UIControlEventValueChanged];
	distanceSlider.minimumValue =  0;
	distanceSlider.maximumValue = [sliderNumbers count]-1;
    distanceSlider.continuous = YES;
    [self.view addSubview:distanceSlider];
	[distanceSlider setValue:2 animated:NO];
	[distanceSlider release];
    
    distanceLabel = [[UILabel alloc] init];
    [distanceLabel setFrame:CGRectMake(19, 335, 100, 20)];
    [distanceLabel setBackgroundColor:[UIColor clearColor]];
    [distanceLabel setFont:[UIFont systemFontOfSize:12]];
    [distanceLabel setTextColor:[UIColor whiteColor]];
    
    distanceLabel.text = [NSString stringWithFormat:@"%d km", [[sliderNumbers objectAtIndex:distanceSlider.value] intValue]/1000];
    [self.view addSubview:distanceLabel];
    [distanceLabel release];
    
    // set dist
    NSUInteger index = distanceSlider.value;
    switchedDistance = [[sliderNumbers objectAtIndex:index] intValue]; // <-- This is the number you want.
}

-(void)distanceDidChanged:(UISlider *)slider
{
    NSUInteger index = slider.value;
    [slider setValue:index animated:NO];
    
    // set dist
    switchedDistance = [[sliderNumbers objectAtIndex:index] intValue]; // <-- This is the number you want.
    
    distanceLabel.text = [NSString stringWithFormat:@"%d km", switchedDistance/1000];
}

// switch All/Friends
- (void)allFriendsSwitchValueDidChanged:(id)sender{
    [((MapChatARViewController *)delegate) allFriendsSwitchValueDidChanged:sender];
}

- (void) viewDidLoad{
    [super viewDidLoad];
	
	CGAffineTransform trans = CGAffineTransformMakeRotation(M_PI * 0.5);
	distanceSlider.transform = trans;
    
//    CALayer *layer = distanceSlider.layer;
//    CATransform3D rotationAndPerspectiveTransform = CATransform3DIdentity;
//    rotationAndPerspectiveTransform.m34 = 1.0 / 500;
//    rotationAndPerspectiveTransform = CATransform3DRotate(rotationAndPerspectiveTransform, 1.0f, -(45.0f * M_PI / 180.0f), 0.0f, 0.0f);
//    layer.transform = rotationAndPerspectiveTransform;
    
    
	[self.view bringSubviewToFront:distanceSlider];
    [self.view bringSubviewToFront:distanceLabel];
	
	[displayView setBackgroundColor:[UIColor clearColor]];
}

- (void)viewDidUnload{
    [super viewDidUnload];
}

- (void)dealloc {
	[coordinates release];
	[captureSession release];
	[centerLocation release];
    
    [sliderNumbers release];
	
	self.locationManager = nil;
	self.coordinateViews = nil;
	
    [super dealloc];
}

// touch on marker
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event{
    UITouch *lastTouch = [touches anyObject];
    
    for(int i=[self.view.subviews count]-1; i>=0; i--)
	{
        ARMarkerView *marker = [self.view.subviews objectAtIndex:i];
        if(![marker isKindOfClass:ARMarkerView.class])
		{
            continue;
        }
        
		CGPoint point = [lastTouch locationInView:marker];
        
        if(point.x > 0 && point.y > 0)
		{
            [marker.target performSelector:marker.action withObject:marker];
            break;
        }
    }
}

// This is needed to start showing the Camera of the Augemented Reality Toolkit.
- (void)displayAR{
	
    [self initCapture];
    
	[self startListening];
}

- (void)dissmisAR {
    [captureSession stopRunning];
    
    [displayView setImage:nil];
    
    for(UIView *view in self.view.subviews){
        if([view isKindOfClass:[CustomSwitch class]] || view == distanceSlider || view == distanceLabel){
			continue;
        }
        
		[view removeFromSuperview];
    }
    
    self.captureSession = nil;
}

- (void)startListening {
	
	// start our heading readings and our accelerometer readings.
	if (!self.locationManager) {
		locationManager = [[CLLocationManager alloc] init];
		self.locationManager.headingFilter = kCLHeadingFilterNone;
		self.locationManager.desiredAccuracy = kCLLocationAccuracyBest;
		[self.locationManager startUpdatingHeading];
		[self.locationManager startUpdatingLocation];
		self.locationManager.delegate = self;
	}
    
	if (!self.accelerometerManager) {
		self.accelerometerManager = [UIAccelerometer sharedAccelerometer];
		self.accelerometerManager.updateInterval = 0.1;
		self.accelerometerManager.delegate = self;
	}
	
	if (!self.centerCoordinate) 
		self.centerCoordinate = [ARCoordinate coordinateWithRadialDistance:1.0 inclination:0 azimuth:0];
}

- (void)refreshWithNewPoints:(NSArray *)mapPoints{
	// remove old
	for (UIView* view in displayView.subviews){
		if ([view isKindOfClass:[CustomSwitch class]] || view == distanceLabel || view == distanceSlider){
			continue;
		}
        
		[view removeFromSuperview];
	}
	[coordinates removeAllObjects];
	[coordinateViews removeAllObjects];
	
    
    // add new
    [self addPoints:mapPoints];
}

- (void)clear{
    [coordinates removeAllObjects];
	[coordinateViews removeAllObjects];
}

/*
 Add users' annotations to AR environment
 */
- (void)addPoints:(NSArray *)mapPoints{
    // add new
    if([mapPoints count] > 0){
        for(UserAnnotation *userAnnotation in mapPoints ){
            // add user annotation
			if ([userAnnotation isKindOfClass:[UserAnnotation class]]){
				[self addPoint:userAnnotation];
			}
        }
    }
    
    // update markers positions
    [self updateMarkersPositionsForCenterLocation:centerLocation];
}

/*
 Add user's annotation to AR environment
 */
- (void)addPoint:(UserAnnotation *)userAnnotation{
    
    // skip me
    if([userAnnotation.fbUserId isEqualToString:[DataManager shared].currentFBUserId]){
        return;
    }
    
    // add marker
    
    // get view for annotation
    UIView *markerView = [self viewForAnnotation:userAnnotation];
    
    // create marker location
    CLLocation *location = [[CLLocation alloc] initWithLatitude:userAnnotation.coordinate.longitude 
                                                      longitude:userAnnotation.coordinate.longitude];
    
    // create AR coordinate
    ARCoordinate *coordinateForUser = [ARGeoCoordinate coordinateWithLocation:location 
                                                                locationTitle:userAnnotation.userName];
    [location release];
    
	[self addCoordinate:coordinateForUser augmentedView:markerView animated:NO];
}

/*
 Return view for new user annotation
 */
- (UIView *)viewForAnnotation:(UserAnnotation *)userAnnotation{
    ARMarkerView *marker = [[[ARMarkerView alloc] initWithGeoPoint:userAnnotation] autorelease];
    marker.target = delegate;
    marker.action = @selector(touchOnMarker:);
    return marker;
}

/*
 Return view for exist user annotation
 */

- (UIView *)viewForExistAnnotation:(UserAnnotation *)userAnnotation{
    for(ARMarkerView *marker in coordinateViews){
        if([marker.userAnnotation.fbUserId isEqualToString:userAnnotation.fbUserId]){
            return marker;
        }
    }
    return nil;
}

/*
 Add AR coordinate 
 */
- (void)addCoordinate:(ARCoordinate *)coordinate augmentedView:(UIView *)agView animated:(BOOL)animated {
	[coordinates addObject:coordinate];
	
	if (coordinate.radialDistance > self.maximumScaleDistance) {
		self.maximumScaleDistance = coordinate.radialDistance;
    }
	
	[coordinateViews addObject:agView];
}

/*
 Remove AR coordinate
 */
- (void)removeCoordinate:(ARCoordinate *)coordinate {
	[self removeCoordinate:coordinate animated:YES];
}

- (void)removeCoordinate:(ARCoordinate *)coordinate animated:(BOOL)animated {
	NSUInteger indexToRemove = [coordinates indexOfObject:coordinate];
    [coordinates	 removeObjectAtIndex:indexToRemove];
    [coordinateViews removeObjectAtIndex:indexToRemove];
}

- (void)removeCoordinates:(NSArray *)coordinateArray {	
	// remove coordinates
	for (ARCoordinate *coordinateToRemove in coordinateArray) {
		[self removeCoordinate:coordinateToRemove animated:NO];
	}
}


#pragma mark - 
#pragma mark CLLocationManagerDelegate

- (void)locationManager:(CLLocationManager *)manager didUpdateHeading:(CLHeading *)newHeading {
	latestHeading = degreesToRadian(newHeading.magneticHeading);
	[self updateCenterCoordinate];
}

- (BOOL)locationManagerShouldDisplayHeadingCalibration:(CLLocationManager *)manager {
	return YES;
}

- (void)locationManager:(CLLocationManager *)manager didUpdateToLocation:(CLLocation *)newLocation fromLocation:(CLLocation *)oldLocation {
	// set new own location
    if (oldLocation == nil){
		self.centerLocation = newLocation;
    }
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
	
}


#pragma mark - 
#pragma mark UIAccelerometerDelegate 

- (void)accelerometer:(UIAccelerometer *)accelerometer didAccelerate:(UIAcceleration *)acceleration {
	
	switch (currentOrientation) {
		case UIDeviceOrientationLandscapeLeft:
			viewAngle = atan2(acceleration.x, acceleration.z);
			break;
		case UIDeviceOrientationLandscapeRight:
			viewAngle = atan2(-acceleration.x, acceleration.z);
			break;
		case UIDeviceOrientationPortrait:
			viewAngle = atan2(acceleration.y, acceleration.z);
			break;
		case UIDeviceOrientationPortraitUpsideDown:
			viewAngle = atan2(-acceleration.y, acceleration.z);
			break;	
		default:
			break;
	}
	
	[self updateCenterCoordinate];
}


#pragma mark - 
#pragma mark  Private methods 

// called when updating acceleration or locationHeading 
- (void)updateCenterCoordinate {
	double adjustment = 0;
	
	if (currentOrientation == UIDeviceOrientationLandscapeLeft)
		adjustment = degreesToRadian(270); 
	else if (currentOrientation == UIDeviceOrientationLandscapeRight)
		adjustment = degreesToRadian(90);
	else if (currentOrientation == UIDeviceOrientationPortraitUpsideDown)
		adjustment = degreesToRadian(180);
    
	self.centerCoordinate.azimuth = latestHeading - adjustment;
	[self updateLocations];
}

// called by the two next methods 
- (double)findDeltaOfRadianCenter:(double*)centerAzimuth coordinateAzimuth:(double)pointAzimuth betweenNorth:(BOOL*)isBetweenNorth {
    
	if (*centerAzimuth < 0.0) 
		*centerAzimuth = (M_PI * 2.0) + *centerAzimuth;
	
	if (*centerAzimuth > (M_PI * 2.0)) 
		*centerAzimuth = *centerAzimuth - (M_PI * 2.0);
	
	double deltaAzimuth = ABS(pointAzimuth - *centerAzimuth);
	*isBetweenNorth		= NO;
    
	// If values are on either side of the Azimuth of North we need to adjust it.  Only check the degree range
	if (*centerAzimuth < degreesToRadian(self.degreeRange) && pointAzimuth > degreesToRadian(360-self.degreeRange)) {
		deltaAzimuth	= (*centerAzimuth + ((M_PI * 2.0) - pointAzimuth));
		*isBetweenNorth = YES;
	}
	else if (pointAzimuth < degreesToRadian(self.degreeRange) && *centerAzimuth > degreesToRadian(360-self.degreeRange)) {
		deltaAzimuth	= (pointAzimuth + ((M_PI * 2.0) - *centerAzimuth));
		*isBetweenNorth = YES;
	}
    
	return deltaAzimuth;
}

// called by updateLocations 
- (CGPoint)pointInView:(UIView *)realityView withView:(UIView *)viewToDraw forCoordinate:(ARCoordinate *)coordinate {	
	
	CGPoint point;
	CGRect realityBounds	= realityView.bounds;
	double currentAzimuth	= self.centerCoordinate.azimuth;
	double pointAzimuth		= coordinate.azimuth;
	BOOL isBetweenNorth		= NO;
	double deltaAzimuth		= [self findDeltaOfRadianCenter: &currentAzimuth coordinateAzimuth:pointAzimuth betweenNorth:&isBetweenNorth];
	
	if ((pointAzimuth > currentAzimuth && !isBetweenNorth) || (currentAzimuth > degreesToRadian(360-self.degreeRange) && pointAzimuth < degreesToRadian(self.degreeRange)))
		point.x = (realityBounds.size.width / 2) + ((deltaAzimuth / degreesToRadian(1)) * 12);  // Right side of Azimuth
	else
		point.x = (realityBounds.size.width / 2) - ((deltaAzimuth / degreesToRadian(1)) * 12);	// Left side of Azimuth
	
	point.y = (realityBounds.size.height / 2) + (radianToDegrees(M_PI_2 + viewAngle)  * 2.0);
	
	return point;
}

// called by updateLocations 
- (BOOL)viewportContainsView:(UIView *)viewToDraw  forCoordinate:(ARCoordinate *)coordinate {    
	double currentAzimuth = self.centerCoordinate.azimuth;
	double pointAzimuth	  = coordinate.azimuth;
	BOOL isBetweenNorth	  = NO;
	double deltaAzimuth	  = [self findDeltaOfRadianCenter: &currentAzimuth coordinateAzimuth:pointAzimuth betweenNorth:&isBetweenNorth];
	BOOL result			  = NO;
	
	if (deltaAzimuth <= degreesToRadian(self.degreeRange))
		result = YES;
    
	return result;
}


#pragma mark - 
#pragma mark Properties

- (void)setCenterLocation:(CLLocation *)newLocation {
	[centerLocation release];
	centerLocation = [newLocation retain];
	
    // update markers positions
    [self updateMarkersPositionsForCenterLocation:newLocation];
}

- (void)updateMarkersPositionsForCenterLocation:(CLLocation *)_centerLocation 
{
    int index			= 0;

	for (ARGeoCoordinate *geoLocation in self.coordinates) 
	{
		
		if ([geoLocation isKindOfClass:[ARGeoCoordinate class]]) {
			[geoLocation calibrateUsingOrigin:_centerLocation];
			
			if (geoLocation.radialDistance > self.maximumScaleDistance) {
				self.maximumScaleDistance = geoLocation.radialDistance;
            }
		}
        
        // update distance
        ARMarkerView *marker = [coordinateViews objectAtIndex:index];
        [marker updateDistance:_centerLocation];
        
        ++index;
	}
    
    
    // sort markers by distance
    int i,j;
    UIView *temp;
    int n = [coordinateViews count];
    for (i=0; i<n-1; i++) {
        for (j=0; j<n-1-i; j++) {
            if ([[coordinateViews objectAtIndex:j] distance] > [[coordinateViews objectAtIndex:j+1] distance]) {
				temp = [[coordinateViews objectAtIndex:j] retain];
				[coordinateViews replaceObjectAtIndex:j withObject:[coordinateViews objectAtIndex:j+1]];
				[coordinateViews replaceObjectAtIndex:j+1 withObject:temp];
                [temp release];
            }
        }
    }
}


#pragma mark -
#pragma mark Public methods 


- (void)updateLocations {
	
	if (!coordinateViews || [coordinateViews count] == 0) {
		return;
    }
	
	int index			= 0;
	int totalDisplayed	= 0;
	
    int maxShowedMarkerDistance = 0;
    int minShowedMarkerDistance = 100000000;
    int count = 0;

    
	for (ARCoordinate *item in coordinates) {
		
		ARMarkerView *viewToDraw = [coordinateViews objectAtIndex:index];

		if ([self viewportContainsView:viewToDraw forCoordinate:item] && (viewToDraw.distance < switchedDistance)) {
			
            // mraker location
			CGPoint locCenter = [self pointInView:self.displayView withView:viewToDraw forCoordinate:item];
            
//            CATransform3D transform = CATransform3DIdentity;
            
			CGFloat scaleFactor = 1.0;
			
			float width	 = viewToDraw.bounds.size.width  * scaleFactor;
			float height = viewToDraw.bounds.size.height * scaleFactor;
			
            int offset = totalDisplayed%2 ? totalDisplayed*25 : -totalDisplayed*25;
			viewToDraw.frame = CGRectMake(locCenter.x - width / 2.0, locCenter.y - (height / 2.0) + offset, width, height);
            
			totalDisplayed++;
			
//            // rotate view based on perspective
//			if ([self rotateViewsBasedOnPerspective]) {
//				transform.m34 = 1.0 / 300.0;
//				
//				double itemAzimuth		= item.azimuth;
//				double centerAzimuth	= self.centerCoordinate.azimuth;
//				
//				if (itemAzimuth - centerAzimuth > M_PI) 
//					centerAzimuth += 2 * M_PI;
//				
//				if (itemAzimuth - centerAzimuth < -M_PI) 
//					itemAzimuth  += 2 * M_PI;
//				
//				double angleDifference	= itemAzimuth - centerAzimuth;
//				transform				= CATransform3DRotate(transform, self.maximumRotationAngle * angleDifference / 0.3696f , 0, 1, 0);
//			}
//			
//            
//            // allow transform
//			viewToDraw.layer.transform = transform;
            
			//if we don't have a superview, set it up.
			if (!([viewToDraw superview])) {
				[self.displayView addSubview:viewToDraw];
				[self.displayView sendSubviewToBack:viewToDraw];
			}
            
            // save max distance
            if(viewToDraw.distance > maxShowedMarkerDistance){
                maxShowedMarkerDistance = viewToDraw.distance;
            }
            if(viewToDraw.distance < minShowedMarkerDistance){
                minShowedMarkerDistance = viewToDraw.distance;
            }
            
            ++count;
            
        } else{ 
			[viewToDraw removeFromSuperview];
        }
		
		index++;
	}
    
    // Set Alpha & Size based on distance
    if([self scaleViewsBasedOnDistance] || [self transparenViewsBasedOnDistance]){

        float scaledChunkWidth = ((maxShowedMarkerDistance-minShowedMarkerDistance)/1000.f)/countOfScaledChunks;
        
        int i = 0;
        for (ARMarkerView *viewToDraw in self.displayView.subviews) {
            if(![viewToDraw isKindOfClass:ARMarkerView.class]){
                continue;
            }
     
            ++i;
            
            CATransform3D transform = CATransform3DIdentity;
            
			CGFloat scaleFactor = 1.0;
            
            // scale view based on distance
            if ([self scaleViewsBasedOnDistance]) {

                int numberOfChunk = ceil(((viewToDraw.distance-minShowedMarkerDistance)/1000.f)/scaledChunkWidth);

                scaleFactor = 1.0 - numberOfChunk*scaleStep();

                if(scaleFactor > 1){
                    scaleFactor = 1.0;
                }else if (scaleFactor < minARMarkerScale){
                    scaleFactor = minARMarkerScale;
                }

                transform = CATransform3DScale(transform, scaleFactor, scaleFactor, scaleFactor);
                viewToDraw.layer.transform = transform;
            }
            
            // set alpha
            if([self transparenViewsBasedOnDistance]){
                int numberOfChunk = ceil(((viewToDraw.distance-minShowedMarkerDistance)/1000.f)/scaledChunkWidth);
                
                float alpha = 1.0 - numberOfChunk*alphaStep();
                if(alpha > 1){
                    alpha = 1.0;
                }else if (alpha < minARMarkerAlpha){
                    alpha = minARMarkerAlpha;
                }
                viewToDraw.alpha = alpha;
            }
        }
    }
}


#pragma mark -
#pragma mark Capture

- (IBAction) initCapture {
    
	/*We setup the input*/
	AVCaptureDeviceInput *captureInput = [AVCaptureDeviceInput 
										  deviceInputWithDevice:[AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo] 
										  error:nil];
	/*We setupt the output*/
	AVCaptureVideoDataOutput *captureOutput = [[AVCaptureVideoDataOutput alloc] init];
	/*While a frame is processes in -captureOutput:didOutputSampleBuffer:fromConnection: delegate methods no other frames are added in the queue.
	 If you don't want this behaviour set the property to NO */
	captureOutput.alwaysDiscardsLateVideoFrames = YES; 
	/*We specify a minimum duration for each frame (play with this settings to avoid having too many frames waiting
	 in the queue because it can cause memory issues). It is similar to the inverse of the maximum framerate.
	 In this example we set a min frame duration of 1/10 seconds so a maximum framerate of 10fps. We say that
	 we are not able to process more than 10 frames per second.*/
	captureOutput.minFrameDuration = CMTimeMake(1, 15);
	
	/*We create a serial queue to handle the processing of our frames*/
	dispatch_queue_t queue;
	queue = dispatch_queue_create("cameraQueue", NULL);
	[captureOutput setSampleBufferDelegate:self queue:queue];
	dispatch_release(queue);
	// Set the video output to store frame in BGRA (It is supposed to be faster)
	NSString* key = (NSString*)kCVPixelBufferPixelFormatTypeKey; 
	NSNumber* value = [NSNumber numberWithUnsignedInt:kCVPixelFormatType_32BGRA]; 
	NSDictionary* videoSettings = [NSDictionary dictionaryWithObject:value forKey:key]; 
	[captureOutput setVideoSettings:videoSettings]; 
	/*And we create a capture session*/
	captureSession = [[AVCaptureSession alloc] init];
	/*We add input and output*/
	[self.captureSession addInput:captureInput];
	[self.captureSession addOutput:captureOutput];
    
    [captureOutput release];
	
	/*We start the capture*/
	[self.captureSession startRunning];
}


#pragma mark -
#pragma mark AVCaptureSession delegate

- (void)captureOutput:(AVCaptureOutput *)captureOutput 
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer 
	   fromConnection:(AVCaptureConnection *)connection 
{ 
	/*We create an autorelease pool because as we are not in the main_queue our code is
	 not executed in the main thread. So we have to create an autorelease pool for the thread we are in*/
	
    //	CGFloat angleInRadians = -90 * (M_PI / 180);
	
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer); 
    /*Lock the image buffer*/
    CVPixelBufferLockBaseAddress(imageBuffer,0); 
    /*Get information about the image*/
    uint8_t *baseAddress = (uint8_t *)CVPixelBufferGetBaseAddress(imageBuffer); 
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer); 
    size_t width = CVPixelBufferGetWidth(imageBuffer); 
    size_t height = CVPixelBufferGetHeight(imageBuffer);  
    
    /*Create a CGImageRef from the CVImageBufferRef*/
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB(); 
    CGContextRef newContext = CGBitmapContextCreate(baseAddress, width, height, 8, bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    //	CGContextRotateCTM(newContext, -angleInRadians);
    CGImageRef newImage = CGBitmapContextCreateImage(newContext); 
	
    /*We release some components*/
    CGContextRelease(newContext); 
    CGColorSpaceRelease(colorSpace);
    
    /*We display the result on the custom layer. All the display stuff must be done in the main thread because
	 UIKit is no thread safe, and as we are not in the main thread (remember we didn't use the main_queue)
	 we use performSelectorOnMainThread to call our CALayer and tell it to display the CGImage.*/
	//[self.customLayer performSelectorOnMainThread:@selector(setContents:) withObject: (id) newImage waitUntilDone:YES];
	
    
	/*We display the result on the image view (We need to change the orientation of the image so that the video is displayed correctly).
	 Same thing as for the CALayer we are not in the main thread so ...*/
	UIImage *image= [UIImage imageWithCGImage:newImage scale:1 orientation:UIImageOrientationRight];
	
    //    + (UIImage *)imageWithCGImage:(CGImageRef)imageRef scale:(CGFloat)scale orientation:(UIImageOrientation)orientation
    
    
	/*We relase the CGImageRef*/
	CGImageRelease(newImage);
	
	[displayView performSelectorOnMainThread:@selector(setImage:) withObject:image waitUntilDone:YES];
	
	/*We unlock the  image buffer*/
	CVPixelBufferUnlockBaseAddress(imageBuffer,0);
	
	[pool drain];
} 

@end