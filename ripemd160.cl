__constant uint K[5] = { 0x00000000, 0x5A827999, 0x6ED9EBA1, 0x8F1BBCDC, 0xA953FD4E };
__constant uint KK[5] = { 0x50A28BE6, 0x5C4DD124, 0x6D703EF3, 0x7A6D76E9, 0x00000000 };

__constant uchar R[80] = {
    0,  1,  2,  3,  4,  5,  6,  7,
    8,  9, 10, 11, 12, 13, 14, 15,
    7,  4, 13, 1, 10, 6, 15, 3,
    12, 0, 9, 5, 2, 14, 11, 8,
    3, 10, 14, 4, 9, 15, 8, 1,
    2, 7, 0, 6, 13, 11, 5, 12,
    1, 9, 11, 10, 0, 8, 12, 4,
    13, 3, 7, 15, 14, 5, 6, 2,
    4, 0, 5, 9, 7, 12, 2, 10,
    14, 1, 3, 8, 11, 6, 15, 13
};

__constant uchar S[80] = {
    11, 14, 15, 12, 5, 8, 7, 9,
    11, 13, 14, 15, 6, 7, 9, 8,
    7, 6, 8, 13, 11, 9, 7, 15,
    7, 12, 15, 9, 11, 7, 13, 12,
    11, 13, 6, 7, 14, 9, 13, 15,
    14, 8, 13, 6, 5, 12, 7, 5,
    11, 12, 14, 15, 14, 15, 9, 8,
    9, 14, 5, 6, 8, 6, 5, 12,
    9, 15, 5, 11, 6, 8, 13, 12,
    5, 12, 13, 14, 11, 8, 5, 6
};

// Funcția de rotire
uint rol(uint x, uchar s) {
    return (x << s) | (x >> (32 - s));
}

// Funcția f(j) specifică pentru RIPEMD-160
uint f(uint j, uint x, uint y, uint z) {
    if (j <= 15) return x ^ y ^ z;
    else if (j <= 31) return (x & y) | (~x & z);
    else if (j <= 47) return (x | ~y) ^ z;
    else if (j <= 63) return (x & z) | (y & ~z);
    else return x ^ (y | ~z);
}

// Kernelul care implementează RIPEMD-160
__kernel void ripemd160_kernel(
    __global const uchar *passwords,  // Parola cu maxim 11 bytes
    __global const uchar *lengths,    // Lungimea fiecărei parole
    __global uint *output_hashes      // Rezultatul, 5 uints pe thread
) {
    size_t id = get_global_id(0);
    uchar msg[64] = {0}; // Un bloc complet de 512 biți

    // Copiem parola + padding
    uchar len = lengths[id];
    for (int i = 0; i < len; i++)
        msg[i] = passwords[id * 11 + i];

    // Padding conform RIPEMD-160: adăugăm 0x80, apoi 0 până la 56 bytes, apoi lungimea în biți
    msg[len] = 0x80;
    uint bit_len = len * 8;
    msg[56] = (uchar)(bit_len & 0xFF);
    msg[57] = (uchar)((bit_len >> 8) & 0xFF);
    msg[58] = (uchar)((bit_len >> 16) & 0xFF);
    msg[59] = (uchar)((bit_len >> 24) & 0xFF);

    // Transformăm mesajul în blocuri de uint (pentru un singur bloc, 64 bytes)
    uint X[16];
    for (int i = 0; i < 16; i++) {
        X[i] = ((uint)msg[i * 4]) |
               ((uint)msg[i * 4 + 1] << 8) |
               ((uint)msg[i * 4 + 2] << 16) |
               ((uint)msg[i * 4 + 3] << 24);
    }

    // Inițializarea valorilor de stare
    uint h0 = 0x67452301;
    uint h1 = 0xEFCDAB89;
    uint h2 = 0x98BADCFE;
    uint h3 = 0x10325476;
    uint h4 = 0xC3D2E1F0;

    uint A1 = h0, B1 = h1, C1 = h2, D1 = h3, E1 = h4;
    uint A2 = h0, B2 = h1, C2 = h2, D2 = h3, E2 = h4;

    // Funcția de procesare pentru fiecare pas
    for (uint j = 0; j < 80; j++) {
        // Faza 1 (procesul pentru A1, B1, C1, D1, E1)
        uint T = rol(A1 + f(j, B1, C1, D1) + X[R[j]] + K[j / 16], S[j]) + E1;
        A1 = E1; E1 = D1; D1 = rol(C1, 10); C1 = B1; B1 = T;

        // Faza 2 (procesul pentru A2, B2, C2, D2, E2)
        T = rol(A2 + f(79 - j, B2, C2, D2) + X[R[j]] + KK[j / 16], S[j]) + E2;
        A2 = E2; E2 = D2; D2 = rol(C2, 10); C2 = B2; B2 = T;
    }

    // Calculul final al valorilor hash
    uint T = h1 + C1 + D2;
    h1 = h2 + D1 + E2;
    h2 = h3 + E1 + A2;
    h3 = h4 + A1 + B2;
    h4 = h0 + B1 + C2;
    h0 = T;

    // Salvăm hash-ul rezultat (5 * uint = 20 bytes)
    output_hashes[id * 5 + 0] = h0;
    output_hashes[id * 5 + 1] = h1;
    output_hashes[id * 5 + 2] = h2;
    output_hashes[id * 5 + 3] = h3;
    output_hashes[id * 5 + 4] = h4;
}
