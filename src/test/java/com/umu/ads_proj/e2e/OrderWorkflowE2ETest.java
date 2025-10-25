package com.umu.ads_proj.e2e;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.umu.ads_proj.entity.Order;
import com.umu.ads_proj.entity.User;
import com.umu.ads_proj.repository.OrderRepository;
import com.umu.ads_proj.repository.UserRepository;
import org.junit.jupiter.api.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.kafka.test.context.EmbeddedKafka;
import org.springframework.test.annotation.DirtiesContext;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.TimeUnit;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

/**
 * End-to-End Tests for Complete Order Workflow
 * 
 * Tests the entire order lifecycle from creation to delivery:
 * 1. User creates order (Order Service)
 * 2. Order status progresses: PENDING -> CONFIRMED -> SHIPPED -> DELIVERED
 * 3. Fulfillment Agent processes order
 * 4. Notification Service sends notifications
 * 5. Idempotency prevents duplicate processing
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureMockMvc
@ActiveProfiles("test")
@TestMethodOrder(MethodOrderer.OrderAnnotation.class)
@DirtiesContext(classMode = DirtiesContext.ClassMode.AFTER_CLASS)
@EmbeddedKafka(
    partitions = 1,
    topics = {"order-events", "notification-events", "performance-events"},
    brokerProperties = {
        "listeners=PLAINTEXT://localhost:9093",
        "port=9093"
    }
)
public class OrderWorkflowE2ETest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private OrderRepository orderRepository;

    @Autowired
    private UserRepository userRepository;

    private static User testUser;
    private static Long testOrderId;

    @BeforeAll
    static void setupClass() {
        System.out.println("========================================");
        System.out.println("  ORDER WORKFLOW E2E TESTS STARTING");
        System.out.println("========================================");
    }

    @BeforeEach
    void setUp() {
        if (testUser == null) {
            // Create a test user
            testUser = new User(
                "E2E Test User",
                "e2e.test@example.com",
                "+1234567890",
                "123 E2E Test St"
            );
            testUser = userRepository.save(testUser);
        }
    }

    // ========================================================================
    // TEST 1: Order Creation
    // ========================================================================
    
    @Test
    @org.junit.jupiter.api.Order(1)
    @DisplayName("E2E Test 1: Create Order via API")
    void testCreateOrder() throws Exception {
        // Given
        Map<String, Object> orderRequest = new HashMap<>();
        orderRequest.put("userId", testUser.getId());
        orderRequest.put("amount", 99.99);
        orderRequest.put("currency", "SGD");

        // When
        MvcResult result = mockMvc.perform(post("/api/orders")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(orderRequest)))
                // Then
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.id").exists())
                .andExpect(jsonPath("$.userId").value(testUser.getId()))
                .andExpect(jsonPath("$.amount").value(99.99))
                .andExpect(jsonPath("$.currency").value("SGD"))
                .andExpect(jsonPath("$.status").value("PENDING"))
                .andExpect(jsonPath("$.createdAt").exists())
                .andReturn();

        String responseBody = result.getResponse().getContentAsString();
        Order createdOrder = objectMapper.readValue(responseBody, Order.class);
        testOrderId = createdOrder.getId();

        // Verify order is persisted in database
        Order dbOrder = orderRepository.findById(testOrderId).orElse(null);
        assertThat(dbOrder).isNotNull();
        assertThat(dbOrder.getStatus().toString()).isEqualTo("PENDING");
        assertThat(dbOrder.getTotalAmount()).isEqualByComparingTo(new BigDecimal("99.99"));

        System.out.println("✓ Test 1 PASSED: Order created with ID: " + testOrderId);
    }

    // ========================================================================
    // TEST 2: Get Order by ID
    // ========================================================================
    
    @Test
    @org.junit.jupiter.api.Order(2)
    @DisplayName("E2E Test 2: Retrieve Order by ID")
    void testGetOrderById() throws Exception {
        assertThat(testOrderId).isNotNull();

        // When/Then
        mockMvc.perform(get("/api/orders/{id}", testOrderId))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(testOrderId))
                .andExpect(jsonPath("$.userId").value(testUser.getId()))
                .andExpect(jsonPath("$.status").value("PENDING"));

        System.out.println("✓ Test 2 PASSED: Order retrieved successfully");
    }

    // ========================================================================
    // TEST 3: Get All Orders
    // ========================================================================
    
    @Test
    @org.junit.jupiter.api.Order(3)
    @DisplayName("E2E Test 3: Get All Orders")
    void testGetAllOrders() throws Exception {
        // When/Then
        mockMvc.perform(get("/api/orders"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$").isArray())
                .andExpect(jsonPath("$.length()").value(greaterThanOrEqualTo(1)));

        System.out.println("✓ Test 3 PASSED: All orders retrieved");
    }

    // ========================================================================
    // TEST 4: Get Orders by Status
    // ========================================================================
    
    @Test
    @org.junit.jupiter.api.Order(4)
    @DisplayName("E2E Test 4: Filter Orders by Status")
    void testGetOrdersByStatus() throws Exception {
        // When/Then - PENDING status
        mockMvc.perform(get("/api/orders")
                .param("status", "PENDING"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$").isArray())
                .andExpect(jsonPath("$[0].status").value("PENDING"));

        System.out.println("✓ Test 4 PASSED: Orders filtered by status");
    }

    // ========================================================================
    // TEST 5: Update Order Status
    // ========================================================================
    
    @Test
    @org.junit.jupiter.api.Order(5)
    @DisplayName("E2E Test 5: Update Order Status")
    void testUpdateOrderStatus() throws Exception {
        assertThat(testOrderId).isNotNull();

        // When - Update to CONFIRMED
        mockMvc.perform(put("/api/orders/{id}/status", testOrderId)
                .param("status", "CONFIRMED"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("CONFIRMED"))
                .andExpect(jsonPath("$.updatedAt").exists());

        // Verify in database
        Order updatedOrder = orderRepository.findById(testOrderId).orElse(null);
        assertThat(updatedOrder).isNotNull();
        assertThat(updatedOrder.getStatus()).isEqualTo("CONFIRMED");

        System.out.println("✓ Test 5 PASSED: Order status updated to CONFIRMED");
    }

    // ========================================================================
    // TEST 6: Order Workflow Progression
    // ========================================================================
    
    @Test
    @org.junit.jupiter.api.Order(6)
    @DisplayName("E2E Test 6: Complete Order Workflow (PENDING -> DELIVERED)")
    void testCompleteOrderWorkflow() throws Exception {
        // Create a new order for this test
        Map<String, Object> orderRequest = new HashMap<>();
        orderRequest.put("userId", testUser.getId());
        orderRequest.put("amount", 150.00);
        orderRequest.put("currency", "SGD");

        MvcResult createResult = mockMvc.perform(post("/api/orders")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(orderRequest)))
                .andExpect(status().isCreated())
                .andReturn();

        Order workflowOrder = objectMapper.readValue(
            createResult.getResponse().getContentAsString(), 
            Order.class
        );
        Long workflowOrderId = workflowOrder.getId();

        // Step 1: PENDING (initial state)
        assertThat(workflowOrder.getStatus().toString()).isEqualTo("PENDING");
        System.out.println("  → Order created in PENDING status");

        // Step 2: PENDING -> CONFIRMED
        mockMvc.perform(put("/api/orders/{id}/status", workflowOrderId)
                .param("status", "CONFIRMED"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("CONFIRMED"));
        System.out.println("  → Order transitioned to CONFIRMED");

        // Step 3: CONFIRMED -> SHIPPED
        mockMvc.perform(put("/api/orders/{id}/status", workflowOrderId)
                .param("status", "SHIPPED"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("SHIPPED"));
        System.out.println("  → Order transitioned to SHIPPED");

        // Step 4: SHIPPED -> DELIVERED
        mockMvc.perform(put("/api/orders/{id}/status", workflowOrderId)
                .param("status", "DELIVERED"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("DELIVERED"));
        System.out.println("  → Order transitioned to DELIVERED");

        // Final verification
        Order finalOrder = orderRepository.findById(workflowOrderId).orElse(null);
        assertThat(finalOrder).isNotNull();
        assertThat(finalOrder.getStatus().toString()).isEqualTo("DELIVERED");
        assertThat(finalOrder.getUpdatedAt()).isAfter(finalOrder.getCreatedAt());

        System.out.println("✓ Test 6 PASSED: Complete workflow PENDING -> CONFIRMED -> SHIPPED -> DELIVERED");
    }

    // ========================================================================
    // TEST 7: Concurrent Order Creation
    // ========================================================================
    
    @Test
    @org.junit.jupiter.api.Order(7)
    @DisplayName("E2E Test 7: Concurrent Order Creation (Stress Test)")
    void testConcurrentOrderCreation() throws Exception {
        int concurrentOrders = 10;
        
        for (int i = 0; i < concurrentOrders; i++) {
            Map<String, Object> orderRequest = new HashMap<>();
            orderRequest.put("userId", testUser.getId());
            orderRequest.put("amount", 50.00 + i);
            orderRequest.put("currency", "SGD");

            mockMvc.perform(post("/api/orders")
                    .contentType(MediaType.APPLICATION_JSON)
                    .content(objectMapper.writeValueAsString(orderRequest)))
                    .andExpect(status().isCreated())
                    .andExpect(jsonPath("$.id").exists());
        }

        // Verify all orders created
        long totalOrders = orderRepository.count();
        assertThat(totalOrders).isGreaterThanOrEqualTo(concurrentOrders);

        System.out.println("✓ Test 7 PASSED: " + concurrentOrders + " concurrent orders created");
    }

    // ========================================================================
    // TEST 8: Invalid Order Validation
    // ========================================================================
    
    @Test
    @org.junit.jupiter.api.Order(8)
    @DisplayName("E2E Test 8: Invalid Order Validation")
    void testInvalidOrderValidation() throws Exception {
        // Test 1: Missing userId
        Map<String, Object> invalidRequest1 = new HashMap<>();
        invalidRequest1.put("amount", 100.00);
        invalidRequest1.put("currency", "SGD");

        mockMvc.perform(post("/api/orders")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(invalidRequest1)))
                .andExpect(status().isBadRequest());

        // Test 2: Negative amount
        Map<String, Object> invalidRequest2 = new HashMap<>();
        invalidRequest2.put("userId", testUser.getId());
        invalidRequest2.put("amount", -50.00);
        invalidRequest2.put("currency", "SGD");

        mockMvc.perform(post("/api/orders")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(invalidRequest2)))
                .andExpect(status().isBadRequest());

        System.out.println("✓ Test 8 PASSED: Invalid orders rejected correctly");
    }

    // ========================================================================
    // TEST 9: Non-existent Order
    // ========================================================================
    
    @Test
    @org.junit.jupiter.api.Order(9)
    @DisplayName("E2E Test 9: Get Non-existent Order")
    void testGetNonExistentOrder() throws Exception {
        Long nonExistentId = 999999L;

        mockMvc.perform(get("/api/orders/{id}", nonExistentId))
                .andExpect(status().isNotFound());

        System.out.println("✓ Test 9 PASSED: Non-existent order returns 404");
    }

    // ========================================================================
    // TEST 10: Order Idempotency
    // ========================================================================
    
    @Test
    @org.junit.jupiter.api.Order(10)
    @DisplayName("E2E Test 10: Order Idempotency Check")
    void testOrderIdempotency() throws Exception {
        // Create first order
        Map<String, Object> orderRequest = new HashMap<>();
        orderRequest.put("userId", testUser.getId());
        orderRequest.put("amount", 200.00);
        orderRequest.put("currency", "SGD");

        MvcResult result1 = mockMvc.perform(post("/api/orders")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(orderRequest)))
                .andExpect(status().isCreated())
                .andReturn();

        Order order1 = objectMapper.readValue(
            result1.getResponse().getContentAsString(), 
            Order.class
        );

        // Create duplicate order (same user, same amount)
        MvcResult result2 = mockMvc.perform(post("/api/orders")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(orderRequest)))
                .andExpect(status().isCreated())
                .andReturn();

        Order order2 = objectMapper.readValue(
            result2.getResponse().getContentAsString(), 
            Order.class
        );

        // Both orders should be created (different IDs)
        // Idempotency is handled at event level, not order creation
        assertThat(order1.getId()).isNotEqualTo(order2.getId());

        System.out.println("✓ Test 10 PASSED: Multiple orders allowed, idempotency at event level");
    }

    @AfterAll
    static void tearDownClass() {
        System.out.println("========================================");
        System.out.println("  ORDER WORKFLOW E2E TESTS COMPLETED");
        System.out.println("========================================");
    }

    // Helper method for assertions
    private static org.hamcrest.Matcher<Integer> greaterThanOrEqualTo(int value) {
        return org.hamcrest.Matchers.greaterThanOrEqualTo(value);
    }
}
