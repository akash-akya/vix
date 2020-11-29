#ifndef VIX_VIPS_CONNECTION_H
#define VIX_VIPS_CONNECTION_H

#include "erl_nif.h"

ErlNifResourceType *VIX_CALLBACK_RESULT_RT;

typedef struct _VixCallbackResultResource {
  int *status;
  void *result;
} VixCallbackResultResource;

#endif
