/**
 * In order to provide fast and flexible logging, this project uses Cocoa Lumberjack.
 * 
 * The GitHub project page has a wealth of documentation if you have any questions.
 * https://github.com/robbiehanson/CocoaLumberjack
 * 
 * Here's what you need to know concerning how logging is setup for XMPPFramework:
 * 
 * There are 4 log levels:
 * - Error
 * - Warning
 * - Info
 * - Verbose
 * 
 * In addition to this, there is a Trace flag that can be enabled.
 * When tracing is enabled, it spits out the methods that are being called.
 * 
 * Please note that tracing is separate from the log levels.
 * For example, one could set the log level to warning, and enable tracing.
 * 
 * All logging is asynchronous, except errors.
 * To use logging within your own custom files, follow the steps below.
 * 
 * Step 1:
 * Import this header in your implementation file:
 * 
 * #import "XMPPLogging.h"
 * 
 * Step 2:
 * Define your logging level in your implementation file:
 * 
 * // Log levels: off, error, warn, info, verbose
 * static const int xmppLogLevel = XMPP_LOG_LEVEL_VERBOSE;
 * 
 * If you wish to enable tracing, you could do something like this:
 * 
 * // Log levels: off, error, warn, info, verbose
 * static const int xmppLogLevel = XMPP_LOG_LEVEL_INFO | XMPP_LOG_FLAG_TRACE;
 * 
 * Step 3:
 * Replace your NSLog statements with XMPPLog statements according to the severity of the message.
 * 
 * NSLog(@"Fatal error, no dohickey found!"); -> XMPPLogError(@"Fatal error, no dohickey found!");
 * 
 * XMPPLog has the same syntax as NSLog.
 * This means you can pass it multiple variables just like NSLog.
 * 
 * You may optionally choose to define different log levels for debug and release builds.
 * You can do so like this:
 * 
 * // Log levels: off, error, warn, info, verbose
 * #if DEBUG
 *   static const int xmppLogLevel = XMPP_LOG_LEVEL_VERBOSE;
 * #else
 *   static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN;
 * #endif
 * 
 * Xcode projects created with Xcode 4 automatically define DEBUG via the project's preprocessor macros.
 * If you created your project with a previous version of Xcode, you may need to add the DEBUG macro manually.
**/

@import CocoaLumberjack;

// Global flag to enable/disable logging throughout the entire xmpp framework.

#ifndef XMPP_LOGGING_ENABLED
#define XMPP_LOGGING_ENABLED 1
#endif

// Define logging context for every log message coming from the XMPP framework.
// The logging context can be extracted from the DDLogMessage from within the logging framework.
// This gives loggers, formatters, and filters the ability to optionally process them differently.

#define XMPP_LOG_CONTEXT 5222

// Configure log levels.

#define XMPP_LOG_FLAG_ERROR   (1 << 0) // 0...00001
#define XMPP_LOG_FLAG_WARN    (1 << 1) // 0...00010
#define XMPP_LOG_FLAG_INFO    (1 << 2) // 0...00100
#define XMPP_LOG_FLAG_VERBOSE (1 << 3) // 0...01000

#define XMPP_LOG_LEVEL_OFF     0                                              // 0...00000
#define XMPP_LOG_LEVEL_ERROR   (XMPP_LOG_LEVEL_OFF   | XMPP_LOG_FLAG_ERROR)   // 0...00001
#define XMPP_LOG_LEVEL_WARN    (XMPP_LOG_LEVEL_ERROR | XMPP_LOG_FLAG_WARN)    // 0...00011
#define XMPP_LOG_LEVEL_INFO    (XMPP_LOG_LEVEL_WARN  | XMPP_LOG_FLAG_INFO)    // 0...00111
#define XMPP_LOG_LEVEL_VERBOSE (XMPP_LOG_LEVEL_INFO  | XMPP_LOG_FLAG_VERBOSE) // 0...01111

// Setup fine grained logging.
// The first 4 bits are being used by the standard log levels (0 - 3)
// 
// We're going to add tracing, but NOT as a log level.
// Tracing can be turned on and off independently of log level.

#define XMPP_LOG_FLAG_TRACE     (1 << 4) // 0...10000

