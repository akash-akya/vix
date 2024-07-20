#ifndef VIX_VIPS_IMAGE_H
#define VIX_VIPS_IMAGE_H

#include "erl_nif.h"

ERL_NIF_TERM nif_image_new_from_file(ErlNifEnv *env, int argc,
                                     const ERL_NIF_TERM argv[]);

ERL_NIF_TERM nif_image_new_from_image(ErlNifEnv *env, int argc,
                                      const ERL_NIF_TERM argv[]);

ERL_NIF_TERM nif_image_copy_memory(ErlNifEnv *env, int argc,
                                   const ERL_NIF_TERM argv[]);

ERL_NIF_TERM nif_image_write_to_file(ErlNifEnv *env, int argc,
                                     const ERL_NIF_TERM argv[]);

ERL_NIF_TERM nif_image_write_to_buffer(ErlNifEnv *env, int argc,
                                       const ERL_NIF_TERM argv[]);

ERL_NIF_TERM nif_image_new(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]);

ERL_NIF_TERM nif_image_new_temp_file(ErlNifEnv *env, int argc,
                                     const ERL_NIF_TERM argv[]);

ERL_NIF_TERM nif_image_new_matrix_from_array(ErlNifEnv *env, int argc,
                                             const ERL_NIF_TERM argv[]);

ERL_NIF_TERM nif_image_get_fields(ErlNifEnv *env, int argc,
                                  const ERL_NIF_TERM argv[]);

ERL_NIF_TERM nif_image_get_header(ErlNifEnv *env, int argc,
                                  const ERL_NIF_TERM argv[]);

ERL_NIF_TERM nif_image_get_as_string(ErlNifEnv *env, int argc,
                                     const ERL_NIF_TERM argv[]);

ERL_NIF_TERM nif_image_update_metadata(ErlNifEnv *env, int argc,
                                       const ERL_NIF_TERM argv[]);

ERL_NIF_TERM nif_image_set_metadata(ErlNifEnv *env, int argc,
                                    const ERL_NIF_TERM argv[]);

ERL_NIF_TERM nif_image_remove_metadata(ErlNifEnv *env, int argc,
                                       const ERL_NIF_TERM argv[]);

ERL_NIF_TERM nif_image_hasalpha(ErlNifEnv *env, int argc,
                                const ERL_NIF_TERM argv[]);

ERL_NIF_TERM nif_image_new_from_source(ErlNifEnv *env, int argc,
                                       const ERL_NIF_TERM argv[]);

ERL_NIF_TERM nif_image_to_target(ErlNifEnv *env, int argc,
                                 const ERL_NIF_TERM argv[]);

ERL_NIF_TERM nif_image_new_from_binary(ErlNifEnv *env, int argc,
                                       const ERL_NIF_TERM argv[]);

ERL_NIF_TERM nif_image_write_to_binary(ErlNifEnv *env, int argc,
                                       const ERL_NIF_TERM argv[]);

ERL_NIF_TERM nif_image_write_area_to_binary(ErlNifEnv *env, int argc,
                                            const ERL_NIF_TERM argv[]);
#endif
