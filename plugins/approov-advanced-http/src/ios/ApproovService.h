/*
 * Copyright (c) 2018-2021 CriticalBlue Ltd.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated
 * documentation files (the "Software"), to deal in the Software without restriction, including without limitation the
 * rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to
 * permit persons to whom the Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all copies or substantial portions of the
 * Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
 * WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
 * COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
 * OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

#import <Foundation/Foundation.h>
#import "SM_AFHTTPSessionManager.h"


// Data access object for providing Approov results, which may be a successful string result or provide error information
@interface ApproovResult: NSObject

// result from the operation, which may be nil
@property (readonly, nullable) NSString *result;    

// an error type, such as "general", "network" or "rejection", or nil if no error
@property (readonly, nullable) NSString *errorType;

// any descriptive error message string, or nil if no error
@property (readonly, nullable) NSString *errorMessage;

// ARC associated with a rejection, or empty string if not enabled, or nil if not rejection
@property (readonly, nullable) NSString *rejectionARC;

// rejection reasons as a comma separated list, or empty string if not enabled, or nil if not rejection
@property (readonly, nullable) NSString *rejectionReasons;

- (nullable instancetype)init NS_UNAVAILABLE;
- (nullable instancetype)initWithResult:(nullable NSString *)result;
- (nullable instancetype)initWithErrorMessage:(nonnull NSString *)errorMessage isNetworkError:(BOOL)isNetworkError;
- (nullable instancetype)initWithRejectionErrorMessage:(nonnull NSString *)errorMessage rejectionARC:(nonnull NSString *)rejectionARC
    rejectionReasons:(nonnull NSString *)rejectionReasons;

@end

// ApproovService provides a mediation layer to the Approov SDK itself
@interface ApproovService: NSObject

- (ApproovResult *_Nonnull)initialize:(NSString *_Nonnull)config;
- (void)setProceedOnNetworkFail;
- (void)setTokenHeader:(NSString *_Nonnull)header prefix:(NSString *_Nonnull)prefix;
- (void)setBindingHeader:(NSString *_Nonnull)newHeader;
- (void)addSubstitutionHeader:(NSString *_Nonnull)header requiredPrefix:(NSString *_Nonnull)requiredPrefix;
- (void)removeSubstitutionHeader:(NSString *_Nonnull)header;
- (void)addSubstitutionQueryParam:(NSString *_Nonnull)key;
- (void)removeSubstitutionQueryParam:(NSString *_Nonnull)key;
- (void)addExclusionURLRegex:(NSString *_Nonnull)urlRegex;
- (void)removeExclusionURLRegex:(NSString *_Nonnull)urlRegex;
- (ApproovResult *_Nonnull)prefetch;
- (ApproovResult *_Nonnull)precheck;
- (ApproovResult *_Nonnull)getDeviceID;
- (ApproovResult *_Nonnull)setDataHashInToken:(NSString *_Nonnull)data;
- (ApproovResult *_Nonnull)fetchToken:(NSString *_Nonnull)url;
- (ApproovResult *_Nonnull)getMessageSignature:(NSString *_Nonnull)message;
- (ApproovResult *_Nonnull)fetchSecureString:(NSString *_Nonnull)key newDef:(NSString *_Nullable)newDef;
- (ApproovResult *_Nonnull)fetchCustomJWT:(NSString *_Nonnull)payload;
- (NSString *_Nonnull)addApproovToSessionManager:(SM_AFHTTPSessionManager *_Nonnull)manager URL:(NSString *_Nonnull)url;

@end
