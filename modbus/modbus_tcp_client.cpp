#include <arpa/inet.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <unistd.h>

#include <cstdint>
#include <cstring>
#include <iostream>
#include <vector>

namespace {
constexpr uint16_t kModbusPort = 502;
constexpr size_t kMbapHeaderSize = 7;

uint16_t read_u16(const uint8_t *data) {
  return static_cast<uint16_t>(data[0] << 8 | data[1]);
}

void write_u16(uint8_t *data, uint16_t value) {
  data[0] = static_cast<uint8_t>((value >> 8) & 0xFF);
  data[1] = static_cast<uint8_t>(value & 0xFF);
}

std::vector<uint8_t> build_request(uint16_t transaction_id,
                                   uint8_t unit_id,
                                   uint8_t function_code,
                                   uint16_t start_address,
                                   uint16_t quantity) {
  std::vector<uint8_t> request(kMbapHeaderSize + 5);
  write_u16(request.data(), transaction_id);
  write_u16(request.data() + 2, 0);
  write_u16(request.data() + 4, 6);
  request[6] = unit_id;
  request[7] = function_code;
  write_u16(request.data() + 8, start_address);
  write_u16(request.data() + 10, quantity);
  return request;
}

void parse_response(const std::vector<uint8_t> &response) {
  if (response.size() < kMbapHeaderSize + 2) {
    std::cerr << "Response too short\n";
    return;
  }

  uint16_t transaction_id = read_u16(response.data());
  uint16_t protocol_id = read_u16(response.data() + 2);
  uint16_t length = read_u16(response.data() + 4);
  uint8_t unit_id = response[6];
  uint8_t function_code = response[7];

  if (protocol_id != 0 || response.size() < kMbapHeaderSize + length) {
    std::cerr << "Invalid response header\n";
    return;
  }

  if (function_code & 0x80) {
    std::cerr << "Exception response: 0x" << std::hex
              << static_cast<int>(response[8]) << std::dec << "\n";
    return;
  }

  std::cout << "Transaction: " << transaction_id << ", Unit: "
            << static_cast<int>(unit_id) << ", Function: 0x" << std::hex
            << static_cast<int>(function_code) << std::dec << "\n";

  uint8_t byte_count = response[8];
  if (response.size() < kMbapHeaderSize + 2 + byte_count) {
    std::cerr << "Incomplete response data\n";
    return;
  }

  if (function_code == 0x01) {
    std::cout << "Coils: ";
    for (uint8_t i = 0; i < byte_count; ++i) {
      std::cout << "0x" << std::hex << static_cast<int>(response[9 + i])
                << " ";
    }
    std::cout << std::dec << "\n";
  } else if (function_code == 0x03) {
    std::cout << "Holding registers: ";
    for (uint8_t i = 0; i < byte_count / 2; ++i) {
      uint16_t value = read_u16(response.data() + 9 + i * 2);
      std::cout << value << " ";
    }
    std::cout << "\n";
  }
}
}  // namespace

int main(int argc, char **argv) {
  if (argc < 6) {
    std::cerr << "Usage: " << argv[0]
              << " <server_ip> <unit_id> <function_code> <start> <quantity>\n";
    return 1;
  }

  const char *server_ip = argv[1];
  uint8_t unit_id = static_cast<uint8_t>(std::stoi(argv[2]));
  uint8_t function_code = static_cast<uint8_t>(std::stoi(argv[3], nullptr, 0));
  uint16_t start_address = static_cast<uint16_t>(std::stoi(argv[4]));
  uint16_t quantity = static_cast<uint16_t>(std::stoi(argv[5]));

  int sock = socket(AF_INET, SOCK_STREAM, 0);
  if (sock < 0) {
    std::cerr << "Failed to create socket\n";
    return 1;
  }

  sockaddr_in addr{};
  addr.sin_family = AF_INET;
  addr.sin_port = htons(kModbusPort);
  if (inet_pton(AF_INET, server_ip, &addr.sin_addr) <= 0) {
    std::cerr << "Invalid server IP\n";
    close(sock);
    return 1;
  }

  if (connect(sock, reinterpret_cast<sockaddr *>(&addr), sizeof(addr)) < 0) {
    std::cerr << "Connect failed\n";
    close(sock);
    return 1;
  }

  uint16_t transaction_id = 1;
  auto request = build_request(transaction_id, unit_id, function_code,
                               start_address, quantity);
  if (send(sock, request.data(), request.size(), 0) < 0) {
    std::cerr << "Send failed\n";
    close(sock);
    return 1;
  }

  std::vector<uint8_t> response(260);
  ssize_t received = recv(sock, response.data(), response.size(), 0);
  if (received <= 0) {
    std::cerr << "No response received\n";
    close(sock);
    return 1;
  }

  response.resize(static_cast<size_t>(received));
  parse_response(response);

  close(sock);
  return 0;
}
