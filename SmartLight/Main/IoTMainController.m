/**
 * IoTMainController.m
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

#import "IoTMainController.h"
#import "IoTAlertView.h"
#import "IoTMainMenu.h"
#import "IoTConfigurationCtrl.h"
#import "IoTAddGroupCtrl.h"
#import "SSPullToRefresh.h"
#import "IoTLightViewCell.h"
#import "IoTLightView.h"

#define COMMAND_DELAY   250000
#define RECEIVE_DELAY   500000

//#define REQUEST_TIMEOUT 30
#define REQUEST_TIMEOUT 5

#define LIGHT_ENTITY    @"entity0"

@interface IoTMainController () <XPGWifiSDKDelegate, XPGWifiGroupDelegate, SSPullToRefreshViewDelegate, UITableViewDataSource, UITableViewDelegate>

@property (weak, nonatomic) IBOutlet UIView   *actionView;

@property (weak, nonatomic) IBOutlet UISlider *lightSlider;
@property (weak, nonatomic) IBOutlet UIButton *onButtonSwitch;
@property (weak, nonatomic) IBOutlet UILabel  *lightLabel;

@property (weak, nonatomic) IBOutlet UILabel  *labelOnOff;
@property (weak, nonatomic) IBOutlet UIButton *buttonEditGroup;

//单个设备
@property (nonatomic, strong) XPGWifiSubDevice    *subDevice;

//组
@property (nonatomic, strong) XPGWifiGroup        *selectedGroup;
@property (nonatomic, strong) NSArray             *selectedGroupDevices;

//对应的分组列表数据
@property (nonatomic, strong) NSArray             *groupList;
@property (nonatomic, strong) NSArray             *subDeviceList;

//编辑状态
@property (nonatomic        ) BOOL                isEditing;
@property (nonatomic, assign) BOOL                isGroup;

//下拉刷新
@property (nonatomic, strong) SSPullToRefreshView *pullToRefreshView;

//设备更新状态锁，防止列表刷新过快
@property (assign           ) BOOL                isDiscoverLock;

//设备状态
@property (nonatomic, strong) NSMutableDictionary *lightStatusDic;

@end

@implementation IoTMainController

- (id)initWithDevice:(XPGWifiCentralControlDevice *)device
{
    self = [super init];
    if(self)
    {
        if(device.type == XPGWifiDeviceTypeCenterControl)
        {
            self.device = (XPGWifiCentralControlDevice *)device;
        }
        else
        {
            NSLog(@"error: device type is not center control.");
            return nil;
        }
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    //开始时必须初始化，另外如果组发生变化时，再更新一次
    [self initCellLists];

    self.lightStatusDic = [[NSMutableDictionary alloc] init];
    [self hideActionView:NO];

    self.navigationItem.title = @"智能灯";
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"icon_menu"] style:UIBarButtonItemStylePlain target:[SlideNavigationController sharedInstance] action:@selector(toggleLeftMenu)];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"icon-06.png"] style:UIBarButtonItemStylePlain target:self action:@selector(onEdit)];
    
    [self.lightSlider setMinimumTrackImage:[UIImage imageNamed:@"hua-34"] forState:(UIControlStateNormal)];
    [self.lightSlider setMaximumTrackImage:[UIImage imageNamed:@"hua"] forState:(UIControlStateNormal)];
    self.lightSlider.continuous = NO;

    //下拉刷新
    self.pullToRefreshView = [[SSPullToRefreshView alloc] initWithScrollView:self.tableView delegate:self];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    //设置委托
    self.device.delegate = self;
    [XPGWifiSDK sharedInstance].delegate = self;
    for(XPGWifiSubDevice *subDevice in self.subDeviceList)
        subDevice.delegate = self;

    //设备已解除绑定，或者断开连接，退出
    if(![self.device isBind:[IoTProcessModel sharedModel].currentUid] || !self.device.isConnected)
    {
        [self onDisconnected];
        return;
    }
    
    //更新侧边菜单数据
    [((IoTMainMenu *)[SlideNavigationController sharedInstance].leftMenu).tableView reloadData];

    //在页面加载后，自动更新数据
    if(self.device.isOnline && self.actionView.hidden == YES)
    {
        [self reloadDataWithProgress];
    }
}

- (void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    [self hideActionView:YES];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    self.groupList = nil;
    self.subDevice.delegate = nil;
    if([self.navigationController.viewControllers indexOfObject:self] > self.navigationController.viewControllers.count)
    {
        [self cleanSubDeviceList];
        self.device.delegate = nil;
        self.isGroup = NO;
    }
    [XPGWifiSDK sharedInstance].delegate = nil;
}

#pragma mark - actions
- (void)cleanSubDeviceList
{
    for(XPGWifiSubDevice *subDevice in self.subDeviceList)
        subDevice.delegate = nil;

    self.subDevice = nil;
    self.subDeviceList = nil;
}

- (void)reloadDataWithProgress
{
    IoTAppDelegate.hud.labelText = @"正在更新数据...";
    [IoTAppDelegate.hud showAnimated:YES whileExecutingBlock:^{
        sleep(REQUEST_TIMEOUT);
    }];
    
    [self reload];
}

- (void)reload
{
    //清理选中的状态
    [self cleanSubDeviceList];
    self.groupList = nil;
    
    [[XPGWifiSDK sharedInstance] getGroupsWithUid:[[IoTProcessModel sharedModel] currentUid] token:[[IoTProcessModel sharedModel] currentToken] specialProductKeys:nil];
    [self.device getSubDevices];
}

- (void)updateActionStatus:(NSDictionary *)dict sdid:(NSString *)sdid
{
    if(self.actionView.hidden == NO)
    {
        NSDictionary *devStatusDic = dict[sdid];
        self.lightSlider.value = [devStatusDic[LIGHT_STATUS_KEY_LIGHTNESS] floatValue];
        [self setOnSwitch:[devStatusDic[LIGHT_STATUS_KEY_ONOFF] boolValue]];
    }
}

#pragma mark - Control Device(s)
//电灯开关
- (void)sendSwitch:(XPGWifiSubDevice *)dev {
    NSLog(@"selected === %d",self.onButtonSwitch.selected);
    [dev write:@{@"cmd":@1,
                 LIGHT_ENTITY:@{LIGHT_STATUS_KEY_ONOFF: @(self.onButtonSwitch.selected)}}];
}

//电灯亮度
- (void)sendSlider:(XPGWifiSubDevice *)dev {
    [dev write:@{@"cmd":@1,
                 LIGHT_ENTITY:@{LIGHT_STATUS_KEY_LIGHTNESS: @((int)(self.lightSlider.value))}}];
}

- (void)sendValue:(XPGWifiSubDevice *)dev isOnOff:(BOOL)isOnOff {
    if(isOnOff) {
        [self sendSwitch:dev];
    } else {
        [self sendSlider:dev];
    }
}

- (void)sendGroupData:(NSDictionary *)dict{
    NSArray *deviceList = dict[@"devices"];
    BOOL isOnOff = [dict[@"isOnOff"] boolValue];
    for (NSDictionary *dic in deviceList){
        NSString *sdid = [dic objectForKey:@"sdid"];
        for(int i=(int)self.subDeviceList.count; i>0; i--){
            XPGWifiSubDevice *dev = self.subDeviceList[i-1];
            if([dev.subDid isEqualToString:sdid]){
                [self sendValue:dev isOnOff:isOnOff];
                usleep(COMMAND_DELAY);
            }
        }
    }
}

- (void)onValueChanged:(BOOL)isOnOff {
    IoTAppDelegate.hud.labelText = @"请稍侯...";
    [IoTAppDelegate.hud showAnimated:YES whileExecutingBlock:^{
        sleep(REQUEST_TIMEOUT);
    }];
    
    if(_isGroup)
    {
        //组控制
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
            if(!self.selectedGroupDevices)
                self.selectedGroupDevices = @[];
            NSDictionary *data = @{@"devices": self.selectedGroupDevices,
                                   @"isOnOff": @(isOnOff)};
            [self performSelectorOnMainThread:@selector(sendGroupData:) withObject:data waitUntilDone:YES];
        });
    }
    else
    {
        //单个设备控制
        [self sendValue:self.subDevice isOnOff:isOnOff];
    }
}

- (IBAction)onSliderValueChanged:(id)sender {
    [self onValueChanged:NO];
}

- (IBAction)onButtonSwitch:(UIButton *)sender {
    sender.selected = !sender.selected;
    [self onValueChanged:YES];
}

- (void)setOnSwitch:(BOOL)isSwitch
{
    self.onButtonSwitch.selected = isSwitch;
    self.labelOnOff.text = isSwitch?@"开灯":@"关灯";
}

#pragma mark - Actions
- (void)onDisconnected {
    //断线且页面在控制页面时才弹框
    UIViewController *currentController = self.navigationController.viewControllers.lastObject;
    
    if(!self.device.isConnected &&
       [currentController isKindOfClass:[IoTMainController class]])
    {
        [IoTAppDelegate.hud hide:YES];
        [[[IoTAlertView alloc] initWithMessage:@"连接已断开" delegate:nil titleOK:@"确定"] show:YES];
        [self onExitToDeviceList];
    }
    else {
        [self onDeviceLogin];
    }
}

//退出到列表
- (void)onExitToDeviceList{
    UIViewController *currentController = self.navigationController.viewControllers.lastObject;
    for(int i=(int)(self.navigationController.viewControllers.count-1); i>0; i--)
    {
        UIViewController *controller = self.navigationController.viewControllers[i];
        if(([controller isKindOfClass:[IoTDeviceList class]] && [currentController isKindOfClass:[IoTMainController class]]))
        {
            [self.navigationController popToViewController:controller animated:YES];
        }
    }
}

//设备登陆
- (void)onDeviceLogin{
    [_device login:[IoTProcessModel sharedModel].currentUid token:[IoTProcessModel sharedModel].currentToken];
}

- (void)onFinishedLoadingDatas
{
    //读完设备数据、分组数据后，重刷列表，结束刷新状态
    if(nil != self.groupList && nil != self.subDeviceList)
    {
        [self.pullToRefreshView finishLoading];
        [IoTAppDelegate.hud hide:YES];
    }
    [self.tableView reloadData];
}

#pragma mark - Device manager
- (void)onEdit {
    self.isEditing = !self.isEditing;
    self.navigationItem.rightBarButtonItem.image = [UIImage imageNamed:self.isEditing ? @"icon-14.png" : @"icon-06.png"];
    [self.tableView reloadData];
}

- (IBAction)onEditGroup:(id)sender {
    IoTAddGroupCtrl *addGroupCtrl = [[IoTAddGroupCtrl alloc] initWithDevices:self.subDeviceList WithGid:_selectedGroup.gid isEditable:YES];
    [self.navigationController pushViewController:addGroupCtrl animated:YES];
}

- (void)onAddSubDev:(id)sender{
    if(self.device.isOnline)
    {
        IoTConfigurationCtrl *addPage = [[IoTConfigurationCtrl alloc] initWithCentralControlDevice:self.device];
        [self.navigationController pushViewController:addPage animated:YES];
    }
}

- (void)onRemoveSubDev:(UIButton *)sender{
    IoTLightView *view = (IoTLightView *)sender.superview;
    [self.device deleteSubDevice:view.sdid];
    
    [self.tableView reloadData];
}

- (void)onControlDeviceOrGroup:(UIButton *)sender{
    if(!self.isEditing){
        NSString *sdid = [NSString stringWithFormat:@"%@", @(sender.tag)];
        XPGWifiSubDevice *subDev = [AppDelegate getWifiSubDeviceFromList:_subDeviceList sdid:sdid];
        [self showActionView:YES WithDev:subDev WithName:subDev.subDid];
    }
}

#pragma mark - Common methods
+ (IoTMainController *)currentController
{
    SlideNavigationController *navCtrl = [SlideNavigationController sharedInstance];
    for(int i=(int)(navCtrl.viewControllers.count-1); i>0; i--)
    {
        if([navCtrl.viewControllers[i] isKindOfClass:[IoTMainController class]])
            return navCtrl.viewControllers[i];
    }
    return nil;
}

//初始化 组列表、子设备列表收缩时对应的高度值
- (void)initCellLists {
    //isHeightList
    //YES ：组列表
    //NO ： 子设备列表
    BOOL isHeightList = NO;
    
    //初始化、清理
    if(nil == _cellHeightSubList)
        _cellHeightSubList = [[NSMutableArray alloc] init];
    if(nil == _cellHeightList)
        _cellHeightList = [[NSMutableArray alloc] init];
    
    [_cellHeightList removeAllObjects];
    [_cellHeightSubList removeAllObjects];
    
    do {
        NSArray *groupList = self.groupList;
        NSMutableArray *cellList = _cellHeightList;
        NSNumber *height = @140;
        NSUInteger count = (groupList.count == 0) ? 1 : groupList.count;
        
        if(!isHeightList)
        {
            //子设备列表
            groupList = nil;
            cellList = _cellHeightSubList;
            height = @120;
        }
        
        for (int i=0; i < count; i++)
        {
            [cellList addObject:height];
        }
        
        isHeightList = !isHeightList;
    }while (isHeightList == YES);
}

#pragma mark - Control manager
- (IBAction)tapHideView:(id)sender {
    [self hideActionView:YES];
}

- (void)showActionView:(BOOL)animated WithDev:(XPGWifiSubDevice *)dev WithName:(NSString *)name{
    if(animated)
    {
        [UIView beginAnimations:nil context:nil];
        [UIView setAnimationCurve:UIViewAnimationCurveEaseIn];
    }
    
    self.subDevice = dev;
    self.actionView.hidden = NO;
    self.lightLabel.text = name;
    [self updateActionStatus:self.lightStatusDic sdid:dev.subDid];
    self.buttonEditGroup.hidden = !_isGroup;
    
    if(animated)
    {
        [UIView commitAnimations];
    }
}

- (void)hideActionView:(BOOL)animated{
    if(animated)
    {
        [UIView beginAnimations:nil context:nil];
        [UIView setAnimationCurve:UIViewAnimationCurveEaseOut];
    }
    
    _isGroup = NO;
    self.actionView.hidden = YES;
    
    if(animated)
    {
        [UIView commitAnimations];
    }

    self.subDevice = nil;
    self.selectedGroup = nil;
    self.selectedGroupDevices = nil;
    [self.tableView reloadData];
}

#pragma mark - SDK delegate
- (BOOL)XPGWifiDevice:(XPGWifiDevice *)device didReceiveData:(NSDictionary *)data result:(int)result
{
    BOOL isSubDevice = device.type == XPGWifiDeviceTypeSub;
    if(!isSubDevice)
        return YES;
    
    NSString *sdid = ((XPGWifiSubDevice *)device).subDid;
    
    BOOL isCurrentSubDevice = nil != self.subDevice && ![self.subDevice.subDid isEqualToString:sdid];
    
    //过滤不是当前设备的状态
    if(!self.isGroup && isCurrentSubDevice)
        return YES;
    
    NSDictionary *_data = data[@"data"];
    
    //数据点处理
    NSDictionary *entity0 = _data[LIGHT_ENTITY];
    BOOL isOnOff = [entity0[LIGHT_STATUS_KEY_ONOFF] boolValue];
    NSInteger lightness = [entity0[LIGHT_STATUS_KEY_LIGHTNESS] integerValue];
    
    //更新到UI
    [self.lightStatusDic setObject:
  @{LIGHT_STATUS_KEY_ONOFF: @(isOnOff),
    LIGHT_STATUS_KEY_LIGHTNESS: @(lightness),
    LIGHT_STATUS_KEY_ONLINE:@(device.isOnline)} forKey:sdid];
    [self updateActionStatus:[self.lightStatusDic copy]
                        sdid:sdid];
    
    //延迟刷新，如果在刷新中，则不频繁触发刷新
    if(!self.isDiscoverLock)
    {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
            self.isDiscoverLock = YES;
            usleep(RECEIVE_DELAY);
            [self.tableView performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:YES];
            [IoTAppDelegate.hud performSelectorOnMainThread:@selector(hide:) withObject:@YES waitUntilDone:YES];
            self.isDiscoverLock = NO;
        });
    }
    
    return YES;
}

- (void)XPGWifiSDK:(XPGWifiSDK *)wifiSDK didGetGroups:(NSArray *)groupList result:(int)result
{
    self.groupList = groupList;
    if(self.groupList.count == 0)
       self.groupList = @[];
    
    for(XPGWifiGroup *group in self.groupList)
        group.delegate = self;
    
    NSLog(@"didGetGroups:%@", self.groupList);
    [self initCellLists];
    [self onFinishedLoadingDatas];
}

- (void)XPGWifiSDK:(XPGWifiSDK *)wifiSDK didUnbindDevice:(NSString *)did error:(NSNumber *)error errorMessage:(NSString *)errorMessage
{
    //解绑事件
    if([error intValue] == XPGWifiError_NONE)
    {
        [[[UIAlertView alloc] initWithTitle:@"提示" message:@"解除绑定成功" delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil] show];
        [self.navigationController popViewControllerAnimated:YES];
    }
}

#pragma mark - XPGWifiDeviceDelegate
- (void)XPGWifiDeviceDidDisconnected:(XPGWifiDevice *)device
{
    if(![device.did isEqualToString:self.device.did] || self.device.isConnected)
        return;
    [self onDisconnected];
}

- (void)XPGWifiCentralControlDevice:(XPGWifiCentralControlDevice *)wifiCentralControlDevice didDiscovered:(NSArray *)subDeviceList result:(int)result
{
    self.subDeviceList = subDeviceList;
    if(self.subDeviceList.count == 0)
    {
        self.subDeviceList = @[];
    }
    
    for(XPGWifiSubDevice *subDevice in self.subDeviceList)
        subDevice.delegate = self;
    
    NSLog(@"didDiscovered:%@", self.subDeviceList);
    //获取所有设备状态
    for(XPGWifiSubDevice *dev in self.subDeviceList){
        [dev write:@{@"cmd":@2}];
        usleep(COMMAND_DELAY);
    }
    
    [self onFinishedLoadingDatas];
}

#pragma mark - tableView
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView{
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if(section == 0)
    {
        return 1;
    }
    return self.groupList.count + !self.isEditing;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *groupCellIdentifier = @"IoTGroupCell";
    static NSString *addCellIdentifier = @"IoTAddCell";
    static NSString *className = @"IoTLightViewCell";
    
    UITableViewCell *cell = nil;
    IoTLightCellStyle lightStyle = kIotSubLightCell;
    
    //分组新增设备
    if (indexPath.section == 1 && indexPath.row == self.groupList.count)
    {
        cell = [tableView dequeueReusableCellWithIdentifier:addCellIdentifier];
        if(cell == nil)
        {
            cell = [[[NSBundle mainBundle] loadNibNamed:className owner:nil options:nil] lastObject];
        }
    }
    //分组列表
    else
    {
        //非子设备组
        if(indexPath.section != 0)
            lightStyle = kIotGroupLightCell;
        
        //子设备和组设备调用一样的方法
        cell = [tableView dequeueReusableCellWithIdentifier:groupCellIdentifier];
        if(cell == nil)
        {
            cell = [[[NSBundle mainBundle] loadNibNamed:className owner:nil options:nil] firstObject];
        }
    }
    
    IoTLightViewCell *lightCell = (IoTLightViewCell *)cell;
    if([lightCell isMemberOfClass:[IoTLightViewCell class]])
    {
        [lightCell updateCellWithSubDevsList:self.subDeviceList
                               WithGroupList:self.groupList
                               WithIndexPath:indexPath
                                       Style:lightStyle
                                 lightStatus:self.lightStatusDic];
        lightCell.isEditing = self.isEditing;
    }

    return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    switch (section) {
        case 0:
            return @"我的LED";
        case 1:
            return @"我的分组";
        default:
            break;
    }
    return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section{
    return 30;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    CGFloat height = 120;
    
    switch (indexPath.section) {
        case 0:
            height = [[_cellHeightSubList objectAtIndex:indexPath.section] integerValue];
            break;
        case 1:
            if(indexPath.row != self.groupList.count)
            {
                height = [[_cellHeightList objectAtIndex:indexPath.row] integerValue];
            }
        default:
            break;
    }

    return height;
}

- (BOOL)tableView:(UITableView *)tableView shouldHighlightRowAtIndexPath:(NSIndexPath *)indexPath
{
    if(indexPath.section == 0)
        return NO;
    
    if(indexPath.row == self.groupList.count)
        return YES;
    
    IoTLightViewCell *lightCell = (IoTLightViewCell *)[tableView cellForRowAtIndexPath:indexPath];
    
    XPGWifiSubDevice *dev = [AppDelegate getWifiSubDeviceFromList:_subDeviceList sdid:lightCell.firstKeyValDev[@"sdid"]];
    return dev.isOnline;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:NO];
    if (indexPath.section == 1 && indexPath.row == self.groupList.count) {
        if(indexPath.row == self.groupList.count){
            if (self.subDeviceList) {
                IoTAddGroupCtrl *addGroupCtrl = [[IoTAddGroupCtrl alloc] initWithDevices:self.subDeviceList WithGid:nil isEditable:NO];
                [self.navigationController pushViewController:addGroupCtrl animated:YES];
            }
        }
    }else if(indexPath.section == 1){
        IoTLightViewCell *lightCell = (IoTLightViewCell *)[tableView cellForRowAtIndexPath:indexPath];
        XPGWifiSubDevice *dev = [AppDelegate getWifiSubDeviceFromList:_subDeviceList sdid:lightCell.firstKeyValDev[@"sdid"]];
        if(dev != nil){
            _isGroup = YES;
            self.selectedGroupDevices = lightCell.groupDevicesList;
            [self showActionView:NO WithDev:dev WithName:lightCell.selectedGroup.groupName];
            self.selectedGroup = [self.groupList objectAtIndex:indexPath.row];
        }
    }
}

- (void)XPGWifiGroup:(XPGWifiGroup *)group didGetDevices:(NSArray *)deviceList result:(int)result
{
    if (result == 0){
        //当前设备的 enabled 状态立即更新
        for(XPGWifiSubDevice *subDevice in deviceList)
        {
            [self.lightStatusDic setObject:
             @{LIGHT_STATUS_KEY_ONLINE:@(subDevice.isOnline)} forKey:subDevice.subDid];
        }
    }
}

#pragma mark - pull to refresh
- (void)pullToRefreshViewDidStartLoading:(SSPullToRefreshView *)view
{
    if(self.device.isOnline)
    {
        [self reload];
    }
    else
    {
        [self.pullToRefreshView finishLoading];
    }
}

@end
