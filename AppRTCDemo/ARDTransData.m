//
//  ARDTransData.m
//  AppRTCDemo
//
//  Created by MotohiroNAKAMURA on 2015/07/27.
//
//

#import "ARDTransData.h"

@implementation ARDTransData

@synthesize data;
@synthesize isBinary;
@synthesize isLast;
@synthesize isFirst;
@synthesize chunk_id;
@synthesize total_chunk;

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    
    if (self) {
        
        self.data = [aDecoder decodeObjectForKey:@"data"];
        self.isBinary = [aDecoder decodeBoolForKey:@"isBinary"];
        self.isLast = [aDecoder decodeBoolForKey:@"isLast"];
        self.isFirst = [aDecoder decodeBoolForKey:@"isFirst"];
        self.chunk_id = (uint32_t)[aDecoder decodeIntegerForKey:@"chunk_id"];
        self.total_chunk = (uint32_t)[aDecoder decodeIntegerForKey:@"total_chunk"];
        
    }
    
    return self;
}


- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:data forKey:@"data"];
    [aCoder encodeBool:isBinary forKey:@"isBinary"];
    [aCoder encodeBool:isLast forKey:@"isLast"];
    [aCoder encodeBool:isFirst forKey:@"isFirst"];
    [aCoder encodeInteger:chunk_id forKey:@"chunk_id"];
    [aCoder encodeInteger:total_chunk forKey:@"total_chunk"];
}

- (NSComparisonResult) compareId:(ARDTransData*)b
{
    if (self.chunk_id < b.chunk_id) {
        return NSOrderedAscending;
    } else if (self.chunk_id > b.chunk_id) {
        return NSOrderedDescending;
    } else {
        return NSOrderedSame;
    }
}


@end
