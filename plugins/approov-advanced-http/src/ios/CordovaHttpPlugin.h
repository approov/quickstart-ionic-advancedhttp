#import <Foundation/Foundation.h>

#import <Cordova/CDVPlugin.h>

@interface CordovaHttpPlugin : CDVPlugin

- (void)setServerTrustMode:(CDVInvokedUrlCommand*)command;
- (void)setClientAuthMode:(CDVInvokedUrlCommand*)command;
- (void)post:(CDVInvokedUrlCommand*)command;
- (void)put:(CDVInvokedUrlCommand*)command;
- (void)patch:(CDVInvokedUrlCommand*)command;
- (void)get:(CDVInvokedUrlCommand*)command;
- (void)delete:(CDVInvokedUrlCommand*)command;
- (void)head:(CDVInvokedUrlCommand*)command;
- (void)options:(CDVInvokedUrlCommand*)command;
- (void)uploadFiles:(CDVInvokedUrlCommand*)command;
- (void)downloadFile:(CDVInvokedUrlCommand*)command;
- (void)abort:(CDVInvokedUrlCommand*)command;
- (void)approovInitialize:(CDVInvokedUrlCommand*)command;
- (void)approovSetProceedOnNetworkFail:(CDVInvokedUrlCommand*)command;
- (void)approovTokenHeader:(CDVInvokedUrlCommand*)command;
- (void)approovAddSubstitutionHeader:(CDVInvokedUrlCommand*)command;
- (void)approovRemoveSubstitutionHeader:(CDVInvokedUrlCommand*)command;
- (void)approovAddSubstitutionQueryParam:(CDVInvokedUrlCommand*)command;
- (void)approovRemoveSubstitutionQueryParam:(CDVInvokedUrlCommand*)command;
- (void)approovPrefetch:(CDVInvokedUrlCommand*)command;
- (void)approovPrecheck:(CDVInvokedUrlCommand*)command;
- (void)approovGetDeviceID:(CDVInvokedUrlCommand*)command;
- (void)approovSetDataHashInToken:(CDVInvokedUrlCommand*)command;
- (void)approovFetchToken:(CDVInvokedUrlCommand*)command;
- (void)approovFetchSecureString:(CDVInvokedUrlCommand*)command;
- (void)approovFetchCustomJWT:(CDVInvokedUrlCommand*)command;

@end
