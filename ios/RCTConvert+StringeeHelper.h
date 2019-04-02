//
//  RCTConvert+StringeeHelper.h
//  RNStringee
//
//  Created by HoangDuoc on 11/16/18.
//  Copyright © 2018 Facebook. All rights reserved.
//

#import <React/RCTConvert.h>
#import <Stringee/Stringee.h>

NS_ASSUME_NONNULL_BEGIN

@interface RCTConvert (StringeeHelper)

+ (NSDictionary *)StringeeIdentity:(StringeeIdentity *)identity;

+ (NSArray *)StringeeIdentities:(NSArray<StringeeIdentity *> *)identities;

+ (NSDictionary *)StringeeConversation:(StringeeConversation *)conversation;

+ (NSArray *)StringeeConversations:(NSArray<StringeeConversation *> *)conversations;

+ (NSDictionary *)StringeeMessage:(StringeeMessage *)message;

+ (NSArray *)StringeeMessages:(NSArray<StringeeMessage *> *)messages;

@end

NS_ASSUME_NONNULL_END
