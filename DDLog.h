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
