#define __CL_ENABLE_EXCEPTIONS
#include <CL/opencl.hpp>
#include <iostream>
#include <vector>
#include <string>
#include <fstream>
#include <sstream>
#include <iomanip>
#include <cstdint>

// Aplică padding la un bloc de date
std::vector<unsigned char> apply_padding(const std::vector<unsigned char>& input_data) {
    size_t original_size = input_data.size();
    uint64_t bit_size = static_cast<uint64_t>(original_size) * 8;

    size_t mod = (original_size + 1 + 8) % 64;
    size_t padding_size = (mod > 0) ? (64 - mod) : 0;

    std::vector<unsigned char> padded_data;
    padded_data.reserve(original_size + 1 + padding_size + 8);

    padded_data.insert(padded_data.end(), input_data.begin(), input_data.end());
    padded_data.push_back(0x80);
    padded_data.insert(padded_data.end(), padding_size, 0x00);

    for (int i = 0; i < 8; ++i) {
        padded_data.push_back(static_cast<unsigned char>((bit_size >> (8 * i)) & 0xFF));
    }

    return padded_data;
}

// Încarcă codul sursă al kernel-ului OpenCL
std::string load_kernel_code(const std::string& filename) {
    std::ifstream file(filename);
    if (!file.is_open()) {
        std::cerr << "Failed to open kernel file: " << filename << std::endl;
        exit(1);
    }

    std::stringstream buffer;
    buffer << file.rdbuf();
    return buffer.str();
}

void execute_opencl_kernel(const std::vector<unsigned char>& input_data,
                           const std::vector<cl_uint>& lengths,
                           size_t num_passwords) {
    try {
        std::vector<cl::Platform> platforms;
        cl::Platform::get(&platforms);
        cl::Platform platform = platforms.front();

        std::vector<cl::Device> devices;
        platform.getDevices(CL_DEVICE_TYPE_GPU, &devices);
        cl::Device device = devices.front();

        std::cout << "Using device: " << device.getInfo<CL_DEVICE_NAME>() << std::endl;

        cl::Context context(device);
        cl::CommandQueue queue(context, device);

        std::string kernel_code = load_kernel_code("ripemd160.cl");
        const char* src = kernel_code.c_str();
        cl::Program::Sources sources;
        sources.push_back({src, strlen(src)});

        cl::Program program(context, sources);
        try {
            program.build({ device });
        } catch (const cl::Error& e) {
            std::cerr << "Error building program: " << e.what() << " (" << e.err() << ")" << std::endl;
            std::cerr << program.getBuildInfo<CL_PROGRAM_BUILD_LOG>(device) << std::endl;
            exit(1);
        }

        cl::Buffer input_buffer(context, CL_MEM_READ_ONLY | CL_MEM_COPY_HOST_PTR, input_data.size(), (void*)input_data.data());
        cl::Buffer lengths_buffer(context, CL_MEM_READ_ONLY | CL_MEM_COPY_HOST_PTR, lengths.size() * sizeof(cl_uint), (void*)lengths.data());
        cl::Buffer output_buffer(context, CL_MEM_WRITE_ONLY, num_passwords * 5 * sizeof(cl_uint));

        cl::Kernel kernel(program, "ripemd160_kernel");
        kernel.setArg(0, input_buffer);
        kernel.setArg(1, lengths_buffer);
        kernel.setArg(2, output_buffer);

        size_t local_work_size = 64;
        size_t global_work_size = ((num_passwords + local_work_size - 1) / local_work_size) * local_work_size;

        queue.enqueueNDRangeKernel(kernel, cl::NullRange, cl::NDRange(global_work_size), cl::NDRange(local_work_size));
        queue.finish();

        std::vector<cl_uint> result(num_passwords * 5);
        queue.enqueueReadBuffer(output_buffer, CL_TRUE, 0, result.size() * sizeof(cl_uint), result.data());

        for (size_t i = 0; i < num_passwords; ++i) {
            std::cout << "Hash for password " << i << ": ";
            for (int j = 0; j < 5; ++j) {
                cl_uint val = result[i * 5 + j];
                for (int k = 0; k < 4; ++k) {
                    std::cout << std::hex << std::setw(2) << std::setfill('0') << ((val >> (8 * k)) & 0xFF);
                }
            }
            std::cout << std::endl;
        }

    } catch (const cl::Error& e) {
        std::cerr << "OpenCL error: " << e.what() << " (" << e.err() << ")" << std::endl;
    }
}

int main() {
    std::vector<std::string> passwords = {
        "password123",
        "admin",
        "123456",
        "qwerty",
        "letmein"
    };

    std::vector<unsigned char> concatenated_input(passwords.size() * 11, 0); // 11 bytes per parola
    std::vector<cl_uint> lengths;

    for (size_t i = 0; i < passwords.size(); ++i) {
        const auto& pw = passwords[i];
        lengths.push_back(static_cast<cl_uint>(pw.size()));

        for (size_t j = 0; j < pw.size() && j < 11; ++j) {
            concatenated_input[i * 11 + j] = static_cast<unsigned char>(pw[j]);
        }
        // Restul celor 11 bytes rămân zero (padding implicit)
    }

    execute_opencl_kernel(concatenated_input, lengths, passwords.size());
    return 0;
}
