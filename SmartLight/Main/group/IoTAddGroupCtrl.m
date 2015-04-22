/**
 * IoTAddGroupCtrl.m
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

#import "IoTAddGroupCtrl.h"
#import "CategorySliderView.h"
#import "IoTCollectionViewCell.h"
#import "IoTMainController.h"

#define cellIdentified @"SelectedCell"

@interface IoTAddGroupCtrl ()<XPGWifiSDKDelegate,XPGWifiGroupDelegate,UICollectionViewDataSource,UICollectionViewDelegate,UITextFieldDelegate>
{
    NSArray* devices;
    NSString *selectedGid;
    BOOL isAddGroup;
}

@property (weak, nonatomic) IBOutlet UITextField      *textFieldGroupName;
@property (weak, nonatomic) IBOutlet UICollectionView *selectedCollectionView;

@property (strong, nonatomic) CategorySliderView *sliderView;
@property (strong, nonatomic) NSMutableArray     *selectedDevices;
@property (strong, nonatomic) NSMutableArray     *sliderViewList;
@property (strong, nonatomic) NSArray            *groupList;

@property (assign, nonatomic) BOOL               isEditable;

@end

@implementation IoTAddGroupCtrl

- (id)initWithDevices:(NSArray *)deviceList WithGid:(NSString *)gid isEditable:(BOOL)isEditable
{
    self = [super init];
    if (self) {
        selectedGid = gid;
        devices = [NSMutableArray arrayWithArray:deviceList];
        self.isEditable = isEditable;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.title = @"智能灯";
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"return_icon"] style:(UIBarButtonItemStylePlain) target:self action:@selector(onBack)];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"icon-14.png"] style:(UIBarButtonItemStylePlain) target:self action:@selector(onAddGroupWithName)];
    UIColor *color = [UIColor whiteColor];
    self.textFieldGroupName.attributedPlaceholder = [[NSAttributedString alloc] initWithString:@"分组名称" attributes:@{NSForegroundColorAttributeName: color}];
    
    //指定xib文件
    UINib *nib = [UINib nibWithNibName:@"IoTCollectionViewCell" bundle:nil];
    [self.selectedCollectionView registerNib:nib forCellWithReuseIdentifier:cellIdentified];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [XPGWifiSDK sharedInstance].delegate = self;
    [[XPGWifiSDK sharedInstance] getGroupsWithUid:[[IoTProcessModel sharedModel] currentUid] token:[[IoTProcessModel sharedModel] currentToken] specialProductKeys:nil];
    
    isAddGroup = NO;
}

- (void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    [self initLamp];
}

- (void)viewWillDisappear:(BOOL)animated{
    [super viewWillDisappear:animated];
    [XPGWifiSDK sharedInstance].delegate = nil;
    
    for (XPGWifiGroup *group in self.groupList){
        group.delegate = nil;
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)initLamp{
    [self.sliderView removeFromSuperview];
    
    if(devices == nil){
        NSLog(@"devices List is nil");
        return;
    }
    
    if(_groupList != nil){
       XPGWifiGroup *group = [self getGroupWithList:_groupList ForGid:selectedGid];
        NSString *groupName;
        if(group){
             groupName = group.groupName;
        }else{
            groupName = @"";
        }
        self.textFieldGroupName.text = groupName;
    }
    
    if(_selectedDevices == nil){
        _selectedDevices = [[NSMutableArray alloc] init];
    }
    self.sliderViewList = [[NSMutableArray alloc] init];
    
    for (XPGWifiSubDevice *dev in devices){
        BOOL isTrue = NO;
        for(NSDictionary *subDev in _selectedDevices){
            NSString * subDid = subDev[@"sdid"];
            NSLog(@"subDId == %@ and dev.subdid == %@",subDid,dev.subDid);
            if([subDid isEqualToString:dev.subDid]){
                isTrue = YES;
                break;
            }
        }
        [self.sliderViewList addObject:
        [self viewWithTitle:[NSString stringWithFormat:@"   LED%@",dev.subDid]
                AndImageName:@"icon"
                     WithTag:[dev.subDid integerValue]
                  isSelected:isTrue]];
    }
    
    self.sliderView.categoryViewPadding = 20;
    self.sliderView = [[CategorySliderView alloc] initWithFrame:CGRectMake(0, 51, 560, 100) andCategoryViews:self.sliderViewList sliderDirection:SliderDirectionHorizontal categorySelectionBlock:nil];
    self.sliderView.shouldAutoSelectScrolledCategory = NO;
    [self.view addSubview:self.sliderView];
}

#pragma mark - common methods
- (UIView *)viewWithTitle:(NSString *)title AndImageName:(NSString *)imageName WithTag:(NSInteger)tag isSelected:(BOOL)isSelected{
    //uiimage
    UIButton *button = [[UIButton alloc] init];
    [button removeTarget:self action:@selector(chooseLamp:) forControlEvents:UIControlEventTouchUpInside];
    button.frame = CGRectMake(0, 0, 60, 60);
    [button setTag:tag];
    [button addTarget:self action:@selector(chooseLamp:) forControlEvents:UIControlEventTouchUpInside];
    
    //uilabel
    UILabel *labelTitle = [[UILabel alloc] initWithFrame:CGRectMake(0, 65, 60, 10)];
    labelTitle.text = title;
    labelTitle.font = [UIFont fontWithName:@"Helvetica" size:10.0];
    labelTitle.textColor = [UIColor whiteColor];
    if(isSelected){
        [button setImage:[UIImage imageNamed:@"icon-02"] forState:UIControlStateNormal];
        [labelTitle setTextColor:[UIColor yellowColor]];
        [button setSelected:YES];
    }else{
        [button setImage:[UIImage imageNamed:imageName] forState:UIControlStateNormal];
    }
    
    //UIVIEW
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 60, 80)];
    [view addSubview:button];
    [view addSubview:labelTitle];
    
    return view;
}

- (NSDictionary *)setSubDeviceId:(NSString *)subDid AndDid:(NSString *)did{
    NSMutableDictionary *dic = [[NSMutableDictionary alloc] init];
    [dic setObject:did forKey:@"did"];
    [dic setObject:subDid forKey:@"sdid"];
    return dic;
}

- (XPGWifiGroup *)getGroupWithList:(NSArray *)groupList ForGid:(NSString *)gid{
    for (XPGWifiGroup *group in groupList){
        if([group.gid isEqualToString:selectedGid]){
            return group;
        }
    }
    return nil;
}

#pragma mark - actions
- (void)chooseLamp:(id)sender{
    UIButton *button = (UIButton *)sender;
    dispatch_async(dispatch_get_main_queue(), ^{
        button.selected = !button.selected;
        if(button.selected){
            [self setButtonHighLighting:button];
        }else{
            [self removeButtonHighLighting:button];
        }
        [self onAddLEDOrCancelWithSubDid:[NSString stringWithFormat:@"%lu", (long)button.tag]];
        [self.selectedCollectionView reloadData];
    });
}

- (IBAction)onTap:(id)sender {
    [self.textFieldGroupName resignFirstResponder];
}

- (BOOL)textFieldShouldReturn:(UITextField *)theTextField {
    if (theTextField == self.textFieldGroupName) {
        [theTextField resignFirstResponder];
    }
    return YES;
}

- (void)onAddLEDOrCancelWithSubDid:(NSString *)subDid{
    XPGWifiSubDevice *subDevice = [AppDelegate getWifiSubDeviceFromList:devices sdid:subDid];
    if(subDevice == nil)
        return;
    
    NSString *sDid = subDevice.subDid;
    if([self.selectedDevices count] <= 0){
        [self.selectedDevices addObject:
         [self setSubDeviceId:sDid AndDid:subDevice.did]];
    }
    else{
        for(NSDictionary *deviceDict in self.selectedDevices){
            NSString *selectedSubDid = deviceDict[@"sdid"];
            if([selectedSubDid isEqualToString:sDid]){
                [self.selectedDevices removeObject:deviceDict];
                return;
            }
        }
        [self.selectedDevices addObject:[self setSubDeviceId:sDid AndDid:subDevice.did]];
    }
}

- (void)onBack{
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)onAddGroupWithName{
    XPGWifiSubDevice *subDevice = devices[0];
    NSString *content = [_textFieldGroupName.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    NSString *groupName = [content stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    if([groupName isEqualToString:@""]){
        [[[UIAlertView alloc] initWithTitle:@"提示" message:@"名称不能为空" delegate:self cancelButtonTitle:@"确定" otherButtonTitles:nil, nil] show];
        return;
    }
    if([_selectedDevices count] <= 0){
        [[[UIAlertView alloc] initWithTitle:@"提示" message:@"你还没选择子设备" delegate:self cancelButtonTitle:@"确定" otherButtonTitles:nil, nil] show];
        return;
    }
    
    for(XPGWifiGroup *group in self.groupList){
        if([groupName isEqualToString:group.groupName]){
            if(![selectedGid isEqualToString:group.gid]){
                [[[UIAlertView alloc] initWithTitle:@"提示" message:@"该组名已存在，不能重复！" delegate:self cancelButtonTitle:@"确定" otherButtonTitles:nil, nil] show];
                return;
            }
        }
        
    }
    
    if(self.isEditable){
        [[XPGWifiSDK sharedInstance] editGroup:[IoTProcessModel sharedModel].currentUid
                                         token:[IoTProcessModel sharedModel].currentToken
                                           gid:selectedGid
                                     groupName:groupName
                                specialDevices:_selectedDevices];
    }else {
        [[XPGWifiSDK sharedInstance] addGroup:[IoTProcessModel sharedModel].currentUid
                                        token:[IoTProcessModel sharedModel].currentToken
                                   productKey:subDevice.subProductKey
                                    groupName:groupName
                               specialDevices:_selectedDevices];
    }
    
    [self.navigationController popToViewController:[IoTMainController currentController] animated:YES];
}

- (void)setButtonHighLighting:(UIButton *)button{
    button.imageView.image = [UIImage imageNamed:@"icon-02@2x"];
    NSArray *viewSubview = [button superview].subviews;
    for(UIView *view in viewSubview){
        if([view isKindOfClass:[UILabel class]]){
            [(UILabel *)view setTextColor:[UIColor yellowColor]];
        }
    }
}

- (void)removeButtonHighLighting:(UIButton *)button{
    button.imageView.image = [UIImage imageNamed:@"icon"];
    NSArray *viewSubview = [button superview].subviews;
    for(UIView *view in viewSubview){
        if([view isKindOfClass:[UILabel class]]){
            [(UILabel *)view setTextColor:[UIColor whiteColor]];
        }
    }
}

#pragma mark - delegates
- (void)XPGWifiSDK:(XPGWifiSDK *)wifiSDK didGetGroups:(NSArray *)groupList result:(int)result{
    // 成功
    self.groupList = groupList;
    if(result == 0){
        for (XPGWifiGroup *group in groupList){
            if([group.gid isEqualToString:selectedGid]){
                group.delegate = self;
                [group getDevices];
            }
        }
    }
    else{
        [[[UIAlertView alloc] initWithTitle:@"提示" message:@"添加失败" delegate:self cancelButtonTitle:@"确定" otherButtonTitles:nil, nil] show];
    }
}

- (void)XPGWifiGroup:(XPGWifiGroup *)group didGetDevices:(NSArray *)deviceList result:(int)result
{
    if(result == 0)
        _selectedDevices = [deviceList mutableCopy];
    [self initLamp];
}

#pragma mark - collectionView delegate and datasource
- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return [self.selectedDevices count];
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    IoTCollectionViewCell *cell = (IoTCollectionViewCell *)[collectionView    dequeueReusableCellWithReuseIdentifier:cellIdentified forIndexPath:indexPath];
    NSString *name = self.selectedDevices[indexPath.row][@"sdid"];
    [cell updateName:name];
    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    NSInteger tag = [self.selectedDevices[indexPath.row][@"sdid"] integerValue];
    NSString *sdid = [NSString stringWithFormat:@"%@", @(tag)];

    for (UIView *view in self.sliderViewList){
        for ( UIButton *btn in view.subviews){
            if(btn.tag == tag){
                btn.selected = !btn.selected;
                [self removeButtonHighLighting:btn];
            }
        }
    }
    
    [self onAddLEDOrCancelWithSubDid:sdid];
    [collectionView reloadData];
}

@end
