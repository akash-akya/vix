#ifndef VIX_VIPS_IMAGE_H
#define VIX_VIPS_IMAGE_H

#include "erl_nif.h"

ERL_NIF_TERM nif_image_new_from_file(ErlNifEnv *env, int argc,
                                     const ERL_NIF_TERM argv[]);

ERL_NIF_TERM nif_image_new_from_source(ErlNifEnv *env, int argc,
                                       const ERL_NIF_TERM argv[]);

ERL_NIF_TERM nif_image_write_to_file(ErlNifEnv *env, int argc,
                                     const ERL_NIF_TERM argv[]);

ERL_NIF_TERM nif_image_new(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]);

ERL_NIF_TERM nif_image_new_temp_file(ErlNifEnv *env, int argc,
                                     const ERL_NIF_TERM argv[]);

ERL_NIF_TERM nif_image_new_matrix_from_array(ErlNifEnv *env, int argc,
                                             const ERL_NIF_TERM argv[]);

#endif
