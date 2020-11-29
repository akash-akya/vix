#ifndef VIX_VIPS_CONNECTION_H
#define VIX_VIPS_CONNECTION_H

#include "erl_nif.h"

ErlNifResourceType *VIX_CALLBACK_RT;

typedef struct _VixCallbackResource {
  ErlNifMutex *lock;
  ErlNifCond *cond;

  gint64 size;
  void *result;
  int status;
} VixCallbackResource;

ERL_NIF_TERM nif_vips_source_new(ErlNifEnv *env, int argc,
                                 const ERL_NIF_TERM argv[]);

ERL_NIF_TERM nif_vips_conn_write_result(ErlNifEnv *env, int argc,
                                        const ERL_NIF_TERM argv[]);

int nif_vips_connection_init(ErlNifEnv *env);

#endif
