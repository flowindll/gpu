#include <CL/cl.h>
#include <iostream>
#include <fstream>
#include <vector>
#include <iomanip>
#include <cstring>

#define MAX_SOURCE_SIZE (0x10000)

int main() {
    // ======================= 1. Inițializare ========================
    const char* message = "abc";
    const size_t input_len = strlen(message);

    if (input_len > 55) {
        std::cerr << "Mesajul trebuie sa aiba maxim 55 de caractere (paddingul se face automat).\n";
        return 1;
    }

    // ======================= 2. Citire fișier kernel =================
    std::ifstream file("kernels\\sha256.cl");
    if (!file.is_open()) {
        std::cerr << "Nu pot deschide fisierul sha256.cl\n";
        return 1;
    }

    std::string source((std::istreambuf_iterator<char>(file)),
                        std::istreambuf_iterator<char>());
    const char* source_str = source.c_str();
    size_t source_size = source.length();

    // ======================= 3. Inițializare OpenCL ===================
    cl_platform_id platform_id = nullptr;
    cl_device_id device_id = nullptr;
    cl_context context = nullptr;
    cl_command_queue command_queue = nullptr;
    cl_program program = nullptr;
    cl_kernel kernel = nullptr;
    cl_int ret;

    ret = clGetPlatformIDs(1, &platform_id, nullptr);
    ret = clGetDeviceIDs(platform_id, CL_DEVICE_TYPE_GPU, 1, &device_id, nullptr);
    context = clCreateContext(nullptr, 1, &device_id, nullptr, nullptr, &ret);
    command_queue = clCreateCommandQueue(context, device_id, 0, &ret);

    // ======================= 4. Buffere ===============================
    size_t total_input_size = 64; // bloc SHA256 = 64 bytes

    std::vector<unsigned char> input_block(64, 0);
    std::memcpy(input_block.data(), message, input_len); // Copiem mesajul

    cl_mem input_buf = clCreateBuffer(context, CL_MEM_READ_ONLY | CL_MEM_COPY_HOST_PTR,
                                      total_input_size, input_block.data(), &ret);

    cl_mem output_buf = clCreateBuffer(context, CL_MEM_WRITE_ONLY, 8 * sizeof(cl_uint), nullptr, &ret);

    // ======================= 5. Build kernel ==========================
    program = clCreateProgramWithSource(context, 1, &source_str, &source_size, &ret);
    ret = clBuildProgram(program, 1, &device_id, nullptr, nullptr, nullptr);

    if (ret != CL_SUCCESS) {
        size_t log_size;
        clGetProgramBuildInfo(program, device_id, CL_PROGRAM_BUILD_LOG, 0, nullptr, &log_size);
        std::vector<char> log(log_size);
        clGetProgramBuildInfo(program, device_id, CL_PROGRAM_BUILD_LOG, log_size, log.data(), nullptr);
        std::cerr << "Eroare la build:\n" << log.data() << "\n";
        return 1;
    }

    kernel = clCreateKernel(program, "sha256", &ret);

    // ======================= 6. Set kernel args =======================
    ret = clSetKernelArg(kernel, 0, sizeof(cl_mem), &input_buf);
    ret = clSetKernelArg(kernel, 1, sizeof(cl_mem), &output_buf);
    ret = clSetKernelArg(kernel, 2, sizeof(cl_uint), &input_len);

    // ======================= 7. Rulează kernel ========================
    size_t global_work_size = 1;
    ret = clEnqueueNDRangeKernel(command_queue, kernel, 1, nullptr,
                                 &global_work_size, nullptr, 0, nullptr, nullptr);

    // ======================= 8. Citește rezultatul ====================
    cl_uint hash[8] = {0};
    ret = clEnqueueReadBuffer(command_queue, output_buf, CL_TRUE, 0,
                              sizeof(hash), hash, 0, nullptr, nullptr);

    // ======================= 9. Afișează SHA256 =======================
    std::cout << "SHA256: ";
    for (int i = 0; i < 8; ++i)
        std::cout << std::hex << std::setw(8) << std::setfill('0') << hash[i];
    std::cout << "\n";

    // ======================= 10. Cleanup ==============================
    clReleaseMemObject(input_buf);
    clReleaseMemObject(output_buf);
    clReleaseKernel(kernel);
    clReleaseProgram(program);
    clReleaseCommandQueue(command_queue);
    clReleaseContext(context);

    return 0;
}