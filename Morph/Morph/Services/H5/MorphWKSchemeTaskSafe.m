#import "MorphWKSchemeTaskSafe.h"

@implementation MorphWKSchemeTaskSafe

+ (BOOL)perform:(void (NS_NOESCAPE ^)(void))block {
    if (block == nil) {
        return NO;
    }
    @try {
        block();
        return YES;
    } @catch (NSException *exception) {
        return NO;
    }
}

+ (BOOL)receiveResponse:(id<WKURLSchemeTask>)task response:(NSURLResponse *)response {
    return [self perform:^{
        [task didReceiveResponse:response];
    }];
}

+ (BOOL)receiveData:(id<WKURLSchemeTask>)task data:(NSData *)data {
    return [self perform:^{
        [task didReceiveData:data];
    }];
}

+ (BOOL)finish:(id<WKURLSchemeTask>)task {
    return [self perform:^{
        [task didFinish];
    }];
}

+ (BOOL)fail:(id<WKURLSchemeTask>)task error:(NSError *)error {
    return [self perform:^{
        [task didFailWithError:error];
    }];
}

@end
