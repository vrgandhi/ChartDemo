//
//  GKLineGraph.m
//  GraphKit
//
//  Copyright (c) 2014 Michal Konturek
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

#import "GKLineGraph.h"
#import "BEMCircle.h"
#import "FrameAccessor.h"
#import "NSArray+MK.h"
#import "BEMAnimations.h"
#import "CMPopTipView.h"
#import "Utility.h"

static CGFloat kDefaultLabelWidth = 40.0;
static CGFloat kDefaultLabelHeight = 36.0;
static NSInteger kDefaultValueLabelCount = 5;

static CGFloat kDefaultLineWidth = 3.0;
static CGFloat kDefaultMargin = 10.0;
static CGFloat kDefaultMarginBottom = 20.0;

static CGFloat kAxisMargin = 50.0;

@interface GKLineGraph ()

@property (nonatomic, strong) NSArray *titleLabels;
@property (nonatomic, strong) NSArray *valueLabels;
/// The label displayed when enablePopUpReport is set to YES
@property (strong, nonatomic) UILabel *popUpLabel;

/// The view used for the background of the popup label
@property (strong, nonatomic) UIView *popUpView;

/// The X position (center) of the view for the popup label
@property (assign) CGFloat xCenterLabel;

/// The Y position (center) of the view for the popup label
@property (assign) CGFloat yCenterLabel;

@end

@implementation GKLineGraph

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self _init];
    }
    return self;
}

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self _init];
    }
    return self;
}

- (void)_init {
   
    self.animated = YES;
    self.animationDuration = 1;
    self.lineWidth = kDefaultLineWidth;
    self.margin = kDefaultMargin;
    self.valueLabelCount = kDefaultValueLabelCount;
    self.clipsToBounds = YES;
    
 
    
}

#pragma mark - Touch Gestures

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    if ([gestureRecognizer isEqual:self.panGesture]) {
        if (gestureRecognizer.numberOfTouches > 0) {
            CGPoint translation = [self.panGesture velocityInView:self.panView];
            return fabs(translation.y) < fabs(translation.x);
        } else {
            return NO;
        }
    }
    return YES;
}

- (void)handlePan:(UIPanGestureRecognizer *)recognizer {
    
    CGPoint translation = [recognizer locationInView:self.viewForBaselineLayout];

    if ((translation.x + self.frame.origin.x) <= self.frame.origin.x) { // To make sure the vertical line doesn't go beyond the frame of the graph.
        self.verticalLine.frame = CGRectMake(0, 20, 20, self.viewForBaselineLayout.frame.size.height-40);
    } else if ((translation.x + self.frame.origin.x) >= self.frame.origin.x + self.frame.size.width) {
        self.verticalLine.frame = CGRectMake(self.frame.size.width, 20, 20, self.viewForBaselineLayout.frame.size.height-40);
    } else {
        self.verticalLine.frame = CGRectMake(translation.x, 20, 20, self.viewForBaselineLayout.frame.size.height-4);
    }
    
    [UIView animateWithDuration:0.2 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        self.verticalLine.alpha = 0.2;
    } completion:nil];
    
    UIImageView *closestDot = [self closestDotFromVerticalLine:self.verticalLine];
 
    if (  closestDot.tag > 99 && closestDot.tag < 1000 && [closestDot isKindOfClass:[UIImageView class]]) {
       [self setUpPopUpLabelAbovePoint:closestDot.frame.origin index:closestDot.tag-100];
    }
    
    if (recognizer.state == UIGestureRecognizerStateEnded) {
        [UIView animateWithDuration:0.2 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
            //closestDot.alpha = 0;
            self.verticalLine.alpha = 0;
           // if (self.enablePopUpReport == YES) {
                self.popUpView.alpha = 0;
                self.popUpLabel.alpha = 0;
           // }
        } completion:nil];
    }

    

}

