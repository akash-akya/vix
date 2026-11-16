#ifndef VIX_PIPE_H
#define VIX_PIPE_H

#include "erl_nif.h"

ERL_NIF_TERM nif_target_new(ErlNifEnv *env, int argc,
                            const ERL_NIF_TERM argv[]);

ERL_NIF_TERM nif_read(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]);

int nif_pipe_init(ErlNifEnv *env);

#endif
