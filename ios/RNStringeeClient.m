
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
    return self;
}

- (void)dealloc
{
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

        [self sendEventWithName:incomingCall body:@{ @"userId" : stringeeClient.userId, @"callId" : stringeeCall.callId, @"from" : stringeeCall.from, @"to" : stringeeCall.to, @"fromAlias" : stringeeCall.fromAlias, @"toAlias" : stringeeCall.toAlias, @"callType" : @(index), @"isVideoCall" : @(stringeeCall.isVideoCall), @"customDataFromYourServer" : stringeeCall.customDataFromYourServer}];
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
        callback(@[@(NO), @(-3), @"Conversation not found."]);
        return;
    }
    
    [_client getConversationWithConversationId:conversationId completionHandler:^(BOOL status, int code, NSString *message, StringeeConversation *conversation) {
        if (!conversation) {
            callback(@[@(NO), @(-3), @"Conversation not found."]);
            return;
        }
        [conversation deleteWithCompletionHandler:^(BOOL status, int code, NSString *message) {
            NSString *returnMsg = status ? @"Success." : @"Fail.";
            int returnCode = status ? 0 : 1;
            callback(@[@(status), @(returnCode), returnMsg]);
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
//    NSError *jsonError;
//    NSData *msgData = [message dataUsingEncoding:NSUTF8StringEncoding];
//    NSDictionary *dicData = [NSJSONSerialization JSONObjectWithData:msgData
//                                                         options:NSJSONReadingMutableContainers
//                                                           error:&jsonError];
    if (!message || ![message isKindOfClass:[NSDictionary class]]) {
        callback(@[@(NO), @(-2), @"Message is invalid."]);
        return;
    }
    
    NSError *jsonError;
    NSData *contentData = [NSJSONSerialization dataWithJSONObject:message
                                                       options:0 error:&jsonError];
    NSString *content = [[NSString alloc] initWithData:contentData
                                             encoding:NSUTF8StringEncoding];
    
    if (jsonError || !content.length) {
        callback(@[@(NO), @(-2), @"Message is invalid."]);
        return;
    }
    
    id text = message[@"text"];
    id type = message[@"type"];
    id conversationId = message[@"conversationId"];
    
    if (![text isKindOfClass:[NSString class]] || ![conversationId isKindOfClass:[NSString class]] || ![type isKindOfClass:[NSNumber class]]) {
        callback(@[@(NO), @(-2), @"Message is invalid."]);
        return;
    }
    
    // Lấy về conversation
    [_client getConversationWithConversationId:conversationId completionHandler:^(BOOL status, int code, NSString *message, StringeeConversation *conversation) {
        if (!conversation) {
            callback(@[@(NO), @(-3), @"Conversation not found."]);
            return;
        }
        
        NSError *error;

        // Gửi tất cả như text message
        StringeeTextMessage *textMsg = [[StringeeTextMessage alloc] initWithText:content metadata:nil];
        
        [conversation sendMessage:textMsg error:&error];
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
            callback(@[@(status), @(code), message, [RCTConvert StringeeMessages:messages]]);
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
            callback(@[@(status), @(code), message, [RCTConvert StringeeMessages:messages]]);
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
            callback(@[@(status), @(code), message, [RCTConvert StringeeMessages:messages]]);
        }];
    }];
}

RCT_EXPORT_METHOD(markConversationAsRead:(NSString *)conversationId callback:(RCTResponseSenderBlock)callback) {
    
    if (!_client || !_client.hasConnected) {
        callback(@[@(NO), @(-1), @"StringeeClient is not initialized or connected."]);
        return;
    }
    
    // Lấy về conversation
    [_client getConversationWithConversationId:conversationId completionHandler:^(BOOL status, int code, NSString *message, StringeeConversation *conversation) {
        if (!conversation) {
            callback(@[@(NO), @(-3), @"Conversation not found."]);
            return;
        }
        
        [conversation markAllMessagesAsSeenWithCompletionHandler:^(BOOL status, int code, NSString *message) {
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
    } else {
        objectType = 2;
    }
    
    id returnObjects = jsObjectDatas ? jsObjectDatas : [NSNull null];
    
    [self sendEventWithName:objectChangeNotification body:@{ @"objectType" : @(objectType), @"objects" : returnObjects, @"changeType" : @(firstObjectChange.type) }];
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
