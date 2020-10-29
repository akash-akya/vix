#ifndef NIF_VIPS_BOXED_H
#define NIF_VIPS_BOXED_H

#ifndef _POSIX_C_SOURCE
#define _POSIX_C_SOURCE 200809L
#endif

#include "erl_nif.h"
#include <vips/vips.h>

ERL_NIF_TERM nif_int_array(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]);

ERL_NIF_TERM nif_double_array(ErlNifEnv *env, int argc,
                              const ERL_NIF_TERM argv[]);

#endif
