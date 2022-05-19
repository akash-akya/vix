#ifndef VIX_PIPE_H
#define VIX_PIPE_H

#include "erl_nif.h"

extern ErlNifResourceType *G_OBJECT_RT;

ERL_NIF_TERM nif_pipe_open(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]);

ERL_NIF_TERM nif_write(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]);

ERL_NIF_TERM nif_read(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]);

ERL_NIF_TERM nif_source_new(ErlNifEnv *env, int argc,
                            const ERL_NIF_TERM argv[]);

ERL_NIF_TERM nif_target_new(ErlNifEnv *env, int argc,
                            const ERL_NIF_TERM argv[]);

int nif_pipe_init(ErlNifEnv *env);

#endif
