#ifndef VIX_VIPS_INTERPOLATE_H
#define VIX_VIPS_INTERPOLATE_H

#include "erl_nif.h"

ERL_NIF_TERM nif_interpolate_new(ErlNifEnv *env, int argc,
                                 const ERL_NIF_TERM argv[]);

#endif
