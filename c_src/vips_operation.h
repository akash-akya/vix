#ifndef VIX_VIPS_OPERATION_H
#define VIX_VIPS_OPERATION_H

#include "erl_nif.h"

ERL_NIF_TERM nif_vips_operation_call(ErlNifEnv *env, int argc,
                                     const ERL_NIF_TERM argv[]);

ERL_NIF_TERM nif_vips_operation_get_arguments(ErlNifEnv *env, int argc,
                                              const ERL_NIF_TERM argv[]);

ERL_NIF_TERM nif_vips_operation_list(ErlNifEnv *env, int argc,
                                     const ERL_NIF_TERM argv[]);

ERL_NIF_TERM nif_vips_enum_list(ErlNifEnv *env, int argc,
                                const ERL_NIF_TERM argv[]);

ERL_NIF_TERM nif_vips_flag_list(ErlNifEnv *env, int argc,
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

ERL_NIF_TERM nif_vips_leak_set(ErlNifEnv *env, int argc,
                               const ERL_NIF_TERM argv[]);

ERL_NIF_TERM nif_vips_tracked_get_mem(ErlNifEnv *env, int argc,
                                      const ERL_NIF_TERM argv[]);

ERL_NIF_TERM nif_vips_tracked_get_mem_highwater(ErlNifEnv *env, int argc,
                                                const ERL_NIF_TERM argv[]);

ERL_NIF_TERM nif_vips_shutdown(ErlNifEnv *env, int argc,
                               const ERL_NIF_TERM argv[]);

ERL_NIF_TERM nif_vips_version(ErlNifEnv *env, int argc,
                              const ERL_NIF_TERM argv[]);

ERL_NIF_TERM nif_vips_nickname_find(ErlNifEnv *env, int argc,
                                    const ERL_NIF_TERM argv[]);

int nif_vips_operation_init(ErlNifEnv *env);

#endif
