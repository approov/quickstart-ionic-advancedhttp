//
// MIT License
// 
// Copyright (c) 2016-present, Critical Blue Ltd.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files
// (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge,
// publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so,
// subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR
// ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH
// THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

package com.silkimen.approov;

/**
 * Data access object for providing Approov results, which may be a successful string result or provide error information.
 */
public class ApproovResult {
    // result from the operation, which may be null
    public String result;

    // an error type, such as "general", "network" or "rejection", or null if no error
    public String errorType;

    // message associated with any error, or null otherwise
    public String errorMessage;

    // ARC associated with an rejection, or empty string if not enabled, or null if not rejection
    public String rejectionARC;

    // rejection reasons as a comma separated list, or empty string if not enabled, or null if not rejection
    public String rejectionReasons;

    /**
     * Construct a valid Approov result.
     * 
     * @param result the result, which may be null
     */
    public ApproovResult(String result) {
        this.result = result;
    }

    /**
     * Construct an error Approov result.
     * 
     * @param errorMessage the descriptive error message
     * @param isNetworkError is true for a network, as opposed to general, error type
     */
    public ApproovResult(String errorMessage, boolean isNetworkError) {
        this.errorType = "general";
        if (isNetworkError)
            this.errorType = "network";
        this.errorMessage = errorMessage;
    }

    /**
     * Construct a rejection Approov error result.
     * 
     * @param errorMessage the descriptive rejection error message
     * @param rejectionARC the ARC or empty string if not enabled
     * @param rejectionReasons the rejection reasons or empty string if not enabled
     */
    public ApproovResult(String errorMessage, String rejectionARC, String rejectionReasons) {
        this.errorType = "rejection";
        this.errorMessage = errorMessage;
        this.rejectionARC = rejectionARC;
        this.rejectionReasons = rejectionReasons;
    }
}
