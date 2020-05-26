
#import "RNStringeeClient.h"
#import "RNStringeeInstanceManager.h"
#import <React/RCTLog.h>
#import <React/RCTUtils.h>
#import "RCTConvert+StringeeHelper.h"

// Connect
static NSString *didConnect               = @"didConnect";
static NSString *didDisConnect            = @"didDisConnect";
static NSString *didFailWithError         = @"didFailWithError";
static NSString *requestAccessToken       = @"requestAccessToken";

// Call 1-1
static NSString *incomingCall               = @"incomingCall";
static NSString *didReceiveCustomMessage    = @"didReceiveCustomMessage";

// Chat
static NSString *objectChangeNotification   = @"objectChangeNotification";

@implementation RNStringeeClient {
    NSMutableArray<NSString *> *jsEvents;
    BOOL isConnecting;
}

@synthesize bridge = _bridge;

RCT_EXPORT_MODULE();

- (instancetype)init {
    self = [super init];
    [RNStringeeInstanceManager instance].rnClient = self;
    jsEvents = [[NSMutableArray alloc] init];
    _messages = [[NSMutableDictionary alloc] init];
    return self;
}

- (void)dealloc
{
    [_client disconnect];
    _client = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (NSArray<NSString *> *)supportedEvents {
    return @[didConnect,
             didDisConnect,
             didFailWithError,
             requestAccessToken,
             incomingCall,
             didReceiveCustomMessage,
             objectChangeNotification
             ];
}

+ (BOOL)requiresMainQueueSetup {
    return YES;
}

RCT_EXPORT_METHOD(setNativeEvent:(NSString *)event) {
    [jsEvents addObject:event];
}

RCT_EXPORT_METHOD(removeNativeEvent:(NSString *)event) {
    int index = -1;
    index = (int)[jsEvents indexOfObject:event];
    if (index >= 0) {
        [jsEvents removeObjectAtIndex:index];
    }
}

RCT_EXPORT_METHOD(connect:(NSString *)accessToken) {
    if (isConnecting) {
        return;
    }
    isConnecting = YES;
    if (!_client) {
        _client = [[StringeeClient alloc] initWithConnectionDelegate:self];
        _client.incomingCallDelegate = self;
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleObjectChangeNotification:) name:StringeeClientObjectsDidChangeNotification object:_client];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleNewMessageNotification:) name:StringeeClientNewMessageNotification object:_client];
    }
    [_client connectWithAccessToken:accessToken];
}

RCT_EXPORT_METHOD(disconnect) {
    if (_client) {
        [_client disconnect];
    }
    isConnecting = NO;
}

RCT_EXPORT_METHOD(registerPushForDeviceToken:(NSString *)deviceToken isProduction:(BOOL)isProduction isVoip:(BOOL)isVoip callback:(RCTResponseSenderBlock)callback) {
    if (!_client || !_client.hasConnected) {
        callback(@[@(NO), @(-1), @"StringeeClient is not initialized or connected."]);
        return;
    }

    [_client registerPushForDeviceToken:deviceToken isProduction:isProduction isVoip:isVoip completionHandler:^(BOOL status, int code, NSString *message) {
        callback(@[@(status), @(code), message]);
    }];

}

RCT_EXPORT_METHOD(unregisterPushToken:(NSString *)deviceToken callback:(RCTResponseSenderBlock)callback) {

    if (!_client || !_client.hasConnected) {
        callback(@[@(NO), @(-1), @"StringeeClient is not initialized or connected."]);
        return;
    } 

    [_client unregisterPushForDeviceToken:deviceToken completionHandler:^(BOOL status, int code, NSString *message) {
        callback(@[@(status), @(code), message]);
    }];
    
}

