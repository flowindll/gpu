__constant uint K[64] = {
  0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,
  0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,
  0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,
  0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,
  0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,
  0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,
  0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,
  0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2
};

uint rotr(uint x, uint n) {
  return (x >> n) | (x << (32 - n));
}

uint ch(uint x, uint y, uint z) {
  return (x & y) ^ (~x & z);
}

uint maj(uint x, uint y, uint z) {
  return (x & y) ^ (x & z) ^ (y & z);
}

uint sig0(uint x) {
  return rotr(x, 7) ^ rotr(x, 18) ^ (x >> 3);
}

uint sig1(uint x) {
  return rotr(x, 17) ^ rotr(x, 19) ^ (x >> 10);
}

uint ep0(uint x) {
  return rotr(x, 2) ^ rotr(x, 13) ^ rotr(x, 22);
}

uint ep1(uint x) {
  return rotr(x, 6) ^ rotr(x, 11) ^ rotr(x, 25);
}

__kernel void sha256(__global const uchar* input,
                            __global uint* output,
                            const uint input_len) {

  uchar block[64] = {0};
  for (int i = 0; i < input_len; i++) {
    block[i] = input[i];
  }
  block[input_len] = 0x80;

  ulong bit_len = (ulong)input_len * 8;
  block[63] = (uchar)(bit_len & 0xFF);
  block[62] = (uchar)((bit_len >> 8) & 0xFF);
  block[61] = (uchar)((bit_len >> 16) & 0xFF);
  block[60] = (uchar)((bit_len >> 24) & 0xFF);
  block[59] = (uchar)((bit_len >> 32) & 0xFF);
  block[58] = (uchar)((bit_len >> 40) & 0xFF);
  block[57] = (uchar)((bit_len >> 48) & 0xFF);
  block[56] = (uchar)((bit_len >> 56) & 0xFF);

  uint w[64];
  for (int i = 0; i < 16; i++) {
    w[i] = (block[i*4] << 24) | (block[i*4+1] << 16) |
           (block[i*4+2] << 8) | (block[i*4+3]);
  }

  for (int i = 16; i < 64; i++) {
    w[i] = sig1(w[i-2]) + w[i-7] + sig0(w[i-15]) + w[i-16];
  }

  uint a = 0x6a09e667;
  uint b = 0xbb67ae85;
  uint c = 0x3c6ef372;
  uint d = 0xa54ff53a;
  uint e = 0x510e527f;
  uint f = 0x9b05688c;
  uint g = 0x1f83d9ab;
  uint h = 0x5be0cd19;


  for (int i = 0; i < 64; i++) {
    uint t1 = h + ep1(e) + ch(e,f,g) + K[i] + w[i];
    uint t2 = ep0(a) + maj(a,b,c);
    h = g;
    g = f;
    f = e;
    e = d + t1;
    d = c;
    c = b;
    b = a;
    a = t1 + t2;
  }

  output[0] = a + 0x6a09e667;
  output[1] = b + 0xbb67ae85;
  output[2] = c + 0x3c6ef372;
  output[3] = d + 0xa54ff53a;
  output[4] = e + 0x510e527f;
  output[5] = f + 0x9b05688c;
  output[6] = g + 0x1f83d9ab;
  output[7] = h + 0x5be0cd19;
}