- (UIImageView *)closestDotFromVerticalLine:(UIView *)verticalLine {
 
    NSInteger currentlyCloser = pow((self.frame.size.width/([[self.dataSource valuesForLineAtIndex:0] count]-1))/2, 2);
    UIImageView *imgView;
    for (UIImageView *point in self.subviews) {
        if (point.tag > 99 && point.tag < 1000 && [point isKindOfClass:[UIImageView class]]) {
           // point.alpha = 0;
            if (pow(((point.center.x) - verticalLine.frame.origin.x), 2) < currentlyCloser) {
                currentlyCloser = pow(((point.center.x) - verticalLine.frame.origin.x), 2);
                imgView = point;
            }
        }
    }
    return imgView;
}

- (void)draw {
    NSAssert(self.dataSource, @"GKLineGraph : No data source is assgined.");
    
    self.verticalLine = [[UIView alloc] initWithFrame:CGRectMake(0, 20, 20, self.viewForBaselineLayout.frame.size.height-40)];
    self.verticalLine.backgroundColor = [UIColor grayColor];
    self.verticalLine.alpha = 0;
    [self addSubview:self.verticalLine];
    
    self.panView = [[UIView alloc] initWithFrame:CGRectMake(10, 10, self.viewForBaselineLayout.frame.size.width, self.viewForBaselineLayout.frame.size.height)];
    self.panView.backgroundColor = [UIColor clearColor];
    [self.viewForBaselineLayout addSubview:self.panView];
    
    self.panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    self.panGesture.delegate = self;
    [self.panGesture setMaximumNumberOfTouches:1];
    [self.panView addGestureRecognizer:self.panGesture];
    
    if ([self _hasTitleLabels]) [self _removeTitleLabels];
    [self _constructTitleLabels];
    [self _positionTitleLabels];

    if ([self _hasValueLabels]) [self _removeValueLabels];
    [self _constructValueLabels];
    [self _getpopup];
    [self _drawDots];
    [self _drawLines];
}

-(void)_getpopup
{
    self.popUpLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 40, 20)];
    self.popUpLabel.text = [NSString stringWithFormat:@"%@", [self calculateMaximumPointValue]];
    self.popUpLabel.textAlignment = 1;
    self.popUpLabel.numberOfLines = 1;
    self.popUpLabel.font = [UIFont fontWithName:@"SYSTEM" size:4.0f];
    self.popUpLabel.backgroundColor = [UIColor clearColor];
    [self.popUpLabel sizeToFit];
    self.popUpLabel.alpha = 0;
    
    self.popUpView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.popUpLabel.frame.size.width + 7, self.popUpLabel.frame.size.height + 2)];
    self.popUpView.backgroundColor = [UIColor whiteColor];
    self.popUpView.alpha = 0;
    self.popUpView.layer.cornerRadius = 3;
    [self addSubview:self.popUpView];
    [self addSubview:self.popUpLabel];
}

- (NSNumber *)calculateMaximumPointValue {
    NSExpression *expression = [NSExpression expressionForFunction:@"max:" arguments:@[[NSExpression expressionForConstantValue:[self.dataSource valuesForLineAtIndex:0]]]];
    NSNumber *value = [expression expressionValueWithObject:nil context:nil];
    
    return value;
}


- (BOOL)_hasTitleLabels {
    return ![self.titleLabels mk_isEmpty];
}

- (BOOL)_hasValueLabels {
    return ![self.valueLabels mk_isEmpty];
}

- (void)_constructTitleLabels {
    
    NSInteger count = [[self.dataSource valuesForLineAtIndex:0] count];
    id items = [NSMutableArray arrayWithCapacity:count];
    for (NSInteger idx = 0; idx < count; idx++) {
        
        CGRect frame = CGRectMake(0, 0, kDefaultLabelWidth, kDefaultLabelHeight);
        UILabel *item = [[UILabel alloc] initWithFrame:frame];
        item.textAlignment = NSTextAlignmentCenter;
        item.font = [UIFont boldSystemFontOfSize:10];
        item.textColor = [UIColor lightGrayColor];
        item.text = [self.dataSource titleForLineAtIndex:idx];
        item.numberOfLines = 3;
        [items addObject:item];
    }
    self.titleLabels = items;
}

