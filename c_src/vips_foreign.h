#ifndef VIX_VIPS_FOREIGN_H
#define VIX_VIPS_FOREIGN_H

#include "erl_nif.h"

ERL_NIF_TERM nif_foreign_find_load_buffer(ErlNifEnv *env, int argc,
                                          const ERL_NIF_TERM argv[]);

ERL_NIF_TERM nif_foreign_find_save_buffer(ErlNifEnv *env, int argc,
                                          const ERL_NIF_TERM argv[]);

ERL_NIF_TERM nif_foreign_find_load(ErlNifEnv *env, int argc,
                                   const ERL_NIF_TERM argv[]);

ERL_NIF_TERM nif_foreign_find_save(ErlNifEnv *env, int argc,
                                   const ERL_NIF_TERM argv[]);

ERL_NIF_TERM nif_foreign_find_load_source(ErlNifEnv *env, int argc,
                                          const ERL_NIF_TERM argv[]);

ERL_NIF_TERM nif_foreign_find_save_target(ErlNifEnv *env, int argc,
                                          const ERL_NIF_TERM argv[]);

ERL_NIF_TERM nif_foreign_get_suffixes(ErlNifEnv *env, int argc,
                                      const ERL_NIF_TERM argv[]);

ERL_NIF_TERM nif_foreign_get_loader_suffixes(ErlNifEnv *env, int argc,
                                             const ERL_NIF_TERM argv[]);

#endif
