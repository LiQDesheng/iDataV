#include <arpa/inet.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <unistd.h>

#include <array>
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

std::vector<uint8_t> build_exception_response(uint16_t transaction_id,
                                              uint8_t unit_id,
                                              uint8_t function_code,
                                              uint8_t exception_code) {
  std::vector<uint8_t> response(kMbapHeaderSize + 2);
  write_u16(response.data(), transaction_id);
  write_u16(response.data() + 2, 0);
  write_u16(response.data() + 4, 2 + 1);
  response[6] = unit_id;
  response[7] = static_cast<uint8_t>(function_code | 0x80);
  response[8] = exception_code;
  return response;
}

std::vector<uint8_t> build_read_coils_response(uint16_t transaction_id,
                                               uint8_t unit_id,
                                               uint16_t start_address,
                                               uint16_t quantity) {
  std::vector<uint8_t> coils(quantity, 0);
  for (uint16_t i = 0; i < quantity; ++i) {
    coils[i] = static_cast<uint8_t>((start_address + i) % 2);
  }

  uint8_t byte_count = static_cast<uint8_t>((quantity + 7) / 8);
  std::vector<uint8_t> response(kMbapHeaderSize + 2 + byte_count, 0);
  write_u16(response.data(), transaction_id);
  write_u16(response.data() + 2, 0);
  write_u16(response.data() + 4, static_cast<uint16_t>(2 + byte_count));
  response[6] = unit_id;
  response[7] = 0x01;
  response[8] = byte_count;

  for (uint16_t i = 0; i < quantity; ++i) {
    if (coils[i]) {
      response[9 + (i / 8)] |= static_cast<uint8_t>(1 << (i % 8));
    }
  }
  return response;
}

std::vector<uint8_t> build_read_holding_registers_response(
    uint16_t transaction_id,
    uint8_t unit_id,
    uint16_t start_address,
    uint16_t quantity) {
  uint8_t byte_count = static_cast<uint8_t>(quantity * 2);
  std::vector<uint8_t> response(kMbapHeaderSize + 2 + byte_count, 0);
  write_u16(response.data(), transaction_id);
  write_u16(response.data() + 2, 0);
  write_u16(response.data() + 4, static_cast<uint16_t>(2 + byte_count));
  response[6] = unit_id;
  response[7] = 0x03;
  response[8] = byte_count;

  for (uint16_t i = 0; i < quantity; ++i) {
    uint16_t value = static_cast<uint16_t>(start_address + i + 1);
    write_u16(response.data() + 9 + i * 2, value);
  }
  return response;
}

std::vector<uint8_t> handle_request(const std::vector<uint8_t> &request) {
  if (request.size() < kMbapHeaderSize + 2) {
    return {};
  }

  uint16_t transaction_id = read_u16(request.data());
  uint16_t protocol_id = read_u16(request.data() + 2);
  uint16_t length = read_u16(request.data() + 4);
  uint8_t unit_id = request[6];

  if (protocol_id != 0 || request.size() < kMbapHeaderSize + length) {
    return build_exception_response(transaction_id, unit_id, request[7], 0x03);
  }

  uint8_t function_code = request[7];
  if (function_code != 0x01 && function_code != 0x03) {
    return build_exception_response(transaction_id, unit_id, function_code, 0x01);
  }

  if (length < 6) {
    return build_exception_response(transaction_id, unit_id, function_code, 0x03);
  }

  uint16_t start_address = read_u16(request.data() + 8);
  uint16_t quantity = read_u16(request.data() + 10);
  if (quantity == 0) {
    return build_exception_response(transaction_id, unit_id, function_code, 0x03);
  }

  if (function_code == 0x01) {
    if (quantity > 2000) {
      return build_exception_response(transaction_id, unit_id, function_code, 0x03);
    }
    return build_read_coils_response(transaction_id, unit_id, start_address,
                                     quantity);
  }

  if (quantity > 125) {
    return build_exception_response(transaction_id, unit_id, function_code, 0x03);
  }
  return build_read_holding_registers_response(transaction_id, unit_id,
                                               start_address, quantity);
}
}  // namespace

int main() {
  int server_fd = socket(AF_INET, SOCK_STREAM, 0);
  if (server_fd < 0) {
    std::cerr << "Failed to create socket\n";
    return 1;
  }

  int reuse = 1;
  setsockopt(server_fd, SOL_SOCKET, SO_REUSEADDR, &reuse, sizeof(reuse));

  sockaddr_in addr{};
  addr.sin_family = AF_INET;
  addr.sin_addr.s_addr = INADDR_ANY;
  addr.sin_port = htons(kModbusPort);

  if (bind(server_fd, reinterpret_cast<sockaddr *>(&addr), sizeof(addr)) < 0) {
    std::cerr << "Bind failed\n";
    close(server_fd);
    return 1;
  }

  if (listen(server_fd, 5) < 0) {
    std::cerr << "Listen failed\n";
    close(server_fd);
    return 1;
  }

  std::cout << "Modbus TCP server listening on port " << kModbusPort << "\n";

  while (true) {
    sockaddr_in client_addr{};
    socklen_t client_len = sizeof(client_addr);
    int client_fd = accept(server_fd, reinterpret_cast<sockaddr *>(&client_addr),
                           &client_len);
    if (client_fd < 0) {
      std::cerr << "Accept failed\n";
      continue;
    }

    std::array<uint8_t, 260> buffer{};
    ssize_t received = recv(client_fd, buffer.data(), buffer.size(), 0);
    if (received > 0) {
      std::vector<uint8_t> request(buffer.begin(), buffer.begin() + received);
      auto response = handle_request(request);
      if (!response.empty()) {
        send(client_fd, response.data(), response.size(), 0);
      }
    }

    close(client_fd);
  }

  close(server_fd);
  return 0;
}
