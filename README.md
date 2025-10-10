# Advanced Distributed System (ADS) Project

A comprehensive distributed system for performance analysis with automated orchestration, workload generation, comprehensive logging, and performance analysis tools.

## 🚀 Project Overview

This project implements a microservices-based distributed system designed for performance testing and analysis. It features autonomous load generation agents, real-time metrics collection, and comprehensive performance monitoring capabilities.

### 🎯 Key Features

- **🏗️ Microservices Architecture**: Independent services with REST API communication
- **⚡ Performance Testing**: Automated load generation with configurable parameters
- **📊 Real-time Metrics**: Comprehensive performance monitoring with Spring Actuator
- **🤖 Autonomous Agents**: Semi-autonomous load generation and testing agents
- **🔄 Async Processing**: Multi-threaded concurrent operations
- **🐳 Docker Integration**: Containerized database services

## 🛠️ Technology Stack

- **Backend**: Spring Boot 3.5.6, Java 21
- **Database**: PostgreSQL 17.5 (Production), H2 (Testing)
- **Build Tool**: Maven
- **Metrics**: Micrometer + Spring Actuator
- **Containerization**: Docker & Docker Compose
- **Testing**: JUnit 5, Mockito

## 📁 Project Structure

```
ads-proj/
├── src/
│   ├── main/
│   │   ├── java/com/umu/ads_proj/
│   │   │   ├── controller/          # REST API Controllers
│   │   │   │   ├── UserController.java
│   │   │   │   └── LoadGenerationController.java
│   │   │   ├── service/             # Business Logic Services
│   │   │   │   ├── UserService.java
│   │   │   │   └── LoadGenerationService.java
│   │   │   ├── entity/              # JPA Entities
│   │   │   │   └── User.java
│   │   │   ├── repository/          # Data Access Layer
│   │   │   │   └── UserRepository.java
│   │   │   └── config/              # Configuration
│   │   │       └── AsyncConfig.java
│   │   └── resources/
│   │       └── application.properties
│   └── test/                        # Test Suite
├── compose.yaml                     # Docker Compose Configuration
└── pom.xml                         # Maven Dependencies
```

## 🚦 Quick Start

### Prerequisites

- Java 21+
- Maven 3.6+
- Docker & Docker Compose

### 1. Clone the Repository

```bash
git clone <repository-url>
cd ads-proj
```

### 2. Start Database Services

```bash
docker-compose up -d
```

### 3. Run the Application

```bash
./mvnw spring-boot:run
```

The application will start on `http://localhost:8081`

### 4. Run Tests

```bash
./mvnw test
```

## 🔍 API Endpoints

### User Service APIs

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/users/health` | Health check |
| GET | `/api/users` | Get all users (paginated) |
| GET | `/api/users/{id}` | Get user by ID |
| POST | `/api/users` | Create new user |
| PUT | `/api/users/{id}` | Update user |
| DELETE | `/api/users/{id}` | Delete user |

### Load Generation APIs

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/load/health` | Load generation health check |
| POST | `/api/load/quick-test` | Quick performance test (50 users) |
| POST | `/api/load/users` | Custom user load generation |
| POST | `/api/load/mixed` | Mixed operation load testing |

### Metrics & Monitoring

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/actuator/metrics` | All available metrics |
| GET | `/actuator/metrics/http.server.requests` | HTTP request metrics |
| GET | `/actuator/health` | Application health |

## 🧪 Performance Testing Examples

### Quick Performance Test
```bash
curl -X POST http://localhost:8081/api/load/quick-test
```

### Custom Load Generation
```bash
curl -X POST "http://localhost:8081/api/load/users?numberOfUsers=100&concurrencyLevel=20"
```

### Mixed Operation Testing
```bash
curl -X POST "http://localhost:8081/api/load/mixed?operations=200&createRatio=0.3&readRatio=0.6&updateRatio=0.1"
```

### View Performance Metrics
```bash
curl -X GET "http://localhost:8081/actuator/metrics/http.server.requests"
```

## 📊 Performance Analysis

The system provides comprehensive performance metrics including:

- **Throughput**: Requests processed per second
- **Latency**: Response times (average, max, percentiles)
- **Resource Usage**: Database connections, JVM memory, CPU
- **Error Rates**: Success/failure ratios
- **Concurrent Operations**: Thread pool utilization

## 🏗️ Architecture Components

### Current Implementation

- ✅ **User Service**: Complete CRUD operations with performance metrics
- ✅ **Load Generation System**: Autonomous testing agents
- ✅ **Database Integration**: PostgreSQL with connection pooling
- ✅ **Metrics Collection**: Real-time performance monitoring
- ✅ **Async Processing**: Multi-threaded load generation

### Planned Extensions

- 🔄 **Order Service**: Product order management microservice
- 🔄 **Payment Service**: Payment processing microservice
- 🔄 **Kafka Integration**: Event-driven inter-service communication
- 🔄 **Grafana Dashboards**: Visual performance monitoring
- 🔄 **CI/CD Pipeline**: Automated deployment and testing

## 🤝 Contributing

This project is part of an academic distributed systems study. For development:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📈 Performance Benchmarks

Current system performance (baseline metrics):

- **Average Response Time**: ~15.9ms per request
- **Maximum Response Time**: <100ms
- **Throughput**: ~63 requests/second
- **Concurrent Users**: Tested up to 50 concurrent operations
- **Zero Error Rate**: 100% success rate under normal load

## 📝 Development Notes

### Database Configuration

- **Production**: PostgreSQL on port 5432
- **Testing**: H2 in-memory database
- **Connection Pool**: HikariCP with optimized settings

### Async Configuration

- **Core Pool Size**: 10 threads
- **Maximum Pool Size**: 50 threads
- **Queue Capacity**: 100 tasks

## 📄 License

This project is developed for academic purposes as part of distributed systems coursework.

---

**Built with ❤️ for Advanced Distributed Systems learning**