//
//  OBSlider.m
//
//  Created by Ole Begemann on 02.01.11.
//  Copyright 2011 Ole Begemann. All rights reserved.
//
//  Original by Ole Begemann. Modifications applied by Luka Mirosevic. November 2012.

#define kMinimumTouchDisplacement 10.0

#import "OBSlider.h"

#import "GBToolbox.h"

@interface OBSlider ()

@property (assign, nonatomic, readwrite) float scrubbingSpeed;
@property (assign, nonatomic, readwrite) float realPositionValue;
@property (assign, nonatomic) CGPoint beganTrackingLocation;

@property (assign, nonatomic) BOOL isVirginTouch;

- (NSUInteger)indexOfLowerScrubbingSpeed:(NSArray*)scrubbingSpeedPositions forOffset:(CGFloat)verticalOffset;
- (NSArray *)defaultScrubbingSpeeds;
- (NSArray *)defaultScrubbingSpeedChangePositions;

@end


@implementation OBSlider

@synthesize scrubbingSpeed = _scrubbingSpeed;
@synthesize scrubbingSpeeds = _scrubbingSpeeds;
@synthesize scrubbingSpeedChangePositions = _scrubbingSpeedChangePositions;
@synthesize beganTrackingLocation = _beganTrackkingLocation;
@synthesize realPositionValue = _realPositionValue;

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        self.scrubbingSpeeds = [self defaultScrubbingSpeeds];
        self.scrubbingSpeedChangePositions = [self defaultScrubbingSpeedChangePositions];
        self.scrubbingSpeed = [[self.scrubbingSpeeds objectAtIndex:0] floatValue];
    }
    return self;
}


#pragma mark - custom accessors

-(CGFloat)vanillaValueForTouch:(UITouch *)touch {
    CGFloat proportion = [touch locationInView:self].x / self.bounds.size.width;
    proportion = ThresholdCGFloat(proportion, 0, 1);
    CGFloat value = self.minimumValue + proportion * (self.maximumValue - self.minimumValue);
    
    return value;
}


#pragma mark - NSCoding

- (id)initWithCoder:(NSCoder *)decoder
{
    self = [super initWithCoder:decoder];
    if (self != nil) 
    {
    	if ([decoder containsValueForKey:@"scrubbingSpeeds"]) {
            self.scrubbingSpeeds = [decoder decodeObjectForKey:@"scrubbingSpeeds"];
        } else {
            self.scrubbingSpeeds = [self defaultScrubbingSpeeds];
        }

        if ([decoder containsValueForKey:@"scrubbingSpeedChangePositions"]) {
            self.scrubbingSpeedChangePositions = [decoder decodeObjectForKey:@"scrubbingSpeedChangePositions"];
        } else {
            self.scrubbingSpeedChangePositions = [self defaultScrubbingSpeedChangePositions];
        }
        
        self.scrubbingSpeed = [[self.scrubbingSpeeds objectAtIndex:0] floatValue];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];

    [coder encodeObject:self.scrubbingSpeeds forKey:@"scrubbingSpeeds"];
    [coder encodeObject:self.scrubbingSpeedChangePositions forKey:@"scrubbingSpeedChangePositions"];
    
    // No need to archive self.scrubbingSpeed as it is calculated from the arrays on init
}


#pragma mark -
#pragma mark Touch tracking

- (BOOL)beginTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event {
    self.isVirginTouch = YES;
    
    // Set the beginning tracking location to the centre of the current
    // position of the thumb. This ensures that the thumb is correctly re-positioned
    // when the touch position moves back to the track after tracking in one
    // of the slower tracking zones.
    CGRect thumbRect = [self thumbRectForBounds:self.bounds 
                                      trackRect:[self trackRectForBounds:self.bounds]
                                          value:self.value];
    self.beganTrackingLocation = CGPointMake(thumbRect.origin.x + thumbRect.size.width / 2.0f, 
                                             thumbRect.origin.y + thumbRect.size.height / 2.0f); 
    self.realPositionValue = self.value;
    
    return YES;
}

