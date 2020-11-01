#ifndef NIF_VIPS_OPERATION_H
#define NIF_VIPS_OPERATION_H

#ifndef _POSIX_C_SOURCE
#define _POSIX_C_SOURCE 200809L
#endif

#include "erl_nif.h"

ERL_NIF_TERM nif_vips_operation_call(ErlNifEnv *env, int argc,
                                     const ERL_NIF_TERM argv[]);

ERL_NIF_TERM nif_vips_operation_get_arguments(ErlNifEnv *env, int argc,
                                              const ERL_NIF_TERM argv[]);

ERL_NIF_TERM nif_vips_operation_list(ErlNifEnv *env, int argc,
                                     const ERL_NIF_TERM argv[]);

ERL_NIF_TERM nif_vips_cache_set_max(ErlNifEnv *env, int argc,
                                    const ERL_NIF_TERM argv[]);

ERL_NIF_TERM nif_vips_cache_get_max(ErlNifEnv *env, int argc,
                                    const ERL_NIF_TERM argv[]);

ERL_NIF_TERM nif_vips_concurrency_set(ErlNifEnv *env, int argc,
                                      const ERL_NIF_TERM argv[]);

ERL_NIF_TERM nif_vips_concurrency_get(ErlNifEnv *env, int argc,
                                      const ERL_NIF_TERM argv[]);

ERL_NIF_TERM nif_vips_cache_set_max_files(ErlNifEnv *env, int argc,
                                          const ERL_NIF_TERM argv[]);

ERL_NIF_TERM nif_vips_cache_get_max_files(ErlNifEnv *env, int argc,
                                          const ERL_NIF_TERM argv[]);

ERL_NIF_TERM nif_vips_cache_set_max_mem(ErlNifEnv *env, int argc,
                                        const ERL_NIF_TERM argv[]);

ERL_NIF_TERM nif_vips_cache_get_max_mem(ErlNifEnv *env, int argc,
                                        const ERL_NIF_TERM argv[]);

ERL_NIF_TERM nif_vips_operation_init(ErlNifEnv *env);

#endif
