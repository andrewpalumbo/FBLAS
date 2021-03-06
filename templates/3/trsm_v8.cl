/**
    FBLAS: BLAS implementation for Intel FPGA
    Copyright (c) 2020 ETH-Zurich. All rights reserved.
    See LICENSE for license information.

    TRSM v8
    TRSM  solves one of the matrix equations

        op( A )*X = alpha*B,   or   X*op( A ) = alpha*B,

     where alpha is a scalar, X and B are m by n matrices, A is a unit, or
     non-unit,  upper or lower triangular matrix  and  op( A )  is one  of

        op( A ) = A   or   op( A ) = A**T.

     The matrix X is overwritten on B.

     This version solves the case: side right, A upper,  transposed.
     No distinction is made between unit/non unit cases

*/
{% if routine.type_str == 'double' %}
#pragma OPENCL EXTENSION cl_khr_fp64 : enable
{% endif %}

__kernel void {{ routine.user_name }}(const int N, const int M, const {{ routine.type_str }} alpha, __global const {{ routine.type_str }} * restrict A,
                          const unsigned int lda, __global {{ routine.type_str }} * restrict B, const unsigned int ldb )
{
    __constant uint WIDTH = {{ routine.width }};
    __constant uint TILE_M = {{ routine.tile_m_size }};
    const int BlocksM=1+(int)((M-1)/TILE_M);
    //NOTE: this is a base implementation
    
    for(int i=0;i<N;i++)
    {
        for(int j=M-1; j>= 0; j--)
        {
            const {{ routine.type_str }} Ajj=A[j*lda+j];
            const {{ routine.type_str }} prev=(j==M-1)?alpha*B[i*ldb+j]:B[i*ldb+j];
            const {{ routine.type_str }} Bij = prev/Ajj;
            B[i*ldb+j]=Bij;

            const int computing_outer_loop_limit=1+(int)((j-1)/(int)WIDTH);

            for(int tk=0;tk < computing_outer_loop_limit; tk++)
            {
                #pragma unroll
                for(int k=0; k < WIDTH ;k++)
                {
                    if(tk*WIDTH+k<j)
                    {
                        const {{ routine.type_str }} prev=(j==M-1)?alpha*B[i*ldb+tk*WIDTH+k]:B[i*ldb+tk*WIDTH+k];
                        B[i*ldb+tk*WIDTH+k]=prev-A[(tk*WIDTH+k)*lda+j]*Bij;
                    }
                }
            }
        }
    }
}
