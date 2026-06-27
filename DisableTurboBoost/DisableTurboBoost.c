/*
 * DisableTurboBoost.c
 *
 * Minimal kernel extension to disable Intel Turbo Boost by setting bit 38
 * of MSR 0x1A0 (IA32_MISC_ENABLE) on all CPU cores.
 *
 * On load:   sets bit 38 → Turbo Boost disabled
 * On unload: clears bit 38 → Turbo Boost re-enabled
 */

#include <mach/mach_types.h>
#include <kern/assert.h>
#include <i386/proc_reg.h>

#define TURBO_DISABLE_BIT    (1ULL << 38)

extern void mp_rendezvous_no_intrs(void (*action)(void *), void *arg);

kern_return_t DisableTurboBoost_start(kmod_info_t *ki, void *d);
kern_return_t DisableTurboBoost_stop(kmod_info_t *ki, void *d);

KMOD_EXPLICIT_DECL(com.local.DisableTurboBoost, "1.0.0", DisableTurboBoost_start, DisableTurboBoost_stop)

static void disable_turbo_boost(__unused void *arg)
{
    uint64_t msr = rdmsr64(MSR_IA32_MISC_ENABLE);
    wrmsr64(MSR_IA32_MISC_ENABLE, msr | TURBO_DISABLE_BIT);
}

static void enable_turbo_boost(__unused void *arg)
{
    uint64_t msr = rdmsr64(MSR_IA32_MISC_ENABLE);
    wrmsr64(MSR_IA32_MISC_ENABLE, msr & ~TURBO_DISABLE_BIT);
}

kern_return_t DisableTurboBoost_start(kmod_info_t *ki __unused, void *d __unused)
{
    mp_rendezvous_no_intrs(disable_turbo_boost, NULL);
    return KERN_SUCCESS;
}

kern_return_t DisableTurboBoost_stop(kmod_info_t *ki __unused, void *d __unused)
{
    mp_rendezvous_no_intrs(enable_turbo_boost, NULL);
    return KERN_SUCCESS;
}
