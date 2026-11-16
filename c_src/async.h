#ifndef VIX_ASYNC_H
#define VIX_ASYNC_H

#include "erl_nif.h"
#include <glib.h>

typedef ERL_NIF_TERM (*VixNif)(ErlNifEnv *env, int argc,
                               const ERL_NIF_TERM argv[]);

/* Runs `nif(argv[1..])` on a thread and sends `{argv[0], result}` to the
 * caller */
ERL_NIF_TERM vix_async(ErlNifEnv *env, VixNif nif, int argc,
                       const ERL_NIF_TERM argv[]);

/* g_cond_wait() for a job. Frees its slot for other jobs while it waits */
void vix_async_wait(GCond *cond, GMutex *mutex);

int vix_async_init(ErlNifEnv *env);
void vix_async_stop(void);

#endif
