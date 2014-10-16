//
//  BLEDataPacket.m
//  BLEMeshChat
//
//  Created by Christopher Ballinger on 10/15/14.
//  Copyright (c) 2014 Christopher Ballinger. All rights reserved.
//

#import "BLEDataPacket.h"
#import "BLECrypto.h"

static const NSUInteger kBLEVersionOffset = 0;
static const NSUInteger kBLEVersionLength = 1;
static const NSUInteger kBLETimestampOffset = kBLEVersionOffset + kBLEVersionLength;
static const NSUInteger kBLETimestampLength = 8;
static const NSUInteger kBLESenderPublicKeyOffset = kBLETimestampOffset + kBLETimestampLength;

@interface BLEDataPacket()
/** full raw packet data */
@end

@implementation BLEDataPacket
@dynamic version;
@dynamic timestampDate;
@dynamic timestamp;

- (instancetype) initWithPacketData:(NSData*)packetData error:(NSError**)error {
    if (self = [super init]) {
        BOOL packetDataHasValidLength = [self parsePacketData:packetData];
        if (!packetDataHasValidLength) {
            if (error) {
                *error = [NSError errorWithDomain:@"BLEDataPacketParseError" code:100 userInfo:@{NSLocalizedDescriptionKey: @"Packet data has invalid length"}];
            }
            return nil;
        }
    }
    return self;
}

//[[version=1][timestamp=8][sender_public_key=32][data=n]][signature=64]
- (BOOL) parsePacketData:(NSData*)packetData {
    NSUInteger kBLEMinimumDataPacketSize = kBLEVersionLength + kBLETimestampLength + kBLECryptoEd25519PublicKeyLength + kBLECryptoEd25519SignatureLength;
    NSAssert(packetData.length > kBLEMinimumDataPacketSize, @"Packet must be of valid length!");
    if (packetData.length <= kBLEMinimumDataPacketSize) {
        return NO;
    }
    _packetData = packetData;
    _versionData = [packetData subdataWithRange:NSMakeRange(kBLEVersionOffset, kBLEVersionLength)];
    _timestampData = [packetData subdataWithRange:NSMakeRange(kBLETimestampOffset, kBLETimestampLength)];
    _senderPublicKey = [packetData subdataWithRange:NSMakeRange(kBLESenderPublicKeyOffset, kBLECryptoEd25519PublicKeyLength)];
    
    NSUInteger dataOffset = kBLESenderPublicKeyOffset + kBLECryptoEd25519PublicKeyLength;
    NSUInteger signatureOffset = packetData.length - kBLECryptoEd25519SignatureLength - 1;

    NSUInteger dataLength = signatureOffset - dataOffset;
    
    _data = [packetData subdataWithRange:NSMakeRange(dataOffset, dataLength)];
    _signature = [packetData subdataWithRange:NSMakeRange(signatureOffset, kBLECryptoEd25519SignatureLength)];
    return YES;
}

- (BOOL) hasValidSignature {
    BOOL hasValidSignature = [BLECrypto verifyData:self.packetData signature:self.signature publicKey:self.senderPublicKey];
    return hasValidSignature;
}

- (uint8_t) version {
    NSAssert(self.versionData.length == 1, @"version must be 1 byte");
    uint8_t version = 0;
    version = *(uint8_t*)(self.versionData.bytes);
    return version;
}

- (NSDate*) timestampDate {
    uint64_t timestamp = [self timestamp];
    NSTimeInterval timeInterval = timestamp / 1000;
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:timeInterval];
    return date;
}

- (uint64_t) timestamp {
    NSAssert(self.timestampData.length == 8, @"timestamp must be 8 bytes");
    uint64_t timestamp = 0;
    timestamp = CFSwapInt64LittleToHost(*(uint64_t*)(self.timestampData.bytes));
    return timestamp;
}

@end