// Setup the usual boolean macros.

#define XMPP_LOG_ERROR   (xmppLogLevel & XMPP_LOG_FLAG_ERROR)
#define XMPP_LOG_WARN    (xmppLogLevel & XMPP_LOG_FLAG_WARN)
#define XMPP_LOG_INFO    (xmppLogLevel & XMPP_LOG_FLAG_INFO)
#define XMPP_LOG_VERBOSE (xmppLogLevel & XMPP_LOG_FLAG_VERBOSE)
#define XMPP_LOG_TRACE   (xmppLogLevel & XMPP_LOG_FLAG_TRACE)

// Configure asynchronous logging.
// We follow the default configuration,
// but we reserve a special macro to easily disable asynchronous logging for debugging purposes.

#if DEBUG
#define XMPP_LOG_ASYNC_ENABLED  NO
#else
#define XMPP_LOG_ASYNC_ENABLED  YES
#endif

#define XMPP_LOG_ASYNC_ERROR     ( NO && XMPP_LOG_ASYNC_ENABLED)
#define XMPP_LOG_ASYNC_WARN      (YES && XMPP_LOG_ASYNC_ENABLED)
#define XMPP_LOG_ASYNC_INFO      (YES && XMPP_LOG_ASYNC_ENABLED)
#define XMPP_LOG_ASYNC_VERBOSE   (YES && XMPP_LOG_ASYNC_ENABLED)
#define XMPP_LOG_ASYNC_TRACE     (YES && XMPP_LOG_ASYNC_ENABLED)

// Define logging primitives.
// These are primarily wrappers around the macros defined in Lumberjack's DDLog.h header file.

