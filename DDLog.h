#ifndef DEBUG_LEVEL
  #define DEBUG_LEVEL 0
#endif

#define DEBUG_ERROR   (DEBUG_LEVEL >= 1)
#define DEBUG_WARN    (DEBUG_LEVEL >= 2)
#define DEBUG_INFO    (DEBUG_LEVEL >= 3)
#define DEBUG_VERBOSE (DEBUG_LEVEL >= 4)

#define DDLogError(format, ...)    do{ if(DEBUG_ERROR)   NSLog((format), ##__VA_ARGS__); }while(0)
#define DDLogWarn(format, ...)     do{ if(DEBUG_WARN)    NSLog((format), ##__VA_ARGS__); }while(0)
#define DDLogInfo(format, ...)     do{ if(DEBUG_INFO)    NSLog((format), ##__VA_ARGS__); }while(0)
#define DDLogVerbose(format, ...)  do{ if(DEBUG_VERBOSE) NSLog((format), ##__VA_ARGS__); }while(0)

/**
 * The THIS_FILE macro gives you an NSString of the file name.
 * For simplicity and clarity, the file name does not include the full path or file extension.
 * 
 * For example: DDLogWarn(@"%@: Unable to find thingy", THIS_FILE) -> @"MyVC: Unable to find thingy"
 **/

#define THIS_FILE ([[[NSString stringWithUTF8String:(__FILE__)] lastPathComponent] stringByDeletingPathExtension])

/**
 * The THIS_METHOD macro gives you the name of the current objective-c method.
 * 
 * For example: DDLogWarn(@"%@ - Requires non-nil string") -> @"setMake:model: requires non-nil string"
 * 
 * Note: This does NOT work in straight C functions (non objective-c).
 * Instead you should use the predefined __FUNCTION__ macro.
**/

#define THIS_METHOD NSStringFromSelector(_cmd)

/**
 * Convenience trace macro. Depends on DEBUG_VERBOSE.
 * 
 * For example: DDLogTrace() -> @"MyVC: viewDidLoad"
**/

#define DDLogTrace() do{ if(DEBUG_VERBOSE) NSLog(@"%@: %@", THIS_FILE, THIS_METHOD); }while(0)
