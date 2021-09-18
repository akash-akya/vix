#ifndef VIX_VIPS_BOXED_H
#define VIX_VIPS_BOXED_H

#include "erl_nif.h"

ERL_NIF_TERM nif_int_array(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]);

ERL_NIF_TERM nif_double_array(ErlNifEnv *env, int argc,
                              const ERL_NIF_TERM argv[]);

ERL_NIF_TERM nif_image_array(ErlNifEnv *env, int argc,
                             const ERL_NIF_TERM argv[]);

ERL_NIF_TERM nif_vips_blob(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]);

ERL_NIF_TERM nif_vips_ref_string(ErlNifEnv *env, int argc,
                                 const ERL_NIF_TERM argv[]);

ERL_NIF_TERM nif_vips_int_array_to_erl_list(ErlNifEnv *env, int argc,
                                            const ERL_NIF_TERM argv[]);

ERL_NIF_TERM nif_vips_double_array_to_erl_list(ErlNifEnv *env, int argc,
                                               const ERL_NIF_TERM argv[]);

ERL_NIF_TERM nif_vips_image_array_to_erl_list(ErlNifEnv *env, int argc,
                                              const ERL_NIF_TERM argv[]);

ERL_NIF_TERM nif_vips_blob_to_erl_binary(ErlNifEnv *env, int argc,
                                         const ERL_NIF_TERM argv[]);

ERL_NIF_TERM nif_vips_ref_string_to_erl_binary(ErlNifEnv *env, int argc,
                                               const ERL_NIF_TERM argv[]);

#endif