- (void)_removeTitleLabels {
    [self.titleLabels mk_each:^(id item) {
        [item removeFromSuperview];
    }];
    self.titleLabels = nil;
}

- (void)_positionTitleLabels {
    
    __block NSInteger idx = 0;
    id values = [self.dataSource valuesForLineAtIndex:0];
    [values mk_each:^(id value) {
        
        CGFloat labelWidth = kDefaultLabelWidth;
        CGFloat labelHeight = kDefaultLabelHeight;
        CGFloat startX = [self _pointXForIndex:idx] - (labelWidth / 2);
        CGFloat startY = (self.height - labelHeight);
        
        UILabel *label = [self.titleLabels objectAtIndex:idx];
        label.x = startX;
        label.y = startY;
        
        [self addSubview:label];

        idx++;
    }];
}

- (CGFloat)_pointXForIndex:(NSInteger)index {
    return kAxisMargin + self.margin + (index * [self _stepX]);
}

- (CGFloat)_stepX {
    id values = [self.dataSource valuesForLineAtIndex:0];
    CGFloat result = ([self _plotWidth] / [values count]);
    return result;
}

- (void)_constructValueLabels {
    
    NSInteger count = self.valueLabelCount;
    id items = [NSMutableArray arrayWithCapacity:count];
    
    CGRect rect;
    

    
    for (NSInteger idx = 0; idx < count; idx++) {
        
        CGRect frame = CGRectMake(0, 0, kDefaultLabelWidth, kDefaultLabelHeight);
        UILabel *item = [[UILabel alloc] initWithFrame:frame];
        item.textAlignment = NSTextAlignmentRight;
        item.font = [UIFont boldSystemFontOfSize:12];
        item.textColor = [UIColor lightGrayColor];
    
        CGFloat value = [self _minValue] + (idx * [self _stepValueLabelY]);
        item.centerY = [self _positionYForLineValue:value];
        
        item.text = [@(ceil(value)) stringValue];
//        item.text = [@(value) stringValue];
        UIImageView *imgView = [[UIImageView alloc] initWithFrame:CGRectMake(item.frame.size.width + 10,item.centerY,self.frame.size.width -(item.frame.size.width + 10), 1)];
        imgView.image = [UIImage imageNamed:@"gray_line_graph.png"];
       // lineView.backgroundColor = item.textColor;
        [self addSubview:imgView];
        if (idx == count-1) {
            rect = item.frame;
        }
        [items addObject:item];
        [self addSubview:item];
    }
    /*
    UIImageView *imgView = [[UIImageView alloc] initWithFrame:CGRectMake(rect.size.width + 10,rect.origin.y+20,self.frame.size.width -(rect.size.width + 10)-50, 5)];
    imgView.image = [UIImage imageNamed:@"red_line_graph.png"];
    [self addSubview:imgView];
     */
    self.valueLabels = items;
}

- (CGFloat)_stepValueLabelY {
    return (([self _maxValue] - [self _minValue]) / (self.valueLabelCount - 1));
}

- (CGFloat)_maxValue {
    id values = [self _allValues];
    return [[values mk_max] floatValue];
}

- (CGFloat)_minValue {
    if (self.startFromZero) return 0;
    id values = [self _allValues];
    return [[values mk_min] floatValue];
}

- (NSArray *)_allValues {
    NSInteger count = [self.dataSource numberOfLines];
    id values = [NSMutableArray array];
    for (NSInteger idx = 0; idx < count; idx++) {
        id item = [self.dataSource valuesForLineAtIndex:idx];
        [values addObjectsFromArray:item];
    }
    return values;
}

