#include "opencl/include/CL/opencl.hpp"
#include <iostream>
#include <fstream>
#include <vector>
#include <iomanip>

#define HASH_SIZE 20  // RIPEMD-160 hash is 160 bits = 20 bytes

// Functie de padding conform RIPEMD-160
std::vector<unsigned char> ripemd160_pad(const std::string& message) {
    uint64_t bit_len = message.size() * 8;

    std::vector<unsigned char> padded(message.begin(), message.end());
    padded.push_back(0x80);  // Adaugăm bitul 1

    // Padding cu 0 până când lungimea % 64 == 56
    while ((padded.size() % 64) != 56)
        padded.push_back(0x00);

    // Adăugăm lungimea în biți (little endian)
    for (int i = 0; i < 8; ++i)
        padded.push_back((bit_len >> (8 * i)) & 0xFF);

    return padded;
}

// Funcție pentru a încărca kernelul din fișier
std::string load_kernel(const std::string& filename) {
    std::ifstream file(filename);
    if (!file.is_open())
        throw std::runtime_error("Nu pot deschide fișierul kernel.cl");

    return std::string(std::istreambuf_iterator<char>(file), {});
}

int main() {
    try {
        std::string message = "abc";
        auto input = ripemd160_pad(message);

        // Încarcă kernelul
        std::string source = load_kernel("test.cl");

        // Inițializare OpenCL
        std::vector<cl::Platform> platforms;
        cl::Platform::get(&platforms);

        if (platforms.empty())
            throw std::runtime_error("Nu există platforme OpenCL disponibile.");

        cl::Platform platform = platforms.front();
        std::vector<cl::Device> devices;
        platform.getDevices(CL_DEVICE_TYPE_GPU | CL_DEVICE_TYPE_CPU, &devices);

        if (devices.empty())
            throw std::runtime_error("Nu există dispozitive OpenCL disponibile.");

        cl::Device device = devices.front();
        cl::Context context({ device });
        cl::Program program(context, source);
        program.build({ device });

        cl::CommandQueue queue(context, device);

        // Creează buffer pentru input și output
        cl::Buffer inputBuffer(context, CL_MEM_READ_ONLY | CL_MEM_COPY_HOST_PTR, input.size(), input.data());
        cl::Buffer outputBuffer(context, CL_MEM_WRITE_ONLY, HASH_SIZE);

        // Creează kernelul
        cl::Kernel kernel(program, "ripemd160");
        kernel.setArg(0, inputBuffer);
        kernel.setArg(1, outputBuffer);

        // Rulează kernelul
        queue.enqueueNDRangeKernel(kernel, cl::NullRange, cl::NDRange(1), cl::NullRange);
        queue.finish();

        // Extrage hash-ul
        std::vector<unsigned char> hash(HASH_SIZE);
        queue.enqueueReadBuffer(outputBuffer, CL_TRUE, 0, HASH_SIZE, hash.data());

        // Afișează hash-ul
        std::cout << "Hash RIPEMD-160: ";
        for (auto byte : hash)
            std::cout << std::hex << std::setw(2) << std::setfill('0') << (int)byte;
        std::cout << std::dec << std::endl;

    } catch (const std::exception& e) {
        std::cerr << "Eroare: " << e.what() << std::endl;
        return 1;
    }

    return 0;
}
