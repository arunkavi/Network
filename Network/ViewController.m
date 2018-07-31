//
//  ViewController.m
//  Network
//
//  Created by Arunkavi on 28/09/15.


#import "ViewController.h"
#import "Reachability.h"
#import <NetworkExtension/NetworkExtension.h>
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import <CoreTelephony/CTCarrier.h>
#import <SystemConfiguration/CaptiveNetwork.h>
#import <SystemConfiguration/SCDynamicStore.h>
#import <SystemConfiguration/SCDynamicStoreCopyDHCPInfo.h>
#include <ifaddrs.h>

#import <Foundation/Foundation.h>
#import <net/if.h>
#import "getgateway.h"
#import <arpa/inet.h>

struct ifaddrs *interfaces;

@interface ViewController ()
@property (nonatomic) Reachability *hostTest;
@property (nonatomic) Reachability *internetTest;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReachabilityChange:) name:kReachabilityChangedNotification object:nil];
    
//    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didRadioChange:) name:CTRadioAccessTechnologyDidChangeNotification object:nil];
    
//    CFArrayRef myArray = CNCopySupportedInterfaces();
//    CFDictionaryRef myDict = CNCopyCurrentNetworkInfo(CFArrayGetValueAtIndex(myArray, 0));
//    NSLog(@"%@",myDict);
    
    NSArray * networkInterfaces = [NEHotspotHelper supportedNetworkInterfaces];
    NSLog(@"Networks %@",networkInterfaces);
    

    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), //center
                                    NULL, // observer
                                    onNotifyCallback, // callback
                                    CFSTR("com.apple.system.config.network_change"), // event name
                                    NULL, // object
                                    CFNotificationSuspensionBehaviorDeliverImmediately);
    
    NSString *hostName = @"www.apple.com";
    self.internetLabel.text=@"NA";
    self.connectionLabel.text=@"NA";
    
    self.hostTest = [Reachability reachabilityWithHostName:hostName];
    [self.hostTest startNotifier];
    [self refreshTheStatus:self.hostTest];
    
    self.internetTest = [Reachability reachabilityForInternetConnection];
    [self.internetTest startNotifier];
    [self refreshTheStatus:self.internetTest];

//    CTTelephonyNetworkInfo *telephonyInfo = [CTTelephonyNetworkInfo new];
//    [NSNotificationCenter.defaultCenter addObserverForName:CTRadioAccessTechnologyDidChangeNotification
//                                                    object:nil
//                                                     queue:nil
//                                                usingBlock:^(NSNotification *note)
//     {
//         NSLog(@"New Radio Access Technology: %@", telephonyInfo.currentRadioAccessTechnology);
//         [self refreshTheStatus:self.internetTest];
//     }];
    

}
- (BOOL) isWiFiEnabled {
    
    NSCountedSet * cset = [NSCountedSet new];
    
    struct ifaddrs *interfaces;
    
    if( ! getifaddrs(&interfaces) ) {
        for( struct ifaddrs *interface = interfaces; interface; interface = interface->ifa_next) {
            if ( (interface->ifa_flags & IFF_UP) == IFF_UP ) {
                [cset addObject:[NSString stringWithUTF8String:interface->ifa_name]];
            }
        }
    }
    
    return [cset countForObject:@"awdl0"] > 1 ? YES : NO;
}
static void onNotifyCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
    NSString* notifyName = (__bridge NSString*)name;
    // this check should really only be necessary if you reuse this one callback method
    //  for multiple Darwin notification events
    if ([notifyName isEqualToString:@"com.apple.system.config.network_change"]) {
        // use the Captive Network API to get more information at this point
        NSLog(@"userinfo %@",userInfo);
    } else {
        NSLog(@"intercepted %@", notifyName);
    }
}
-(void)refreshTheStatus :(Reachability *)input
{
    if (input == self.hostTest)
    {
        BOOL connectionRequired = [input connectionRequired];
        if (connectionRequired)
        {
            self.internetLabel.text=@"Internet Not available";
        }
        else
        {
            self.internetLabel.text=@"Internet available";
        }

    }
    
    if (input == self.internetTest)
    {
        [self updateFields:self.internetTest];
    }


}