- (void)_removeValueLabels {
    [self.valueLabels mk_each:^(id item) {
        [item removeFromSuperview];
    }];
    self.valueLabels = nil;
}

- (CGFloat)_plotWidth {
    return (self.width - (2 * self.margin) - kAxisMargin);
}

- (CGFloat)_plotHeight {
    return (self.height - (2 * kDefaultLabelHeight + kDefaultMarginBottom));
}

- (void)_drawLines {
    for (NSInteger idx = 0; idx < [self.dataSource numberOfLines]; idx++) {
        [self _drawLineAtIndex:idx];
    }
}

- (void)_drawDots {
    for (NSInteger idx = 0; idx < [self.dataSource numberOfLines]; idx++) {
        //if (idx ==0) {
            [self _drawdotAtIndex:idx];
        //}
    }
}

- (void)_drawdotAtIndex:(NSInteger)index {

    NSInteger idx = 0;
    id values = [self.dataSource valuesForLineAtIndex:index];
    for (id item in values) {
        
        CGFloat x = [self _pointXForIndex:idx];
        CGFloat y = [self _positionYForLineValue:[item floatValue]];
        
        if (isnan(y)) {
            y=186.0;
        }
        
        
        CGRect rect = CGRectMake(0, 0,7,7);
        UIGraphicsBeginImageContext(rect.size);
        CGContextRef context = UIGraphicsGetCurrentContext();
       
        CGContextSetFillColorWithColor(context, [[self.dataSource colorForLineAtIndex:index] CGColor]);
        // [[UIColor colorWithRed:77./255 green:184./255 blue: 72./255 alpha:1] CGColor]) ;
        CGContextFillRect(context, rect);
        UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        
        UIImageView *imgView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, img.size.width, img.size.height)];
        imgView.center = CGPointMake(x, y);
        imgView.image = img;
        
        CALayer * l = [imgView layer];
        [l setMasksToBounds:YES];
        [l setCornerRadius:3.5];
        
        // You can even add a border
        [l setBorderWidth:1.0];
        [l setBorderColor:(__bridge CGColorRef)([UIColor blackColor])];

         imgView.tag = idx+100;
        [self bringSubviewToFront:imgView];
        [self addSubview:imgView];
       // [self setUpPopUpLabelAbovePoint:point index:idx];
        idx++;
    }


}


- (void)setUpPopUpLabelAbovePoint:(CGPoint)closestPoint index:(NSInteger)i {
    
    //[self _getpopup];

    [UIView animateWithDuration:0.2 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        self.popUpView.alpha = 0.7;
        self.popUpLabel.alpha = 1;
    } completion:nil];
    
    self.xCenterLabel = closestPoint.x;
    self.yCenterLabel = closestPoint.y - 10/2 - 15;
    self.popUpView.center = CGPointMake(self.xCenterLabel, self.yCenterLabel);
    self.popUpLabel.center = self.popUpView.center;
    self.popUpLabel.text = [NSString stringWithFormat:@"%@", [[self.dataSource valuesForLineAtIndex:0] objectAtIndex:i]];
    
    if (self.popUpView.frame.origin.x <= 0) {
        self.xCenterLabel = self.popUpView.frame.size.width/2;
        self.popUpView.center = CGPointMake(self.xCenterLabel, self.yCenterLabel);
        self.popUpLabel.center = self.popUpView.center;
    } else if ((self.popUpView.frame.origin.x + self.popUpView.frame.size.width) >= self.frame.size.width) {
        self.xCenterLabel = self.frame.size.width - self.popUpView.frame.size.width/2;
        self.popUpView.center = CGPointMake(self.xCenterLabel, self.yCenterLabel);
        self.popUpLabel.center = self.popUpView.center;
    }
    if (self.popUpView.frame.origin.y <= 2) {
        self.yCenterLabel = closestPoint.y +10/2 + 15;
        self.popUpView.center = CGPointMake(self.xCenterLabel, closestPoint.y + 10/2 + 15);
        self.popUpLabel.center = self.popUpView.center;
    }
}


