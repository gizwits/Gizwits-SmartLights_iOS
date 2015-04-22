/**
 * IoTLightViewCell.h
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

#import <UIKit/UIKit.h>
#import "IoTMainController.h"

typedef enum
{
    kIotSubLightCell   = 1,//子设备列表
    kIotGroupLightCell = 2,//分组设备列表
}IoTLightCellStyle;

@interface IoTLightViewCell : UITableViewCell

@property (weak, nonatomic) IBOutlet UILabel      *labelName;
@property (weak, nonatomic) IBOutlet UIView       *lineView;
@property (weak, nonatomic) IBOutlet UIButton     *deleteBtn;
@property (weak, nonatomic) IBOutlet UIButton     *buttonExpand;
@property (weak, nonatomic) IBOutlet UIButton *buttonGroupExpand;
@property (weak, nonatomic) IBOutlet UIScrollView *scrollView;
@property (weak, nonatomic) IBOutlet UIScrollView *scrollSubDevList;

@property (nonatomic, strong) XPGWifiGroup *selectedGroup;
@property (nonatomic, assign) BOOL         isEditing;

//组列表键值对
@property (nonatomic, strong) NSArray      *groupList;

//组设备信息键值对
@property (nonatomic, strong) NSArray      *groupDevicesList;
@property (nonatomic, strong) NSArray      *subDeviceList;
@property (nonatomic, strong) NSDictionary *firstKeyValDev;

//更新信息
- (void)updateCellWithSubDevsList:(NSArray *)subDeviceList WithGroupList:(NSArray *)groupList WithIndexPath:(NSIndexPath *)indexPath Style:(IoTLightCellStyle)style lightStatus:(NSDictionary *)lightStatus;

@end