#define XMPP_LOG_OBJC_MAYBE(async, lvl, flg, ctx, frmt, ...) \
do{ if(XMPP_LOGGING_ENABLED) LOG_MAYBE(async, lvl, flg, ctx, nil, sel_getName(_cmd), frmt, ##__VA_ARGS__); } while(0)

#define XMPP_LOG_C_MAYBE(async, lvl, flg, ctx, frmt, ...) \
    do{ if(XMPP_LOGGING_ENABLED) LOG_MAYBE(async, lvl, flg, ctx, nil, __FUNCTION__, frmt, ##__VA_ARGS__); } while(0)


#define XMPPLogError(frmt, ...)    XMPP_LOG_OBJC_MAYBE(XMPP_LOG_ASYNC_ERROR,   xmppLogLevel, XMPP_LOG_FLAG_ERROR,  \
                                                  XMPP_LOG_CONTEXT, frmt, ##__VA_ARGS__)

#define XMPPLogWarn(frmt, ...)     XMPP_LOG_OBJC_MAYBE(XMPP_LOG_ASYNC_WARN,    xmppLogLevel, XMPP_LOG_FLAG_WARN,   \
                                                  XMPP_LOG_CONTEXT, frmt, ##__VA_ARGS__)

#define XMPPLogInfo(frmt, ...)     XMPP_LOG_OBJC_MAYBE(XMPP_LOG_ASYNC_INFO,    xmppLogLevel, XMPP_LOG_FLAG_INFO,    \
                                                  XMPP_LOG_CONTEXT, frmt, ##__VA_ARGS__)

#define XMPPLogVerbose(frmt, ...)  XMPP_LOG_OBJC_MAYBE(XMPP_LOG_ASYNC_VERBOSE, xmppLogLevel, XMPP_LOG_FLAG_VERBOSE, \
                                                  XMPP_LOG_CONTEXT, frmt, ##__VA_ARGS__)

#define XMPPLogTrace()             XMPP_LOG_OBJC_MAYBE(XMPP_LOG_ASYNC_TRACE,   xmppLogLevel, XMPP_LOG_FLAG_TRACE, \
                                                  XMPP_LOG_CONTEXT, @"%@: %@", THIS_FILE, THIS_METHOD)

#define XMPPLogTrace2(frmt, ...)   XMPP_LOG_OBJC_MAYBE(XMPP_LOG_ASYNC_TRACE,   xmppLogLevel, XMPP_LOG_FLAG_TRACE, \
                                                  XMPP_LOG_CONTEXT, frmt, ##__VA_ARGS__)


#define XMPPLogCError(frmt, ...)      XMPP_LOG_C_MAYBE(XMPP_LOG_ASYNC_ERROR,   xmppLogLevel, XMPP_LOG_FLAG_ERROR,   \
                                                  XMPP_LOG_CONTEXT, frmt, ##__VA_ARGS__)

#define XMPPLogCWarn(frmt, ...)       XMPP_LOG_C_MAYBE(XMPP_LOG_ASYNC_WARN,    xmppLogLevel, XMPP_LOG_FLAG_WARN,    \
                                                  XMPP_LOG_CONTEXT, frmt, ##__VA_ARGS__)

#define XMPPLogCInfo(frmt, ...)       XMPP_LOG_C_MAYBE(XMPP_LOG_ASYNC_INFO,    xmppLogLevel, XMPP_LOG_FLAG_INFO,    \
                                                  XMPP_LOG_CONTEXT, frmt, ##__VA_ARGS__)

#define XMPPLogCVerbose(frmt, ...)    XMPP_LOG_C_MAYBE(XMPP_LOG_ASYNC_VERBOSE, xmppLogLevel, XMPP_LOG_FLAG_VERBOSE, \
                                                  XMPP_LOG_CONTEXT, frmt, ##__VA_ARGS__)

#define XMPPLogCTrace()               XMPP_LOG_C_MAYBE(XMPP_LOG_ASYNC_TRACE,   xmppLogLevel, XMPP_LOG_FLAG_TRACE, \
                                                  XMPP_LOG_CONTEXT, @"%@: %s", THIS_FILE, __FUNCTION__)

#define XMPPLogCTrace2(frmt, ...)     XMPP_LOG_C_MAYBE(XMPP_LOG_ASYNC_TRACE,   xmppLogLevel, XMPP_LOG_FLAG_TRACE, \
                                                  XMPP_LOG_CONTEXT, frmt, ##__VA_ARGS__)

// Setup logging for XMPPStream (and subclasses such as XMPPStreamFacebook)

#define XMPP_LOG_FLAG_SEND      (1 << 5)
#define XMPP_LOG_FLAG_RECV_PRE  (1 << 6) // Prints data before it goes to the parser
#define XMPP_LOG_FLAG_RECV_POST (1 << 7) // Prints data as it comes out of the parser

#define XMPP_LOG_FLAG_SEND_RECV (XMPP_LOG_FLAG_SEND | XMPP_LOG_FLAG_RECV_POST)

#define XMPP_LOG_SEND      (xmppLogLevel & XMPP_LOG_FLAG_SEND)
#define XMPP_LOG_RECV_PRE  (xmppLogLevel & XMPP_LOG_FLAG_RECV_PRE)
#define XMPP_LOG_RECV_POST (xmppLogLevel & XMPP_LOG_FLAG_RECV_POST)

#define XMPP_LOG_ASYNC_SEND      (YES && XMPP_LOG_ASYNC_ENABLED)
#define XMPP_LOG_ASYNC_RECV_PRE  (YES && XMPP_LOG_ASYNC_ENABLED)
#define XMPP_LOG_ASYNC_RECV_POST (YES && XMPP_LOG_ASYNC_ENABLED)

#define XMPPLogSend(format, ...)     XMPP_LOG_OBJC_MAYBE(XMPP_LOG_ASYNC_SEND, xmppLogLevel, \
                                                XMPP_LOG_FLAG_SEND, XMPP_LOG_CONTEXT, format, ##__VA_ARGS__)

#define XMPPLogRecvPre(format, ...)  XMPP_LOG_OBJC_MAYBE(XMPP_LOG_ASYNC_RECV_PRE, xmppLogLevel, \
                                                XMPP_LOG_FLAG_RECV_PRE, XMPP_LOG_CONTEXT, format, ##__VA_ARGS__)

#define XMPPLogRecvPost(format, ...) XMPP_LOG_OBJC_MAYBE(XMPP_LOG_ASYNC_RECV_POST, xmppLogLevel, \
                                                XMPP_LOG_FLAG_RECV_POST, XMPP_LOG_CONTEXT, format, ##__VA_ARGS__)
