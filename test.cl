__constant uint K[5] = {0x00000000, 0x5A827999, 0x6ED9EBA1, 0x8F1BBCDC, 0xA953FD4E};
__constant uint KK[5] = {0x50A28BE6, 0x5C4DD124, 0x6D703EF3, 0x7A6D76E9, 0x00000000};

__constant uchar R[80] = 
{
    0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15,
    7, 4, 13, 1, 10, 6, 15, 3, 12, 0, 9, 5, 2, 14, 11, 8,
    3, 10, 14, 4, 9, 15, 8, 1, 2, 7, 0, 6, 13, 11, 5, 12,
    1, 9, 11, 10, 0, 8, 12, 4, 13, 3, 7, 15, 14, 5, 6, 2,
    4, 0, 5, 9, 7, 12, 2, 10, 14, 1, 3, 8, 11, 6, 15, 13,
};

__constant uchar RR[80] =
{
    5, 14, 7, 0, 9, 2, 11, 4, 13, 6, 15, 8, 1, 10, 3, 12,
    6, 11, 3, 7, 0, 13, 5, 10, 14, 15, 8, 12, 4, 9, 1, 2,
    15, 5, 1, 3, 7, 14, 6, 9, 11, 8, 12, 2, 10, 0, 4, 13,
    8, 6, 4, 1, 3, 11, 15, 0, 5, 12, 2, 13, 9, 7, 10, 14,
    12, 15, 10, 4, 1, 5, 8, 7, 6, 2, 13, 14, 0, 3, 9, 11,
};

__constant uchar S[80] =
{
    11, 14, 15, 12, 5, 8, 7, 9, 11, 13, 14, 15, 6, 7, 9, 8,
    7, 6, 8, 13, 11, 9, 7, 15, 7, 12, 15, 9, 11, 7, 13, 12,
    11, 13, 6, 7, 14, 9, 13, 15, 14, 8, 13, 6, 5, 12, 7, 5,
    11, 12, 14, 15, 14, 15, 9, 8, 9, 14, 5, 6, 8, 6, 5, 12,
    9, 15, 5, 11, 6, 8, 13, 12, 5, 12, 13, 14, 11, 8, 5, 6,
};

__constant uchar SS[80] =
{
    8, 9, 9, 11, 13, 15, 15, 5, 7, 7, 8, 11, 14, 14, 12, 6,
    9, 13, 15, 7, 12, 8, 9, 11, 7, 7, 12, 7, 6, 15, 13, 11,
    9, 7, 15, 11, 8, 6, 6, 14, 12, 13, 5, 14, 13, 13, 7, 5,
    15, 5, 8, 11, 14, 14, 6, 14, 6,9, 12, 9, 12, 5, 15, 8,
    8, 5, 12, 9, 12, 5, 14, 6, 8, 13, 6, 5, 15, 13, 11, 11,
};


uint algo(uint j, uint x, uint y, uint z)
{
    if (j <= 15) return x ^ y ^ z;
    if (j <= 31) return (x & y) | (~x & z);
    if (j <= 47) return (x | ~y) ^ z;
    if (j <= 63) return (x & z) | (y & ~z);

    return x ^ (y | ~z);
}

uint ROL(uint x, uchar y)
{
    return (x << y) | (x >> (32 - y));
}

__kernel void ripemd160(__global const uchar* input, __global uchar* output)
{
    uint h0 = 0x67452301;
    uint h1 = 0xEFCDAB89;
    uint h2 = 0x98BADCFE;
    uint h3 = 0x10325476;
    uint h4 = 0xC3D2E1F0;

    uint X[16];
    for (int i = 0; i < 16; i++) {
    X[i] = ((uint)input[i * 4]) |
            ((uint)input[i * 4 + 1] << 8) |
            ((uint)input[i * 4 + 2] << 16) |
            ((uint)input[i * 4 + 3] << 24);
    }

    uint A1 = h0, B1 = h1, C1 = h2, D1 = h3, E1 = h4;
    uint A2 = h0, B2 = h1, C2 = h2, D2 = h3, E2 = h4;


    for (uint j = 0; j < 80; j++) {
        uint T1 = ROL(A1 + algo(j, B1, C1, D1) + X[R[j]] + K[j / 16], S[j]) + E1;
        A1 = E1; E1 = D1; D1 = ROL(C1, 10); C1 = B1; B1 = T1;

        uint T2 = ROL(A2 + algo(79 - j, B2, C2, D2) + X[RR[j]] + KK[j / 16], SS[j]) + E2;
        A2 = E2; E2 = D2; D2 = ROL(C2, 10); C2 = B2; B2 = T2;
    }

    uint T = h1 + C1 + D2;
    h1 = h2 + D1 + E2;
    h2 = h3 + E1 + A2;
    h3 = h4 + A1 + B2;
    h4 = h0 + B1 + C2;
    h0 = T;

    output[0] = h0 & 0xff; output[1] = (h0 >> 8) & 0xff; output[2] = (h0 >> 16) & 0xff; output[3] = (h0 >> 24) & 0xff;
    output[4] = h1 & 0xff; output[5] = (h1 >> 8) & 0xff; output[6] = (h1 >> 16) & 0xff; output[7] = (h1 >> 24) & 0xff;
    output[8] = h2 & 0xff; output[9] = (h2 >> 8) & 0xff; output[10] = (h2 >> 16) & 0xff; output[11] = (h2 >> 24) & 0xff;
    output[12] = h3 & 0xff; output[13] = (h3 >> 8) & 0xff; output[14] = (h3 >> 16) & 0xff; output[15] = (h3 >> 24) & 0xff;
    output[16] = h4 & 0xff; output[17] = (h4 >> 8) & 0xff; output[18] = (h4 >> 16) & 0xff; output[19] = (h4 >> 24) & 0xff;
        



}