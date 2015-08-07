//
//  ARDTransData.h
//  AppRTCDemo
//
//  Created by MotohiroNAKAMURA on 2015/07/27.
//
//
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

@interface ARDTransData : NSObject<NSCoding>/* {
    
    NSData* data;
    BOOL isBinary;
    BOOL isLast;
    BOOL isFirst;
    uint32_t chunk_id;
}*/

@property (nonatomic, strong) NSData* data;
@property (nonatomic) BOOL isBinary;
@property (nonatomic) BOOL isLast;
@property (nonatomic) BOOL isFirst;
@property (nonatomic) uint32_t chunk_id;
@property (nonatomic) uint32_t total_chunk;


- (NSComparisonResult) compareId:(ARDTransData*)b;
@end
