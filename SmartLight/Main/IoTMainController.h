/**
 * IoTMainController.h
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

@interface IoTMainController : UIViewController<XPGWifiCentralControlDeviceDelegate>

@property (weak, nonatomic) IBOutlet UITableView *tableView;

@property (nonatomic, assign          ) XPGWifiCentralControlDevice *device;

//两种分组的高度，用于展开功能
@property (nonatomic, strong, readonly) NSMutableArray              *cellHeightList;
@property (nonatomic, strong, readonly) NSMutableArray              *cellHeightSubList;

//初始化
- (id)initWithDevice:(XPGWifiCentralControlDevice *)device;

//获取当前实例
+ (IoTMainController *)currentController;

//添加子设备
- (void)onAddSubDev:(id)sender;

//删除子设备
- (void)onRemoveSubDev:(id)sender;

//控制子设备或分组
- (void)onControlDeviceOrGroup:(id)sender;

//重载数据
- (void)reload;

@end
