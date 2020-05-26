
#import <Foundation/Foundation.h>
#import "RNStringeeClient.h"
#import "RNStringeeCall.h"
#import "RNStringeeRoom.h"
#import "RNClientWrapper.h"

@interface RNStringeeInstanceManager : NSObject

+ (RNStringeeInstanceManager*)instance;

@property(strong, nonatomic) RNStringeeClient *rnClient;
@property(strong, nonatomic) RNStringeeCall *rnCall;
@property(strong, nonatomic) RNStringeeRoom *rnRoom;

@property(strong, nonatomic) NSMutableDictionary *calls;

@property(strong, nonatomic) NSMutableDictionary<NSString *, RNClientWrapper *> *clientWrappers;

@end
