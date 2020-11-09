#ifndef VIX_VIPS_BOXED_H
#define VIX_VIPS_BOXED_H

#include "erl_nif.h"

ERL_NIF_TERM nif_int_array(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]);

ERL_NIF_TERM nif_double_array(ErlNifEnv *env, int argc,
                              const ERL_NIF_TERM argv[]);

#endif
