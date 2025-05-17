__kernel void hash160(__global const uchar* input, __global uchar* output, uint length) {
    uint sha_out[8]; // 8 * 4 = 32 bytes

    // 1. Hash cu SHA256
    sha256(input, sha_out, length);

    // 2. Conversie uint[8] -> uchar[32]
    uchar sha_bytes[32];
    for (int i = 0; i < 8; i++) {
        sha_bytes[i * 4 + 0] = (uchar)((sha_out[i] >> 24) & 0xFF);
        sha_bytes[i * 4 + 1] = (uchar)((sha_out[i] >> 16) & 0xFF);
        sha_bytes[i * 4 + 2] = (uchar)((sha_out[i] >> 8) & 0xFF);
        sha_bytes[i * 4 + 3] = (uchar)(sha_out[i] & 0xFF);
    }

    // 3. Hash cu RIPEMD160
    ripemd160(sha_bytes, output, 32);
}