-(void)updateFields :(Reachability *)input
{
    NetworkStatus netStatus = [input currentReachabilityStatus];
    
    switch (netStatus)
    {
        case NotReachable:        {
            self.connectionLabel.text=@"NA";
            if ([self isWiFiEnabled])
            {
                self.connectionLabel.text=@"Wifi Turned ON but Not Connected";
            }
            self.internetLabel.text=@"Internet Not available";
            break;
        }
            
        case ReachableViaWWAN:        {
            NSMutableString *finalDetails=[[NSMutableString alloc]init];
            [finalDetails appendString:@"Type : Mobile Data"];

            
            CTTelephonyNetworkInfo *telephonyInfo = [CTTelephonyNetworkInfo new];
                        CTCarrier *carrier = [telephonyInfo subscriberCellularProvider];
            NSString *name = [carrier carrierName];
            if (name.length>=2)
            {
                [finalDetails appendString:[NSString stringWithFormat:@"\nProvider :%@",name]];

            }
            NSString *type=@"";
            NSLog(@"Current Radio Access Technology: %@", telephonyInfo.currentRadioAccessTechnology);
            if ([[NSString stringWithFormat:@"%@",telephonyInfo.currentRadioAccessTechnology] caseInsensitiveCompare:@"CTRadioAccessTechnologyHSDPA"]==NSOrderedSame)
            {
                
                type=@"3G";
            }
            else if ([[NSString stringWithFormat:@"%@",telephonyInfo.currentRadioAccessTechnology] caseInsensitiveCompare:@"CTRadioAccessTechnologyEdge"]==NSOrderedSame)
            {
                
                type=@"2G";
            }
            else if ([[NSString stringWithFormat:@"%@",telephonyInfo.currentRadioAccessTechnology] caseInsensitiveCompare:@"CTRadioAccessTechnologyLTE"]==NSOrderedSame)
            {
                
                type=@"4G";
                
            }
            
            if (type.length>0)
            {
                [finalDetails appendString:[NSString stringWithFormat:@"\nNetwork Type :%@",type]];
            }

            NSString *country = [carrier isoCountryCode];
            if (country.length>0)
            {
                [finalDetails appendString:[NSString stringWithFormat:@"\nCountry :%@",[country uppercaseString]]];
  
            }
            self.connectionLabel.text= finalDetails;
            break;
        }
        case ReachableViaWiFi:        {
             self.connectionLabel.text=@"Wifi";
            [self runMethod];
            break;
        }
    }

}

-(void)runMethod
{
    NSArray *ifs = (__bridge_transfer id)CNCopySupportedInterfaces();
    id info = nil;
    for (NSString *ifnam in ifs) {
        info = (__bridge_transfer id)CNCopyCurrentNetworkInfo((__bridge CFStringRef)ifnam);
        NSLog(@"%@ => %@", ifnam, info);
        if (info && [info count]) { break; }
    }
     NSMutableString *finalDetails=[[NSMutableString alloc]init];
    NSDictionary *new=(NSDictionary *)info;
    NSLog(@"%@",new);
    NSString *name =[new objectForKey:@"SSID"];
    if (name.length>0)
    {
        [finalDetails appendString:[NSString stringWithFormat:@"Type : Wifi \nName : %@",name]];
        //self.connectionLabel.text=[NSString stringWithFormat:@"Type : Wifi \n%@",name];
    }
    NSString *mac =[new objectForKey:@"BSSID"];
    if (mac.length>0)
    {
        [finalDetails appendString:[NSString stringWithFormat:@"\nMAC Address : %@",mac]];
        //self.connectionLabel.text=[NSString stringWithFormat:@"Type : Wifi \nName : %@ \nMAC Address : %@",name,mac];
    }
    NSString *ipadd =[self getIPAddress];
    if (ipadd.length>0)
    {
        [finalDetails appendString:[NSString stringWithFormat:@"\nDevice ip : %@",ipadd]];
        //self.connectionLabel.text=[NSString stringWithFormat:@"Type : Wifi \nName : %@ \nMAC Address : %@\nDevice ip : %@",name,mac,ipadd];
    }
    
    NSString *gate =[self getGatewayIP];
    if (gate.length>0)
    {
        [finalDetails appendString:[NSString stringWithFormat:@"\nGateway ip : %@",gate]];
        //self.connectionLabel.text=[NSString stringWithFormat:@"Type : Wifi \nName : %@ \nMAC Address : %@\nDevice ip : %@\nGateway ip : %@",name,mac,ipadd,gate];
    }
    
    self.connectionLabel.text= finalDetails;
    id signalStrength = [CTTelephonyNetworkInfo new];
    
}

- (NSString *)getGatewayIP {
    NSString *ipString = nil;
    struct in_addr gatewayaddr;
    int r = getdefaultgateway(&(gatewayaddr.s_addr));
    if(r >= 0) {
        ipString = [NSString stringWithFormat: @"%s",inet_ntoa(gatewayaddr)];
        NSLog(@"default gateway : %@", ipString );
    } else {
        NSLog(@"getdefaultgateway() failed");
    }
    
    return ipString;
    
}

- (NSString *)getIPAddress {
    
    NSString *address = @"error";
    struct ifaddrs *interfaces = NULL;
    struct ifaddrs *temp_addr = NULL;
    int success = 0;
    // retrieve the current interfaces - returns 0 on success
    success = getifaddrs(&interfaces);
    if (success == 0) {
        // Loop through linked list of interfaces
        temp_addr = interfaces;
        while(temp_addr != NULL) {
            if(temp_addr->ifa_addr->sa_family == AF_INET) {
                // Check if interface is en0 which is the wifi connection on the iPhone
                if([[NSString stringWithUTF8String:temp_addr->ifa_name] isEqualToString:@"en0"]) {
                    // Get NSString from C String
                    address = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)temp_addr->ifa_addr)->sin_addr)];
                    
                }
                
            }
            
            temp_addr = temp_addr->ifa_next;
        }
    }
    // Free memory
    freeifaddrs(interfaces);
    return address;
    
}
/*
 * Change in network
 */
- (void) didReachabilityChange:(NSNotification *)input
{
    Reachability* reach = [input object];
    NSParameterAssert([reach isKindOfClass:[Reachability class]]);
    [self refreshTheStatus:reach];
}
-(void)didRadioChange :(NSNotification *)input
{
    [self refreshTheStatus:self.internetTest];
}
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}



@end
