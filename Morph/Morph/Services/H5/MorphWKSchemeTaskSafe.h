#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface MorphWKSchemeTaskSafe : NSObject

+ (BOOL)receiveResponse:(id<WKURLSchemeTask>)task response:(NSURLResponse *)response;
+ (BOOL)receiveData:(id<WKURLSchemeTask>)task data:(NSData *)data;
+ (BOOL)finish:(id<WKURLSchemeTask>)task;
+ (BOOL)fail:(id<WKURLSchemeTask>)task error:(NSError *)error;

@end

NS_ASSUME_NONNULL_END
