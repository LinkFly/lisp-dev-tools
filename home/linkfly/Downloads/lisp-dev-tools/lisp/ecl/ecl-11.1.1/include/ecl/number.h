/* -*- mode: c; c-basic-offset: 8 -*- */
/*
    number.h  -- GMP interface.
*/
/*
    Copyright (c) 1995, Giuseppe Attardi.

    ECoLisp is free software; you can redistribute it and/or
    modify it under the terms of the GNU Library General Public
    License as published by the Free Software Foundation; either
    version 2 of the License, or (at your option) any later version.

    See file '../Copyright' for full details.
*/

#ifndef ECL_NUMBER_H
#define ECL_NUMBER_H
#define ECL_BIG_REGISTER_SIZE	32

#define ECL_WITH_TEMP_BIGNUM(name,n)                                    \
        mp_limb_t name##data[n];                                        \
        volatile struct ecl_bignum name##aux;                           \
        const cl_object name = (name##aux.big_num->_mp_alloc = n,       \
                                name##aux.big_num->_mp_size = 0,        \
                                name##aux.big_num->_mp_d = name##data,  \
                                (cl_object)(&name##aux))

extern ECL_API cl_object _ecl_big_set_fixnum(cl_object x, cl_fixnum f);
extern ECL_API cl_object _ecl_big_set_index(cl_object x, cl_index f);
#ifdef ECL_LONG_FLOAT
extern ECL_API long double _ecl_big_to_long_double(cl_object x);
#endif
typedef void (*_ecl_big_binary_op)(cl_object out, cl_object o1, cl_object o2);
extern ECL_API _ecl_big_binary_op _ecl_big_boole_operator(int op);

#if ECL_LONG_BITS >= FIXNUM_BITS
#define _ecl_big_set_fixnum(x, f) mpz_set_si((x)->big.big_num,(f))
#define _ecl_big_set_index(x, f) mpz_set_ui((x)->big.big_num,(f))
#endif
#define _ecl_big_init2(x,size)	mpz_init2((x)->big.big_num,(size)*GMP_LIMB_BITS)
#define _ecl_big_clear(x)	mpz_clear((x)->big.big_num)
#define _ecl_big_set(x,y)	mpz_set((x)->big.big_num,(y)->big.big_num)
#define _ecl_big_odd_p(x)	((mpz_get_ui(x->big.big_num) & 1) != 0)
#define _ecl_big_even_p(x)	((mpz_get_ui(x->big.big_num) & 1) == 0)
#define _ecl_big_zerop(x)	((x)->big.big_size == 0)
#define _ecl_big_sign(x)	((x)->big.big_size)
#define _ecl_big_compare(x, y)	mpz_cmp(x->big.big_num, y->big.big_num)
#define _ecl_big_complement(z, x) mpz_neg((z)->big.big_num,(x)->big.big_num)
#define _ecl_big_add(z, x, y)	mpz_add((z)->big.big_num,(x)->big.big_num,(y)->big.big_num)
#define _ecl_big_sub(z, x, y)	mpz_sub((z)->big.big_num,(x)->big.big_num,(y)->big.big_num)
#define _ecl_big_mul(z, x, y)	mpz_mul((z)->big.big_num,(x)->big.big_num,(y)->big.big_num)
#define _ecl_big_add_ui(z, x, i)	mpz_add_ui(z->big.big_num, x->big.big_num, i)
#define _ecl_big_sub_ui(z, x, i)	mpz_sub_ui(z->big.big_num, x->big.big_num, i)
#define _ecl_big_mul_ui(z, x, y)	mpz_mul_ui((z)->big.big_num,(x)->big.big_num,(y))
#define _ecl_big_mul_si(z, x, y)	mpz_mul_si((z)->big.big_num,(x)->big.big_num,(y))
#define _ecl_big_set_ui(x, i)	mpz_set_ui(x->big.big_num, (unsigned long int)i)
#define _ecl_big_set_si(x, i)	mpz_set_si(x->big.big_num, (long int)i)
#define _ecl_big_to_double(x)	mpz_get_d(x->big.big_num)
#define _ecl_big_to_long(x)		mpz_get_si(x->big.big_num)
#define _ecl_big_to_ulong(x)		mpz_get_ui(x->big.big_num)
#define _ecl_big_cmp_si(x,y)		mpz_cmp_si((x)->big.big_num,(y))
#define _ecl_big_tdiv_q(q, x, y)	mpz_tdiv_q((q)->big.big_num,(x)->big.big_num,(y)->big.big_num)
#define _ecl_big_tdiv_q_ui(q, x, y)	mpz_tdiv_q_ui((q)->big.big_num, (x)->big.big_num, (y))
#define _ecl_big_set_d(x, d)		mpz_set_d((x)->big.big_num, (d))

#endif /* ECL_NUMBER_H */
