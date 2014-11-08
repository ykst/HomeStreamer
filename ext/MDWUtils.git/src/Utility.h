// Copyright (c) 2014 Yohsuke Yukishita
// This software is released under the MIT License: http://opensource.org/licenses/mit-license.php
#ifndef _VideoStreamer_Utility_h_
#define _VideoStreamer_Utility_h_

#include <mach/mach_time.h>

#ifndef likely
# ifdef __builtin_expect
# define likely(x) __builtin_expect((x), 1)
# else
# define likely(x) (x)
# endif
#endif

#ifndef unlikely
# ifdef __builtin_expect
# define unlikely(x) __builtin_expect((x), 0)
# else
# define unlikely(x) (x)
# endif
#endif

#define ERROR(fmt, ...)  NSLog(@"ERROR :%s:%s:%d: " fmt, __BASE_FILE__, __FUNCTION__, __LINE__, ##__VA_ARGS__)

#ifdef DEBUG
#   define WARN(fmt, ...) NSLog(@"WARN :%s:%s:%d: " fmt, __BASE_FILE__, __FUNCTION__, __LINE__, ##__VA_ARGS__)
#   define INFO(fmt, ...) NSLog(@"INFO :%s:%s:%d: " fmt, __BASE_FILE__, __FUNCTION__, __LINE__, ##__VA_ARGS__)
#   define DBG(fmt, ...) NSLog(@"DBG :%s:%s:%d: " fmt, __BASE_FILE__, __FUNCTION__, __LINE__, ##__VA_ARGS__)
#   define MASSERT(b,action,fmt,...) ({bool __b = (bool)(b); if(unlikely(!(__b))){ ERROR(@"failed (%s): " fmt, #b, ##__VA_ARGS__);action;} __b;})
#   define MEXPECT(b,action,fmt,...) ({bool __b = (bool)(b); if(unlikely(!(__b))){ WARN(@"not expected (%s): " fmt, #b, ##__VA_ARGS__);action;} __b;})
#   define MCHECK(b,action,fmt,...) ({bool __b = (bool)(b);if(unlikely(!(__b))){ DBG(@"? (%s): " fmt, #b, ##__VA_ARGS__);action;} __b;})
#else
#   define WARN(fmt, ...)
#   define INFO(fmt, ...)
#   define DBG(fmt, ...)
#   define MASSERT(b,action,fmt,...) ({bool __b = (bool)(b); if(unlikely(!(__b))){ ERROR(@"failed: " fmt, ##__VA_ARGS__);action;} __b;})
#   define MEXPECT(b,action,fmt,...) ({bool __b = (bool)(b); if(unlikely(!(__b))){ WARN(@"not expected: " fmt, #b, ##__VA_ARGS__);action;} __b;})
#   define MCHECK(b,action,fmt,...) ({bool __b = (bool)(b);if(unlikely(!(__b))){ DBG(@"?: " fmt, ##__VA_ARGS__);action;} __b;})
#endif

#define ECHECK do {ERROR("(#-_-)p");} while (0)
#define DCHECK do {DBG("(*^-^)v");} while (0)
#define ICHECK do {INFO("(*^-^)b");} while (0)

#ifdef DEBUG
#define DUMPF(x) printf("%s = %.3f\n", #x, (double) (x))
#define DUMPD(x) printf("%s = %d\n", #x, (int) (x))
#define DUMPUL(x) printf("%s = %llu\n", #x, (uint64_t) (x))
#define DUMPZ(x) printf("%s = %zu\n", #x, (size_t) (x))
#define DUMPP(x) printf("%s = %p\n", #x, (const void *) (x))
#define DUMPS(x) printf("%s = %s\n", #x,  [(x) UTF8String])
#define DUMPCS(x) printf("%s = %s\n", #x, (const char *) (x))
#define DUMPC(x) printf("%s = %c\n", #x, (char) (x))
#define DUMP8(x) printf("%s = 0x%02x\n", #x, (uint8_t) (x))
#define DUMP16(x) printf("%s = 0x%04x\n", #x, (uint16_t) (x))
#define DUMP32(x) printf("%s = 0x%08x\n", #x, (uint32_t) (x))
#define DUMP64(x) printf("%s = 0x%016llx\n", #x, (uint64_t) (x))
#define DUMPIP4(x) do { char str[128]; inet_ntop( AF_INET, &(x), str, INET_ADDRSTRLEN );printf("%s = %s\n", #x, str); } while(0)
#else
#define DUMPF(x)
#define DUMPD(x)
#define DUMPUL(x)
#define DUMPZ(x)
#define DUMPP(x)
#define DUMPS(x)
#define DUMPCS(x)
#define DUMPC(x)
#define DUMP8(x)
#define DUMP16(x)
#define DUMP32(x)
#define DUMP64(x)
#define DUMPIP4(x)
#endif

#define ALLOC(t) (t = (typeof(t))calloc(1,sizeof(typeof(*(t)))))
#define TALLOC(h,action) do {h=NULL;if(!(ALLOC(h))){ERROR("Cannot alloc %zuB",sizeof(*(h)));action;}} while (0)
#define TALLOCS(h,num,action) ({typeof(num) __num = (num); if(!((h) = (typeof (h))(calloc((sizeof (*(h))), __num)))){ERROR("Cannot alloc %zuB",(size_t)(sizeof(*(h))*__num));action;} })
#define FREE(h) do {if(h){free(h);(h)=NULL;}} while (0);

#define ASSERT(b,action) MASSERT(b,action,@"")
#define EXPECT(b,action) MEXPECT(b,action,@"")
#define CHECK(b,action) MCHECK(b,action,@"")

#ifdef DEBUG
# define DASSERT(b,action) MASSERT(b,action,"(debug)")
#else
# define DASSERT(b,action)
#endif

#define NSSTR(s) [NSString stringWithCString: (s) encoding:NSUTF8StringEncoding]
#define NSPRINTF(fmt, ...) [NSString stringWithFormat:(fmt), ##__VA_ARGS__]

#define ONCE(action) do {\
static dispatch_once_t ____once_token;\
dispatch_once(&____once_token, ^{\
action;\
});\
} while(0)

#define STRINGIFY(x) #x
#define STRINGIFY2(x) STRINGIFY(x)
#define NSSTRINGIFY(text) @ STRINGIFY2(text)

#define NSASSERT(b) NSAssert((b), @"NSAssert on %s:%s:%d:(%s)", __BASE_FILE__, __FUNCTION__, __LINE__, STRINGIFY2(b))

#define NSPOINTER(ptr) ([NSValue valueWithPointer:(ptr)])

static inline bool ____benchmark_check_time(char const * const comment, uint64_t const start, uint64_t const tick)
{
    if (!tick) return true;
    uint64_t const elapsed = mach_absolute_time() - start;
    mach_timebase_info_data_t base;
    mach_timebase_info(&base);

    uint64_t const nsec = elapsed * base.numer / base.denom;
    printf("%s: %.3fms\n", comment, nsec / 1000000.0);
    return false;
}

#define IS_IPHONE ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone)
#define SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(v) ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedAscending)
#define IS_IOS6 (!SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"7.0"))

#ifdef DEBUG
#define ENABLE_BENCHMARK
#endif
#ifdef ENABLE_BENCHMARK
#define BENCHMARK(comment) for(uint64_t ____tick = 0, ____start = mach_absolute_time(); ____benchmark_check_time(comment, ____start, ____tick); ++____tick)
#else
#define BENCHMARK(comment)
#endif
#endif


