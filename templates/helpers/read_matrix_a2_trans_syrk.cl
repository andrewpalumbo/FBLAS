/**
    FBLAS: BLAS implementation for Intel FPGA
    Copyright (c) 2020 ETH-Zurich. All rights reserved.
    See LICENSE for license information.

    Reads a matrix of type  {{ helper.type_str }} from memory and  push it
    into {{ channels["channel_out_matrix"] }} The matrix is read considering the presence of a
    two level tiling (memory/computational) like the one present in SYRK implementation.

    In this kernel we read the right-most matrix of the computation
    Matrix A is sent by row
    Each tile-col ti of A is sent a  different number of time, depending on the
    type of SYRK computation:
    - if C is lower triangular, it will be sent ti times
    - if C is upper triangular, it will be sent NumTiles-ti times


    8 reads are performed simultaneously (this value has been choosen as a trade off between
    generated hardware and speed. In the future can be considered as a parameter).
    If needed, data is padded to tile sizes using zero elements.

*/
{% if generate_channel_declaration is defined %}
#pragma OPENCL EXTENSION cl_intel_channels : enable

channel {{ helper.type_str }} {{ channels["channel_out_matrix"] }} __attribute__((depth({{ helper.width }})));
{% endif %}

__kernel void {{ helper_name }}(__global volatile  {{ helper.type_str }} * restrict A, const unsigned int N, const unsigned int K, const unsigned int lda,const unsigned int lower)
{
    __constant ushort MTILE = {{ helper.tile_size}};
    __constant uchar CTILE_ROWS = {{ helper.width_y}};
    __constant uchar CTILE_COLS = {{ helper.width_x}};
    
    //double level of tiling
    const int OuterBlocksN = 1 + (int)((N-1) / MTILE);
    const int InnerBlocksNR = MTILE / CTILE_ROWS;
    const int InnerBlocksNC = MTILE / CTILE_COLS;
    if(lower!=0 && lower !=1) return;

    const int BlocksK=(int)(K/MTILE);
    int tj_start,tj_end;
     {{ helper.type_str }} localA[MTILE];

    for(int ti=0;ti<OuterBlocksN;ti++)
    {

        if(lower==1){
            tj_start=0;
            tj_end=ti;
        }
        else{
            tj_start=ti;
            tj_end=OuterBlocksN-1;
        }

        for(int tj=tj_start;tj<=tj_end;tj++)
        {
            for(int k=0;k<K;k++)
            {
                #pragma unroll 8
                for(int i=0;i<MTILE;i++)
                {
                    if(tj*MTILE+i < N)
                        localA[i]=A[(tj*MTILE+i)*lda+k];
                    else
                        localA[i]=0;
                }
                for(int i=0;i<InnerBlocksNR;i++)
                {
                    //iterates over the inner tiles of A
                    for(int ttj=0;ttj<InnerBlocksNC;ttj++)
                    {
                        #pragma unroll
                        for(int j=0;j<CTILE_COLS;j++)
                        {
                            write_channel_intel({{ channels["channel_out_matrix"] }},localA[ttj*CTILE_COLS+j]);
                        }
                    }
                }
            }
        }
    }
}

