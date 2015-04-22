/**
 * IoTLightViewCell.m
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

#import "IoTLightViewCell.h"
#import "IoTLightView.h"

#define SUB_LAMP_NAME(x) [NSString stringWithFormat:@"   LED%@",x]

@interface IoTLightViewCell()<XPGWifiGroupDelegate>{
    NSInteger selectedRow;
    NSInteger selectedSection;
}

@property (weak, nonatomic) IBOutlet UIView *groupView;
@property (weak, nonatomic) IBOutlet UIView *subDevView;
@property (weak, nonatomic) IBOutlet UIButton *subDevBtn;

@property (nonatomic, assign) IoTLightCellStyle           cellStyle;

@property (nonatomic, strong) XPGWifiCentralControlDevice *device;
@property (nonatomic, strong) UIButton                    *subDeviceBtn;
@property (nonatomic, strong) UIButton                    *addButton;

@property (nonatomic, strong) NSDictionary                *lampStatusDic;

//4.4 ChaoSo edit version
@property (nonatomic, strong) NSMutableDictionary         *remarkIsLight;
@property (nonatomic, strong) NSDictionary                *lightStatusDic;

@property (nonatomic, assign) BOOL                        isExpanded;

@end

@implementation IoTLightViewCell

#pragma mark - getViewsList
//获取子设备列表布局
- (NSArray *)getViewListForSubDeviceList:(NSArray *)subdevList HasAddButton:(BOOL)hasAddBtn {
    NSMutableArray *btnList;
    btnList = [[NSMutableArray alloc] init];
    BOOL isGroup = self.cellStyle == kIotGroupLightCell;
    
    for(id subDevObj in subdevList){
        NSString *sdid = nil;
        NSString *gsdid = nil;
        id target = nil;
        SEL selector = nil;
        
        if(isGroup)
        {
            //组
            sdid = subDevObj[@"sdid"];
            gsdid = self.firstKeyValDev[@"sdid"];
        }
        else
        {
            //子设备
            sdid = ((XPGWifiSubDevice *)subDevObj).subDid;
            target = [IoTMainController currentController];
            selector = @selector(onControlDeviceOrGroup:);
        }
        
        IoTLightView *view = [IoTLightView viewWithTitle:SUB_LAMP_NAME(sdid)
                                               WithTag:[sdid integerValue]
                                                action:selector
                                                target:target
                                             ];
        
        if(self.lightStatusDic != nil){
            view.isLighting = [self lightingStatusFromDict:self.lightStatusDic sdid:gsdid.length>0?gsdid:sdid];
            view.isEnabled = [self enableStatusFromDict:self.lightStatusDic sdid:gsdid.length>0?gsdid:sdid];
        }
        
        if(!isGroup)
        {
            view.isEditing = self.isEditing;
        }
        [btnList addObject:view];
    }
    
    if(!isGroup && (hasAddBtn || subdevList.count == 0)){
        IoTLightView *view = [IoTLightView addButtonViewWithAction:@selector(onAddSubDev:) addTarget:[IoTMainController currentController]];
        [btnList addObject:view];
    }
    return btnList;
}

#pragma mark 布局，排版
#define LINE_SUM 4
- (void)setLayoutAndSetViewWithView:(NSArray *)views{
    
    for (UIView *v in self.scrollView.subviews)
    {
        [v removeFromSuperview];
    }
    for (UIView *v in self.scrollSubDevList.subviews)
    {
        [v removeFromSuperview];
    }
    
    float x = 0;
    float h = 5;
    int i = 0;
    for (UIView *view in views){
        float cellPadding = ([UIScreen mainScreen].bounds.size.width - 20 - 4 * view.frame.size.width)/4;
        x += view.frame.size.width + view.frame.origin.x + cellPadding;
        if(i == 0){
            x = cellPadding /2 ;
        }
        if(i % 4 == 0 && i){
            h += view.frame.size.height + view.frame.origin.y + cellPadding + 20;
            x = cellPadding /2;
        }
        [view setFrame:CGRectMake(x, h, view.frame.size.width, view.frame.size.height)];
        if(selectedSection == 0){
            [self.scrollSubDevList addSubview:view];
        }else{
            [self.scrollView addSubview:view];
        }

        i++;
    }
}

- (int)getExpandedHeight{
    int row = 0;
    if (selectedSection == 0) {
        int count = (int)self.subDeviceList.count;
        if(count > 3){
            row = count / 3;
            if(count > row*3){
                row = row ;
            }
            else{
                row = row-1;
            }
        }
    }else if (selectedSection == 1){
        int count = (int)self.groupDevicesList.count;
        if(count > 4){
            row = count / 4;
            if(count > row*4){
                row = row ;
            }
            else{
                row = row-1;
            }
        }
    }
    
    return row * 100;
}

#pragma mark - actions
- (IBAction)onExpand:(id)sender {
    [self setIsExpanded:!self.isExpanded reload:YES];
}

- (void)setIsExpanded:(BOOL)isExpanded
{
    //添加分组，不处理展开
    if(nil != self.buttonExpand)
    {
        [self setIsExpanded:isExpanded reload:NO];
    }
}

- (void)setIsExpanded:(BOOL)isExpanded reload:(BOOL)reload
{
    if(selectedSection > 1)
        return;
    
    IoTMainController *mainController = [IoTMainController currentController];
    if(nil == mainController)
        return;
    
    NSArray *lists = @[mainController.cellHeightSubList, mainController.cellHeightList];
    NSArray *heights = @[@120, @140];
    NSInteger expandHeight = [self getExpandedHeight];
    NSInteger height = [heights[selectedSection] integerValue];
    
    lists[selectedSection][selectedRow] = isExpanded ? @(height + expandHeight) : @(height);
    
    if(reload)
    {
        NSIndexPath *indexPath = [mainController.tableView indexPathForCell:self];
        [mainController.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
    }
}

- (BOOL)isExpanded
{
    //添加分组，不处理展开
    if(nil != self.buttonExpand)
    {
        IoTMainController *mainController = [IoTMainController currentController];
        if(nil != mainController)
        {
            NSArray *lists = @[mainController.cellHeightSubList, mainController.cellHeightList];
            NSArray *heights = @[@120, @140];
            NSInteger oldVal = [lists[selectedSection][selectedRow] integerValue];
            NSInteger newVal = [heights[selectedSection] integerValue];
            return oldVal > newVal;
        }
    }
    return NO;
    
}

- (IBAction)onDeleteGroup:(id)sender {
    [[XPGWifiSDK sharedInstance] removeGroup:[IoTProcessModel sharedModel].currentUid
                                       token:[IoTProcessModel sharedModel].currentToken
                                         gid:self.selectedGroup.gid];
    
    [[IoTMainController currentController].tableView reloadData];
}

//分享数据
- (void)updateCellWithSubDevsList:(NSArray *)subDeviceList WithGroupList:(NSArray *)groupList WithIndexPath:(NSIndexPath *)indexPath Style:(IoTLightCellStyle)style lightStatus:(NSDictionary *)lightStatus
{
    BOOL isSubLight = (style == kIotSubLightCell);
    
    self.lightStatusDic = lightStatus;
    self.cellStyle = style;
    
    //必备的数据
    self.subDeviceList = subDeviceList;
    self.groupList = groupList;
    selectedRow = indexPath.row;
    selectedSection = indexPath.section;
    
    //UI设置
    self.scrollView.userInteractionEnabled = NO;
    self.scrollSubDevList.userInteractionEnabled = YES;
    self.deleteBtn.hidden = YES;
    
    [self.lineView setHidden:isSubLight];
    [self.labelName setHidden:isSubLight];
    [self.groupView setHidden:isSubLight];
    [self.subDevView setHidden:!isSubLight];
    
    if(style == kIotSubLightCell)
    {
        //当显示子设备列表的时候
        //UI设置
        self.isExpanded = self.isExpanded;
        [self updateCellViewWithName:@"" WithDeviceList:self.subDeviceList];
    }
    else //if(style == kIotSubLightCell)
    {
        //当显示分组列表时候
        //设定 delegate
        if(selectedRow < groupList.count){
            self.selectedGroup = groupList[selectedRow];
        }
        if(self.selectedGroup){
            [self.selectedGroup setDelegate:self];
            [self.selectedGroup getDevices];
        }else{
            NSLog(@"%s: Here are no groups", __func__);
        }
        //UI设置
        [self.buttonExpand setHidden:NO];
    }
    
    self.buttonExpand.selected = self.isExpanded;
    self.buttonGroupExpand.selected = self.isExpanded;
}

- (void)updateCellViewWithName:(NSString *)name WithDeviceList:(NSArray *)devicesList{
    self.labelName.text = name;
    dispatch_async(dispatch_get_main_queue(), ^{
        NSArray *viewsList = nil;
        BOOL hasAddButton = NO;

        //子设备
        if([devicesList[0] isKindOfClass:[XPGWifiSubDevice class]] || devicesList.count == 0){
            hasAddButton = !self.isEditing;
        }
        viewsList = [self getViewListForSubDeviceList:devicesList HasAddButton:hasAddButton];
        
        if(viewsList != nil)
        {
            [self setLayoutAndSetViewWithView:viewsList];
        }
    });
}

#pragma mark property
- (void)setIsEditing:(BOOL)isEditing
{
    _isEditing = isEditing;
    if(self.cellStyle == kIotGroupLightCell)
    {
        [self.deleteBtn setHidden:!isEditing];
    }
    else //if(self.cellStyle == kIotSubLightCell)
    {
        //这里无法设置
    }
}

#pragma mark - light status dict
- (NSDictionary *)devStatusFromDict:(NSDictionary *)dict sdid:(NSString *)sdid
{
    if(nil == dict || ![dict isKindOfClass:[NSDictionary class]])
    {
        NSLog(@"%s Error: invalid dict, default return NO.", __func__);
        return nil;
    }
    
    if(nil == sdid || ![sdid isKindOfClass:[NSString class]])
    {
        NSLog(@"%s Error: invalid sdid, default return NO.", __func__);
        return nil;
    }
    
    NSDictionary *rdict = dict[sdid];
    if([rdict isKindOfClass:[NSDictionary class]])
        return rdict;
    return nil;
}

- (BOOL)booleanStatusFromDict:(NSDictionary *)dict sdid:(NSString *)sdid key:(NSString *)key defaultValue:(BOOL)defaultValue
{
    NSDictionary *sdict = [self devStatusFromDict:dict sdid:sdid];
    if(nil == sdict)
        return defaultValue;
    
    NSNumber *number = sdict[key];
    if(![number isKindOfClass:[NSNumber class]])
        return defaultValue;
    return [number boolValue];
}

- (BOOL)lightingStatusFromDict:(NSDictionary *)dict sdid:(NSString *)sdid
{
    return [self booleanStatusFromDict:dict sdid:sdid key:LIGHT_STATUS_KEY_ONOFF defaultValue:NO];
}

- (BOOL)enableStatusFromDict:(NSDictionary *)dict sdid:(NSString *)sdid
{
    return [self booleanStatusFromDict:dict sdid:sdid key:LIGHT_STATUS_KEY_ONLINE defaultValue:YES];
}

#pragma mark - delegates
- (void)XPGWifiGroup:(XPGWifiGroup *)group didGetDevices:(NSArray *)deviceList result:(int)result
{
    self.groupDevicesList = deviceList;
    self.firstKeyValDev = deviceList.firstObject;
    self.isExpanded = self.isExpanded;
    
    [self updateCellViewWithName:self.selectedGroup.groupName WithDeviceList:deviceList];
}

@end