- (BOOL)continueTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event {
    //get info about track
    CGPoint previousLocation = [touch previousLocationInView:self];
    CGPoint currentLocation  = [touch locationInView:self];
    CGFloat yDisplacement = currentLocation.y - previousLocation.y;
    CGFloat xDisplacement = currentLocation.x - previousLocation.x;
    CGFloat totalXDisplacement = currentLocation.x - self.beganTrackingLocation.x;
    
    //make sure that any predominantly downwards movements are ignored when it comes to changing the slider value
    BOOL ignoreCurrentMove = NO;
    
    //ignore move if it goes down more than it goes either left or right
    if (yDisplacement/ScalarAbsolute(xDisplacement) > 1.0) {
        ignoreCurrentMove = YES;
    }
    
    //make sure it doesnt start moving the slider until the movements become significant
    if (self.isVirginTouch) {
        if (ScalarAbsolute(totalXDisplacement) >= kMinimumTouchDisplacement) {
            self.isVirginTouch = NO;
        }
    }
    
    if (self.tracking && !ignoreCurrentMove) {
        // Find the scrubbing speed that curresponds to the touch's vertical offset
        CGFloat verticalOffset = fabsf(currentLocation.y - self.beganTrackingLocation.y);
        NSUInteger scrubbingSpeedChangePosIndex = [self indexOfLowerScrubbingSpeed:self.scrubbingSpeedChangePositions forOffset:verticalOffset];        
        if (scrubbingSpeedChangePosIndex == NSNotFound) {
            scrubbingSpeedChangePosIndex = [self.scrubbingSpeeds count];
        }
        self.scrubbingSpeed = [[self.scrubbingSpeeds objectAtIndex:scrubbingSpeedChangePosIndex - 1] floatValue];
         
        CGRect trackRect = [self trackRectForBounds:self.bounds];
        self.realPositionValue = self.realPositionValue + (self.maximumValue - self.minimumValue) * (xDisplacement / trackRect.size.width);
        
        CGFloat valueAdjustment = self.scrubbingSpeed * (self.maximumValue - self.minimumValue) * (xDisplacement / trackRect.size.width);
        CGFloat thumbAdjustment = 0.0f;
        if ( ((self.beganTrackingLocation.y < currentLocation.y) && (currentLocation.y < previousLocation.y)) ||
             ((self.beganTrackingLocation.y > currentLocation.y) && (currentLocation.y > previousLocation.y)) )
            {
            // We are getting closer to the slider, go closer to the real location
            thumbAdjustment = ([self vanillaValueForTouch:touch] - self.value) / (1 + fabsf(currentLocation.y - self.beganTrackingLocation.y));
        }
        self.value += valueAdjustment + thumbAdjustment;

        if (self.continuous) {
            [self sendActionsForControlEvents:UIControlEventValueChanged];
        }
    }
    return self.tracking;
}

- (void)endTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event
{
    if (self.tracking) 
    {
        self.scrubbingSpeed = [[self.scrubbingSpeeds objectAtIndex:0] floatValue];
        [self sendActionsForControlEvents:UIControlEventValueChanged];
    }
}


#pragma mark - Helper methods

// Return the lowest index in the array of numbers passed in scrubbingSpeedPositions 
// whose value is smaller than verticalOffset.
- (NSUInteger) indexOfLowerScrubbingSpeed:(NSArray*)scrubbingSpeedPositions forOffset:(CGFloat)verticalOffset 
{
    for (NSUInteger i = 0; i < [scrubbingSpeedPositions count]; i++) {
        NSNumber *scrubbingSpeedOffset = [scrubbingSpeedPositions objectAtIndex:i];
        if (verticalOffset < [scrubbingSpeedOffset floatValue]) {
            return i;
        }
    }
    return NSNotFound; 
}


#pragma mark - Default values

// Used in -initWithFrame: and -initWithCoder:
- (NSArray *) defaultScrubbingSpeeds
{
    return [NSArray arrayWithObjects:
            [NSNumber numberWithFloat:1.0f],
            [NSNumber numberWithFloat:0.5f],
            [NSNumber numberWithFloat:0.25f],
            [NSNumber numberWithFloat:0.1f],
            nil];
}

- (NSArray *) defaultScrubbingSpeedChangePositions
{
    return [NSArray arrayWithObjects:
            [NSNumber numberWithFloat:0.0f],
            [NSNumber numberWithFloat:50.0f],
            [NSNumber numberWithFloat:100.0f],
            [NSNumber numberWithFloat:150.0f],
            nil];
}

@end
