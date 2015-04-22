/**
 * IoTLightView.m
 *
 * Copyright (c) 2014~2015 Xtreme Programming Group, Inc.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

#import "IoTLightView.h"
#import "IoTMainController.h"

@interface IoTLightView()

@property (strong, nonatomic) UIButton *button;
@property (strong, nonatomic) UILabel  *label;
@property (strong, nonatomic) UIButton *delBtn;

@end

@implementation IoTLightView

+ (instancetype)addButtonViewWithAction:(SEL)action addTarget:(id)target{
    //Container
    IoTLightView *view = [[IoTLightView alloc] initWithFrame:CGRectMake(0, 0, 60, 60)];

    //Icon
    view.button = [[UIButton alloc] init];
    view.button.frame = CGRectMake(0, 0, 60, 60);
    [view.button setImage:[UIImage imageNamed:@"icon-03"] forState:UIControlStateNormal];
    
    [view.button addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
    [view addSubview:view.button];
    return view;
}

//设置view
+ (instancetype)viewWithTitle:(NSString *)title WithTag:(NSInteger)tag action:(SEL)action target:(id)target{
    //Container
    IoTLightView *view = [[IoTLightView alloc] initWithFrame:CGRectMake(0, 0, 60, 60)];
    
    view.sdid = [NSString stringWithFormat:@"%ld",(long)tag];
   
    //Icon
    view.button = [[UIButton alloc] init];
    view.button.frame = CGRectMake(0, 0, 60, 60);
    [view.button setTag:tag];
    [view.button addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
    
    //Label
    view.label = [[UILabel alloc] initWithFrame:CGRectMake(0, 65, 60, 10)];
    view.label.text = title;
    view.label.font = [UIFont fontWithName:@"Helvetica" size:10.0];
    view.label.textColor = [UIColor whiteColor];
    
    //DelBtn
    view.delBtn = [[UIButton alloc] initWithFrame:CGRectMake(45, -5, 25, 25)];
    [view.delBtn setBackgroundImage:[UIImage imageNamed:@"icon-19"] forState:UIControlStateNormal];
    [view.delBtn addTarget:[IoTMainController currentController] action:@selector(onRemoveSubDev:) forControlEvents:UIControlEventTouchUpInside];
    [view.delBtn setHidden:YES];
    
    //Finish
    [view addSubview:view.button];
    [view addSubview:view.label];
    [view addSubview:view.delBtn];
    
    view.isLighting = NO;
    
    return view;
}

#pragma mark - Properties
- (void)setIsEditing:(BOOL)isEditing
{
    _isEditing = isEditing;
    self.delBtn.hidden = !_isEditing;
}

- (void)setIsLighting:(BOOL)isLighting
{
    _isLighting = isLighting;
    UIImage *btnImage = [UIImage imageNamed:isLighting?@"icon-02@2x":@"icon"];

    self.label.textColor = isLighting?[UIColor yellowColor]:[UIColor whiteColor];
    [self.button setImage:btnImage forState:UIControlStateNormal];
    self.button.selected = isLighting;
}

- (void)setIsEnabled:(BOOL)isEnabled
{
    _isEnabled = isEnabled;
    self.button.enabled = isEnabled;
    self.label.alpha = isEnabled?1:0.5;
}

@end