RCT_EXPORT_METHOD(sendCustomMessage:(NSString *)userId message:(NSString *)message callback:(RCTResponseSenderBlock)callback) {
    
    if (!_client || !_client.hasConnected) {
        callback(@[@(NO), @(-1), @"StringeeClient is not initialized or connected."]);
        return;
    }

    if (!message) {
        callback(@[@(NO), @(-3), @"Message can not be nil."]);
        return;
    }
    
    NSError *jsonError;
    NSData *objectData = [message dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *data = [NSJSONSerialization JSONObjectWithData:objectData
                                                         options:NSJSONReadingMutableContainers
                                                           error:&jsonError];
    
    if (jsonError) {
        callback(@[@(NO), @(-4), @"Message format is invalid."]);
        return;
    }
    
    [_client sendCustomMessage:data toUserId:userId completionHandler:^(BOOL status, int code, NSString *message) {
        callback(@[@(status), @(code), message]);
    }];
}

// Connect
- (void)requestAccessToken:(StringeeClient *)stringeeClient {
    isConnecting = NO;
    [self sendEventWithName:requestAccessToken body:@{ @"userId" : stringeeClient.userId }];
}

- (void)didConnect:(StringeeClient *)stringeeClient isReconnecting:(BOOL)isReconnecting {
    if ([jsEvents containsObject:didConnect]) {
        [self sendEventWithName:didConnect body:@{ @"userId" : stringeeClient.userId, @"projectId" : stringeeClient.projectId, @"isReconnecting" : @(isReconnecting) }];
    }
}

- (void)didDisConnect:(StringeeClient *)stringeeClient isReconnecting:(BOOL)isReconnecting {
    if ([jsEvents containsObject:didDisConnect]) {
        [self sendEventWithName:didDisConnect body:@{ @"userId" : stringeeClient.userId, @"projectId" : stringeeClient.projectId, @"isReconnecting" : @(isReconnecting) }];
    }
}

- (void)didFailWithError:(StringeeClient *)stringeeClient code:(int)code message:(NSString *)message {
    if ([jsEvents containsObject:didFailWithError]) {
        [self sendEventWithName:didFailWithError body:@{ @"userId" : stringeeClient.userId, @"code" : @(code), @"message" : message }];
    }
}

- (void)didReceiveCustomMessage:(StringeeClient *)stringeeClient message:(NSDictionary *)message fromUserId:(NSString *)userId {
    if ([jsEvents containsObject:didReceiveCustomMessage]) {
        NSString *data;
        if (message) {
            NSError *err;
            NSData *jsonData = [NSJSONSerialization dataWithJSONObject:message options:0 error:&err];
            data = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        }
        
        data = (data != nil) ? data : @"";
        
        [self sendEventWithName:didReceiveCustomMessage body:@{ @"from" : userId, @"data" : data }];
    }
}

// Call
- (void)incomingCallWithStringeeClient:(StringeeClient *)stringeeClient stringeeCall:(StringeeCall *)stringeeCall {
    [[RNStringeeInstanceManager instance].calls setObject:stringeeCall forKey:stringeeCall.callId];

    if ([jsEvents containsObject:incomingCall]) {

        int index = 0;

        if (stringeeCall.callType == CallTypeCallIn) {
            // Phone-to-app
            index = 3;
        } else if (stringeeCall.callType == CallTypeCallOut) {
            // App-to-phone
            index = 2;
        } else if (stringeeCall.callType == CallTypeInternalIncomingCall) {
            // App-to-app-incoming-call
            index = 1;
        } else {
            // App-to-app-outgoing-call
            index = 0;
        }

        id returnUserId = stringeeClient.userId ? stringeeClient.userId : [NSNull null];
        id returnCallId = stringeeCall.callId ? stringeeCall.callId : [NSNull null];
        id returnFrom = stringeeCall.from ? stringeeCall.from : [NSNull null];
        id returnTo = stringeeCall.to ? stringeeCall.to : [NSNull null];
        id returnFromAlias = stringeeCall.fromAlias ? stringeeCall.fromAlias : [NSNull null];
        id returnToAlias = stringeeCall.toAlias ? stringeeCall.toAlias : [NSNull null];
        id returnCustomData = stringeeCall.customDataFromYourServer ? stringeeCall.customDataFromYourServer : [NSNull null];

        [self sendEventWithName:incomingCall body:@{ @"userId" : returnUserId, @"callId" : returnCallId, @"from" : returnFrom, @"to" : returnTo, @"fromAlias" : returnFromAlias, @"toAlias" : returnToAlias, @"callType" : @(index), @"isVideoCall" : @(stringeeCall.isVideoCall), @"customDataFromYourServer" : returnCustomData}];
    }
    
}

#pragma mark - Conversation

RCT_EXPORT_METHOD(createConversation:(NSArray *)userIds options:(NSDictionary *)options callback:(RCTResponseSenderBlock)callback) {
    
    if (!_client || !_client.hasConnected) {
        callback(@[@(NO), @(-1), @"StringeeClient is not initialized or connected.", [NSNull null]]);
        return;
    }
    
    if (!userIds.count) {
        callback(@[@(NO), @(-3), @"UserIds is invalid.", [NSNull null]]);
        return;
    }
    
    NSMutableSet *users = [[NSMutableSet alloc] init];
    for (NSString *userId in userIds) {
        if (![userId isKindOfClass:[NSString class]]) {
            callback(@[@(NO), @(-3), @"UserIds is invalid.", [NSNull null]]);
            return;
        }
        
        StringeeIdentity *iden = [StringeeIdentity new];
        iden.userId = userId;
        [users addObject:iden];
    }
    

    if (![options isKindOfClass:[NSDictionary class]]) {
        callback(@[@(NO), @(-4), @"Options is invalid."]);
        return;
    }
    
    NSString *name = options[@"name"];
    NSNumber *distinctByParticipants = options[@"isDistinct"];
    NSNumber *isGroup = options[@"isGroup"];
    
    StringeeConversationOption *convOptions = [StringeeConversationOption new];
    convOptions.isGroup = [isGroup boolValue] ? [isGroup boolValue] : NO;
    convOptions.distinctByParticipants = distinctByParticipants ? [distinctByParticipants boolValue] : YES;
    
    [_client createConversationWithName:name participants:users options:convOptions completionHandler:^(BOOL status, int code, NSString *message, StringeeConversation *conversation) {
        callback(@[@(status), @(code), message, [RCTConvert StringeeConversation:conversation]]);
    }];
}

RCT_EXPORT_METHOD(getConversationById:(NSString *)conversationId callback:(RCTResponseSenderBlock)callback) {
    
    if (!_client || !_client.hasConnected) {
        callback(@[@(NO), @(-1), @"StringeeClient is not initialized or connected.", [NSNull null]]);
        return;
    }
    
    if (![conversationId isKindOfClass:[NSString class]]) {
        callback(@[@(NO), @(-2), @"ConversationId is invalid.", [NSNull null]]);
        return;
    }
    
    [_client getConversationWithConversationId:conversationId completionHandler:^(BOOL status, int code, NSString *message, StringeeConversation *conversation) {
        callback(@[@(status), @(code), message, [RCTConvert StringeeConversation:conversation]]);
    }];
}

RCT_EXPORT_METHOD(getLocalConversations:(NSUInteger)count callback:(RCTResponseSenderBlock)callback) {
    
    if (!_client) {
        callback(@[@(NO), @(-1), @"StringeeClient is not initialized.", [NSNull null]]);
        return;
    }
    
    [_client getLocalConversationsWithCount:count completionHandler:^(BOOL status, int code, NSString *message, NSArray<StringeeConversation *> *conversations) {
        callback(@[@(status), @(code), message, [RCTConvert StringeeConversations:conversations]]);
    }];
}

RCT_EXPORT_METHOD(getLastConversations:(NSUInteger)count callback:(RCTResponseSenderBlock)callback) {
    
    if (!_client || !_client.hasConnected) {
        callback(@[@(NO), @(-1), @"StringeeClient is not initialized or connected.", [NSNull null]]);
        return;
    }
    
    [_client getLastConversationsWithCount:count completionHandler:^(BOOL status, int code, NSString *message, NSArray<StringeeConversation *> *conversations) {
        callback(@[@(status), @(code), message, [RCTConvert StringeeConversations:conversations]]);
    }];
}

RCT_EXPORT_METHOD(getConversationsAfter:(NSUInteger)datetime count:(NSUInteger)count callback:(RCTResponseSenderBlock)callback) {
    
    if (!_client || !_client.hasConnected) {
        callback(@[@(NO), @(-1), @"StringeeClient is not initialized or connected.", [NSNull null]]);
        return;
    }
    
    [_client getConversationsAfter:datetime withCount:count completionHandler:^(BOOL status, int code, NSString *message, NSArray<StringeeConversation *> *conversations) {
        callback(@[@(status), @(code), message, [RCTConvert StringeeConversations:conversations]]);
    }];
}

RCT_EXPORT_METHOD(getConversationsBefore:(NSUInteger)datetime count:(NSUInteger)count callback:(RCTResponseSenderBlock)callback) {
    
    if (!_client || !_client.hasConnected) {
        callback(@[@(NO), @(-1), @"StringeeClient is not initialized or connected.", [NSNull null]]);
        return;
    }
    
    [_client getConversationsBefore:datetime withCount:count completionHandler:^(BOOL status, int code, NSString *message, NSArray<StringeeConversation *> *conversations) {
        callback(@[@(status), @(code), message, [RCTConvert StringeeConversations:conversations]]);
    }];
}

RCT_EXPORT_METHOD(deleteConversation:(NSString *)conversationId callback:(RCTResponseSenderBlock)callback) {
    
    if (!_client || !_client.hasConnected) {
        callback(@[@(NO), @(-1), @"StringeeClient is not initialized or connected."]);
        return;
    }
    
    if (![conversationId isKindOfClass:[NSString class]] || !conversationId.length) {
        callback(@[@(NO), @(-2), @"Conversation not found."]);
        return;
    }
    
    [_client getConversationWithConversationId:conversationId completionHandler:^(BOOL status, int code, NSString *message, StringeeConversation *conversation) {
        if (!conversation) {
            callback(@[@(NO), @(-2), @"Conversation not found."]);
            return;
        }
        [conversation deleteWithCompletionHandler:^(BOOL status, int code, NSString *message) {
            callback(@[@(status), @(code), message]);
        }];
    }];
}

RCT_EXPORT_METHOD(addParticipants:(NSString *)conversationId userIds:(NSArray *)userIds callback:(RCTResponseSenderBlock)callback) {
    
    if (!_client || !_client.hasConnected) {
        callback(@[@(NO), @(-1), @"StringeeClient is not initialized or connected.", [NSNull null]]);
        return;
    }
    
    if (![userIds isKindOfClass:[NSArray class]] || !userIds.count) {
        callback(@[@(NO), @(-2), @"The participants is invalid.", [NSNull null]]);
        return;
    }
    
    NSMutableSet *users = [[NSMutableSet alloc] init];
    for (NSString *userId in userIds) {
        if (![userId isKindOfClass:[NSString class]]) {
            callback(@[@(NO), @(-2), @"The participants is invalid.", [NSNull null]]);
            return;
        }
        
        StringeeIdentity *iden = [StringeeIdentity new];
        iden.userId = userId;
        [users addObject:iden];
    }
    
    if (![conversationId isKindOfClass:[NSString class]] || !conversationId.length) {
        callback(@[@(NO), @(-3), @"Conversation not found.", [NSNull null]]);
        return;
    }
    
    [_client getConversationWithConversationId:conversationId completionHandler:^(BOOL status, int code, NSString *message, StringeeConversation *conversation) {
        if (!conversation) {
            callback(@[@(NO), @(-3), @"Conversation not found.", [NSNull null]]);
            return;
        }
        
        [conversation addParticipants:users completionHandler:^(BOOL status, int code, NSString *message, NSArray<StringeeIdentity *> *addedUsers) {
            callback(@[@(status), @(code), message, [RCTConvert StringeeIdentities:addedUsers]]);
        }];
    }];
}

RCT_EXPORT_METHOD(removeParticipants:(NSString *)conversationId userIds:(NSArray *)userIds callback:(RCTResponseSenderBlock)callback) {
    
    if (!_client || !_client.hasConnected) {
        callback(@[@(NO), @(-1), @"StringeeClient is not initialized or connected.", [NSNull null]]);
        return;
    }
    
    if (![userIds isKindOfClass:[NSArray class]] || !userIds.count) {
        callback(@[@(NO), @(-2), @"The participants is invalid.", [NSNull null]]);
        return;
    }
    
    NSMutableSet *users = [[NSMutableSet alloc] init];
    for (NSString *userId in userIds) {
        if (![userId isKindOfClass:[NSString class]]) {
            callback(@[@(NO), @(-2), @"The participants is invalid.", [NSNull null]]);
            return;
        }
        
        StringeeIdentity *iden = [StringeeIdentity new];
        iden.userId = userId;
        [users addObject:iden];
    }
    
    if (![conversationId isKindOfClass:[NSString class]] || !conversationId.length) {
        callback(@[@(NO), @(-3), @"Conversation not found.", [NSNull null]]);
        return;
    }
    
    [_client getConversationWithConversationId:conversationId completionHandler:^(BOOL status, int code, NSString *message, StringeeConversation *conversation) {
        if (!conversation) {
            callback(@[@(NO), @(-3), @"Conversation not found.", [NSNull null]]);
            return;
        }
        
        [conversation removeParticipants:users completionHandler:^(BOOL status, int code, NSString *message, NSArray<StringeeIdentity *> *removedUsers) {
            callback(@[@(status), @(code), message, [RCTConvert StringeeIdentities:removedUsers]]);
        }];
    }];
}

RCT_EXPORT_METHOD(updateConversation:(NSString *)conversationId params:(NSDictionary *)params callback:(RCTResponseSenderBlock)callback) {
    if (!_client || !_client.hasConnected) {
        callback(@[@(NO), @(-1), @"StringeeClient is not initialized or connected.", [NSNull null]]);
        return;
    }
    
    if (!params || ![params isKindOfClass:[NSDictionary class]]) {
        callback(@[@(NO), @(-2), @"Params are invalid."]);
        return;
    }
    
    NSString *name = params[@"name"];
    NSString *avatar = params[@"avatar"];

    if (![conversationId isKindOfClass:[NSString class]] || !conversationId.length || (![name isKindOfClass:[NSString class]] && ![avatar isKindOfClass:[NSString class]])) {
        callback(@[@(NO), @(-2), @"Params are invalid."]);
        return;
    }
    
    NSString *safeName = [name isKindOfClass:[NSString class]] ? name : nil;
    NSString *safeAvatar = [avatar isKindOfClass:[NSString class]] ? avatar : nil;
    
    [_client getConversationWithConversationId:conversationId completionHandler:^(BOOL status, int code, NSString *message, StringeeConversation *conversation) {
        if (!conversation) {
            callback(@[@(NO), @(-3), @"Conversation not found.", [NSNull null]]);
            return;
        }
        
        [conversation updateWithName:safeName strAvatarUrl:safeAvatar completionHandler:^(BOOL status, int code, NSString *message) {
            callback(@[@(status), @(code), message]);
        }];
    }];
}

RCT_EXPORT_METHOD(getConversationWithUser:(NSString *)userId callback:(RCTResponseSenderBlock)callback) {
    if (!_client || !_client.hasConnected || !_client.userId.length) {
        callback(@[@(NO), @(-1), @"StringeeClient is not initialized or connected.", [NSNull null]]);
        return;
    }
    
    if (!userId || ![userId isKindOfClass:[NSString class]] || !userId.length || [userId isEqualToString:_client.userId]) {
        callback(@[@(NO), @(-2), @"UserId is invalid."]);
        return;
    }
    
    NSMutableSet *users = [[NSMutableSet alloc] init];
    StringeeIdentity *iden = [StringeeIdentity new];
    iden.userId = userId;
    [users addObject:iden];
    
    StringeeIdentity *meUser = [StringeeIdentity new];
    meUser.userId = _client.userId;
    [users addObject:meUser];
    
    [_client getConversationForUsers:users completionHandler:^(BOOL status, int code, NSString *message, NSArray<StringeeConversation *> *conversations) {
        if (!conversations) {
            callback(@[@(NO), @(-4), @"Conversation is not found.", [NSNull null]]);
            return;
        }
        
        if (conversations.count == 0) {
            callback(@[@(NO), @(-4), @"Conversation is not found.", [NSNull null]]);
            return;
        }
        
        for (StringeeConversation *conversation in conversations) {
            if (conversation.isGroup == false) {
                callback(@[@(status), @(code), message, [RCTConvert StringeeConversation:conversation]]);
                return;
            }
        }
        
    }];
}

RCT_EXPORT_METHOD(getUnreadConversationCount:(RCTResponseSenderBlock)callback) {
    if (!_client || !_client.hasConnected) {
        callback(@[@(NO), @(-1), @"StringeeClient is not initialized or connected.", @(0)]);
        return;
    }
    
    [_client getUnreadConversationCountWithCompletionHandler:^(BOOL status, int code, NSString *message, int count) {
        callback(@[@(status), @(code), message, @(count)]);
    }];
}

#pragma mark - Message

RCT_EXPORT_METHOD(sendMessage:(NSDictionary *)message callback:(RCTResponseSenderBlock)callback) {
    if (!message || ![message isKindOfClass:[NSDictionary class]]) {
        callback(@[@(NO), @(-2), @"Message is invalid."]);
        return;
    }
    
    id msg = message[@"message"];
    NSNumber *type = message[@"type"];
    id convId = message[@"convId"];
    
    if (![msg isKindOfClass:[NSDictionary class]] || ![convId isKindOfClass:[NSString class]] || ![type isKindOfClass:[NSNumber class]]) {
        callback(@[@(NO), @(-2), @"Message is invalid."]);
        return;
    }
    
    __weak RNStringeeClient *weakSelf = self;
    
    // Lấy về conversation
    [_client getConversationWithConversationId:convId completionHandler:^(BOOL status, int code, NSString *message, StringeeConversation *conversation) {
        
        RNStringeeClient *strongSelf = weakSelf;
        if (!strongSelf) {
            callback(@[@(NO), @(-3), @"Conversation not found."]);
            return;
        }
        
        if (!conversation) {
            callback(@[@(NO), @(-3), @"Conversation not found."]);
            return;
        }
    
        if (!_client || !_client.hasConnected) {
            callback(@[@(NO), @(-1), @"StringeeClient is not initialized or connected."]);
            return;
        }
        
        // Lay data tu message -> khoi tao msg tuong ung trong native
        StringeeMessage *msgToSend;
        NSDictionary *dicMsg = (NSDictionary *)msg;
        
        switch (type.intValue) {
            case StringeeMessageTypeText:
            {
                NSString *text = dicMsg[@"content"];
                if (![text isKindOfClass:[NSString class]] || !text.length) {
                    callback(@[@(NO), @(-2), @"Message is invalid."]);
                    return;
                }
                msgToSend = [[StringeeTextMessage alloc] initWithText:text metadata:nil];
            }
                break;
                
            case StringeeMessageTypePhoto:
            {
                NSDictionary *photoDic = dicMsg[@"photo"];
                
                NSString *filePath = photoDic[@"filePath"];
                NSString *thumbnail = photoDic[@"thumbnail"] != nil ? photoDic[@"thumbnail"] : @"";
                NSNumber *ratio = photoDic[@"ratio"] != nil ? photoDic[@"ratio"] : @(1);

                if (![filePath isKindOfClass:[NSString class]] || !filePath.length) {
                    callback(@[@(NO), @(-2), @"Message is invalid."]);
                    return;
                }
                
                msgToSend = [[StringeePhotoMessage alloc] initWithFileUrl:filePath thumbnailUrl:thumbnail ratio:ratio.floatValue metadata:nil];
            }
                break;
                
            case StringeeMessageTypeVideo:
            {
                NSDictionary *videoDic = dicMsg[@"video"];

                NSString *filePath = videoDic[@"filePath"];
                NSString *thumbnail = videoDic[@"thumbnail"] != nil ? videoDic[@"thumbnail"] : @"";
                NSNumber *ratio = videoDic[@"ratio"] != nil ? videoDic[@"ratio"] : @(1);
                NSNumber *duration = videoDic[@"duration"] != nil ? videoDic[@"duration"] : @(0);

                if (![filePath isKindOfClass:[NSString class]] || !filePath.length) {
                    callback(@[@(NO), @(-2), @"Message is invalid."]);
                    return;
                }
                msgToSend = [[StringeeVideoMessage alloc] initWithFileUrl:filePath thumbnailUrl:thumbnail ratio:ratio.floatValue duration:duration.doubleValue metadata:nil];
            }
                break;
                
            case StringeeMessageTypeAudio:
            {
                NSDictionary *audioDic = dicMsg[@"audio"];

                NSString *filePath = audioDic[@"filePath"];
                NSNumber *duration = audioDic[@"duration"] != nil ? audioDic[@"duration"] : @(0);
                
                if (![filePath isKindOfClass:[NSString class]] || !filePath.length) {
                    callback(@[@(NO), @(-2), @"Message is invalid."]);
                    return;
                }
                msgToSend = [[StringeeAudioMessage alloc] initWithFileUrl:filePath duration:duration.doubleValue metadata:nil];
            }
                break;
                
            case StringeeMessageTypeFile:
            {
                NSDictionary *fileDic = dicMsg[@"file"];

                NSString *filePath = fileDic[@"filePath"];
                NSString *filename = fileDic[@"filename"] != nil ? fileDic[@"filename"] : @"";
                NSNumber *length = fileDic[@"length"] != nil ? fileDic[@"length"] : @(0);
                
                if (![filePath isKindOfClass:[NSString class]] || !filePath.length) {
                    callback(@[@(NO), @(-2), @"Message is invalid."]);
                    return;
                }
                msgToSend = [[StringeeFileMessage alloc] initWithFileUrl:filePath fileName:filename length:length.longLongValue metadata:nil];
            }
                break;
                
            case StringeeMessageTypeLink:
            {
                NSString *text = dicMsg[@"content"];
                if (![text isKindOfClass:[NSString class]] || !text.length) {
                    callback(@[@(NO), @(-2), @"Message is invalid."]);
                    return;
                }
                msgToSend = [[StringeeTextMessage alloc] initWithLink:text metadata:nil];
            }
                break;
                
            case StringeeMessageTypeLocation:
            {
                NSDictionary *locationDic = dicMsg[@"location"];

                NSNumber *lat = locationDic[@"lat"];
                NSNumber *lon = locationDic[@"lon"];
                
                if (!lat || !lon) {
                    callback(@[@(NO), @(-2), @"Message is invalid."]);
                    return;
                }
                msgToSend = [[StringeeLocationMessage alloc] initWithlatitude:lat.doubleValue longitude:lon.doubleValue metadata:nil];
            }
                break;
                
            case StringeeMessageTypeContact:
            {
                NSString *vcard = dicMsg[@"contact"][@"vcard"];
                if (![vcard isKindOfClass:[NSString class]] || !vcard.length) {
                    callback(@[@(NO), @(-2), @"Message is invalid."]);
                    return;
                }
                msgToSend = [[StringeeContactMessage alloc] initWithVcard:vcard metadata:nil];
            }
                break;
                
            case StringeeMessageTypeSticker:
            {
                NSDictionary *stickerDic = dicMsg[@"sticker"];

                NSString *category = stickerDic[@"category"];
                NSString *name = stickerDic[@"name"];

                if (![category isKindOfClass:[NSString class]] || !category.length || ![name isKindOfClass:[NSString class]] || !name.length) {
                    callback(@[@(NO), @(-2), @"Message is invalid."]);
                    return;
                }
                msgToSend = [[StringeeStickerMessage alloc] initWithCategory:category name:name metadata:nil];
            }
                break;
                
            default:
                callback(@[@(NO), @(-2), @"Message is invalid."]);
                return;
        }
        
        NSError *error;
        [strongSelf.messages setObject:msgToSend forKey:msgToSend.localIdentifier];
        
        [conversation sendMessageWithoutPretreatment:msgToSend error:&error];
        if (error) {
            callback(@[@(NO), @(1), @"Fail."]);
        } else {
            callback(@[@(YES), @(0), @"Success."]);
        }
    }];
}

RCT_EXPORT_METHOD(deleteMessage:(NSString *)conversationId msgId:(NSString *)msgId callback:(RCTResponseSenderBlock)callback) {

    if (!_client || !_client.hasConnected) {
        callback(@[@(NO), @(-1), @"StringeeClient is not initialized or connected."]);
        return;
    }
    
    if (!msgId.length) {
        callback(@[@(NO), @(-2), @"Message's id is invalid."]);
        return;
    }
    
    // Lấy về conversation
    [_client getConversationWithConversationId:conversationId completionHandler:^(BOOL status, int code, NSString *message, StringeeConversation *conversation) {
        if (!conversation) {
            callback(@[@(NO), @(-3), @"Conversation not found."]);
            return;
        }
        
        [conversation deleteMessageWithMessageIds:@[msgId] withCompletionHandler:^(BOOL status, int code, NSString *message) {
            callback(@[@(status), @(code), message]);
        }];
    }];
}

RCT_EXPORT_METHOD(getLocalMessages:(NSString *)conversationId count:(NSUInteger)count callback:(RCTResponseSenderBlock)callback) {
    
    if (!_client) {
        callback(@[@(NO), @(-1), @"StringeeClient is not initialized.", [NSNull null]]);
        return;
    }
    
    // Lấy về conversation
    [_client getConversationWithConversationId:conversationId completionHandler:^(BOOL status, int code, NSString *message, StringeeConversation *conversation) {
        if (!conversation) {
            callback(@[@(NO), @(-3), @"Conversation not found.", [NSNull null]]);
            return;
        }
        
        [conversation getLocalMessagesWithCount:count completionHandler:^(BOOL status, int code, NSString *message, NSArray<StringeeMessage *> *messages) {
            callback(@[@(status), @(code), message, [RCTConvert StringeeMessages:[[messages reverseObjectEnumerator] allObjects]]]);
        }];
    }];
}

RCT_EXPORT_METHOD(getLastMessages:(NSString *)conversationId count:(NSUInteger)count callback:(RCTResponseSenderBlock)callback) {
    
    if (!_client || !_client.hasConnected) {
        callback(@[@(NO), @(-1), @"StringeeClient is not initialized or connected."]);
        return;
    }

    // Lấy về conversation
    [_client getConversationWithConversationId:conversationId completionHandler:^(BOOL status, int code, NSString *message, StringeeConversation *conversation) {
        if (!conversation) {
            callback(@[@(NO), @(-3), @"Conversation not found.", [NSNull null]]);
            return;
        }
        
        [conversation getLastMessagesWithCount:count completionHandler:^(BOOL status, int code, NSString *message, NSArray<StringeeMessage *> *messages) {
            callback(@[@(status), @(code), message, [RCTConvert StringeeMessages:[[messages reverseObjectEnumerator] allObjects]]]);
        }];
    }];
}

RCT_EXPORT_METHOD(getMessagesAfter:(NSString *)conversationId sequence:(NSUInteger)sequence count:(NSUInteger)count callback:(RCTResponseSenderBlock)callback) {
    
    if (!_client || !_client.hasConnected) {
        callback(@[@(NO), @(-1), @"StringeeClient is not initialized or connected."]);
        return;
    }
    
    // Lấy về conversation
    [_client getConversationWithConversationId:conversationId completionHandler:^(BOOL status, int code, NSString *message, StringeeConversation *conversation) {
        if (!conversation) {
            callback(@[@(NO), @(-3), @"Conversation not found.", [NSNull null]]);
            return;
        }
        
        [conversation getMessagesAfter:sequence withCount:count completionHandler:^(BOOL status, int code, NSString *message, NSArray<StringeeMessage *> *messages) {
            callback(@[@(status), @(code), message, [RCTConvert StringeeMessages:messages]]);
        }];
    }];
}

RCT_EXPORT_METHOD(getMessagesBefore:(NSString *)conversationId sequence:(NSUInteger)sequence count:(NSUInteger)count callback:(RCTResponseSenderBlock)callback) {
    
    if (!_client || !_client.hasConnected) {
        callback(@[@(NO), @(-1), @"StringeeClient is not initialized or connected."]);
        return;
    }
    
    // Lấy về conversation
    [_client getConversationWithConversationId:conversationId completionHandler:^(BOOL status, int code, NSString *message, StringeeConversation *conversation) {
        if (!conversation) {
            callback(@[@(NO), @(-3), @"Conversation not found.", [NSNull null]]);
            return;
        }
        
        [conversation getMessagesBefore:sequence withCount:count completionHandler:^(BOOL status, int code, NSString *message, NSArray<StringeeMessage *> *messages) {
            callback(@[@(status), @(code), message, [RCTConvert StringeeMessages:[[messages reverseObjectEnumerator] allObjects]]]);
        }];
    }];
}

RCT_EXPORT_METHOD(markConversationAsRead:(NSString *)conversationId callback:(RCTResponseSenderBlock)callback) {
    
    if (!_client || !_client.hasConnected) {
        callback(@[@(NO), @(-1), @"StringeeClient is not initialized or connected."]);
        return;
    }
    
    // Lấy về conversation
    __weak RNStringeeClient *weakSelf = self;
    [_client getConversationWithConversationId:conversationId completionHandler:^(BOOL status, int code, NSString *message, StringeeConversation *conversation) {
        if (!conversation) {
            callback(@[@(NO), @(-3), @"Conversation not found."]);
            return;
        }
        
        [conversation markAllMessagesAsSeenWithCompletionHandler:^(BOOL status, int code, NSString *message) {
            if (status && [jsEvents containsObject:objectChangeNotification] && weakSelf != nil) {
                RNStringeeClient *strongSelf = weakSelf;
                [strongSelf sendEventWithName:objectChangeNotification body:@{ @"objectType" : @(0), @"objects" : @[[RCTConvert StringeeConversation:conversation]], @"changeType" : @(StringeeObjectChangeTypeUpdate) }];
            }
            callback(@[@(status), @(code), message]);
        }];
    }];
}

#pragma mark - ClearData

RCT_EXPORT_METHOD(clearDb:(RCTResponseSenderBlock)callback) {
    if (!_client) {
        callback(@[@(NO), @(-1), @"StringeeClient is not initialized."]);
        return;
    }
    
    [_client clearData];
    callback(@[@(YES), @(0), @"Success."]);
}

#pragma mark Handle chat event

- (void)handleObjectChangeNotification:(NSNotification *)notification {
    if (![jsEvents containsObject:objectChangeNotification]) return;
    
    NSArray *objectChanges = [notification.userInfo objectForKey:StringeeClientObjectChangesUserInfoKey];
    if (!objectChanges.count) {
        return;
    }
    
    NSMutableArray *objects = [[NSMutableArray alloc] init];
    
    for (StringeeObjectChange *objectChange in objectChanges) {
        [objects addObject:objectChange.object];
    }
    
    StringeeObjectChange *firstObjectChange = [objectChanges firstObject];
    id firstObject = [objects firstObject];
    
    int objectType;
    NSArray *jsObjectDatas;
    if ([firstObject isKindOfClass:[StringeeConversation class]]) {
        objectType = 0;
        jsObjectDatas = [RCTConvert StringeeConversations:objects];
    } else if ([firstObject isKindOfClass:[StringeeMessage class]]) {
        objectType = 1;
        jsObjectDatas = [RCTConvert StringeeMessages:objects];
        
        // Xoá đối tượng message đã lưu
        for (NSDictionary *message in jsObjectDatas) {
            NSNumber *state = message[@"state"];
            if (state.intValue == StringeeMessageStatusRead) {
                NSString *localId = message[@"localId"];
                if (localId) {
                    [_messages removeObjectForKey:localId];
                }
            }
        }
    } else {
        objectType = 2;
    }
    
    id returnObjects = jsObjectDatas ? jsObjectDatas : [NSNull null];
    
    [self sendEventWithName:objectChangeNotification body:@{ @"objectType" : @(objectType), @"objects" : returnObjects, @"changeType" : @(firstObjectChange.type) }];
}

- (void)handleNewMessageNotification:(NSNotification *)notification {
    if (![jsEvents containsObject:objectChangeNotification]) return;

    NSDictionary *userInfo = [notification userInfo];
    if (!userInfo) return;
    
    NSString *convId = [userInfo objectForKey:StringeeClientNewMessageConversationIDKey];
    if (convId == nil || convId.length == 0) {
        return;
    }
    
    // Lấy về conversation
    __weak RNStringeeClient *weakSelf = self;
    [_client getConversationWithConversationId:convId completionHandler:^(BOOL status, int code, NSString *message, StringeeConversation *conversation) {
        if (!conversation) {
            return;
        }
        if (weakSelf == nil) {
            return;
        }
        
        RNStringeeClient *strongSelf = weakSelf;
        [strongSelf sendEventWithName:objectChangeNotification body:@{ @"objectType" : @(0), @"objects" : @[[RCTConvert StringeeConversation:conversation]], @"changeType" : @(StringeeObjectChangeTypeCreate) }];
    }];
}

#pragma mark Enums

//- (NSDictionary *)constantsToExport
//{
//    return @{ @"Constants": @{
//                      @"StringeeMessageType": @{
//                              @"Text" : @(StringeeMessageTypeText),
//                              @"Photo" : @(StringeeMessageTypePhoto),
//                              @"Video" : @(StringeeMessageTypeVideo),
//                              @"Audio" : @(StringeeMessageTypeAudio),
//                              @"File" : @(StringeeMessageTypeFile),
//                              @"CreateGroup" : @(StringeeMessageTypeCreateGroup),
//                              @"RenameGroup" : @(StringeeMessageTypeRenameGroup),
//                              @"Location" : @(StringeeMessageTypeLocation),
//                              @"Contact" : @(StringeeMessageTypeContact),
//                              @"Notify" : @(StringeeMessageTypeNotify)
//                              },
//                      @"StringeeMessageStatus": @{
//                              @"Pending" : @(StringeeMessageStatusPending),
//                              @"Sending" : @(StringeeMessageStatusSending),
//                              @"Sent" : @(StringeeMessageStatusSent),
//                              @"Delivered" : @(StringeeMessageStatusDelivered),
//                              @"Read" : @(StringeeMessageStatusRead)
//                              }
//                      }
//              };
//};

@end