- (void)_drawLineAtIndex:(NSInteger)index {
    
    // http://stackoverflow.com/questions/19599266/invalid-context-0x0-under-ios-7-0-and-system-degradation
    UIGraphicsBeginImageContext(self.frame.size);
    
    UIBezierPath *path = [self _bezierPathWith:0];
    CAShapeLayer *layer = [self _layerWithPath:path];
    
    layer.strokeColor = [[self.dataSource colorForLineAtIndex:index] CGColor];
    
    [self.layer addSublayer:layer];
    
    NSInteger idx = 0;
    id values = [self.dataSource valuesForLineAtIndex:index];
    for (id item in values) {

        CGFloat x = [self _pointXForIndex:idx];
        CGFloat y = [self _positionYForLineValue:[item floatValue]];
        
       
        if (isnan(y)) {
            y=186;
//            switch (idx) {
//                case 0:
//                    y =186;
//                    break;
//                case 1:
//                    y =156;
//                    break;
//                case 2:
//                    y =126;
//                    break;
//                case 3:
//                    y =96;
//                    break;
//                case 4:
//                    y =66;
//                    break;
//                case 5:
//                    y =36;
//                    break;
//                default:
//                    y = 6 ;
//                    break;
//            }
        }
        CGPoint point = CGPointMake(x, y);
        
        if (idx != 0) [path addLineToPoint:point];
        [path moveToPoint:point];
        
        idx++;
    }
    
    layer.path = path.CGPath;
    
    if (self.animated) {
        CABasicAnimation *animation = [self _animationWithKeyPath:@"strokeEnd"];
        if ([self.dataSource respondsToSelector:@selector(animationDurationForLineAtIndex:)]) {
            animation.duration = [self.dataSource animationDurationForLineAtIndex:index];
        }
        [layer addAnimation:animation forKey:@"strokeEndAnimation"];
    }
    
    UIGraphicsEndImageContext();
}

- (CGFloat)_positionYForLineValue:(CGFloat)value {
    
    CGFloat scale;
    if (([self _maxValue] - [self _minValue]) == 0) {
        scale = 0;

    }
    else{
        scale = (value - [self _minValue]) / ([self _maxValue] - [self _minValue]);

    }
    CGFloat result = [self _plotHeight] * scale;
    result = ([self _plotHeight] -  result);
    result += kDefaultLabelHeight;
    return result;
}

- (UIBezierPath *)_bezierPathWith:(CGFloat)value {
    UIBezierPath *path = [UIBezierPath bezierPath];
    path.lineCapStyle = kCGLineCapRound;
    path.lineJoinStyle = kCGLineJoinRound;
    path.lineWidth = self.lineWidth;
    return path;
}

- (CAShapeLayer *)_layerWithPath:(UIBezierPath *)path {
    CAShapeLayer *item = [CAShapeLayer layer];
    item.fillColor = [[UIColor blackColor] CGColor];
    item.lineCap = kCALineCapRound;
    item.lineJoin  = kCALineJoinRound;
    item.lineWidth = self.lineWidth;
//    item.strokeColor = [self.foregroundColor CGColor];
    item.strokeColor = [[UIColor redColor] CGColor];
    item.strokeEnd = 1;
    return item;
}

- (CABasicAnimation *)_animationWithKeyPath:(NSString *)keyPath {
    CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:keyPath];
    animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    animation.duration = self.animationDuration;
    animation.fromValue = @(0);
    animation.toValue = @(1);
//    animation.delegate = self;
    return animation;
}

- (void)reset {
    self.layer.sublayers = nil;
    [self _removeTitleLabels];
    [self _removeValueLabels];
    self.verticalLine = nil;
    self.panGesture = nil;
    self.popUpLabel = nil;
    self.popUpView = nil;
}

@end
