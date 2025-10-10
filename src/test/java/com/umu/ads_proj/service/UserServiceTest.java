package com.umu.ads_proj.service;

import com.umu.ads_proj.entity.User;
import com.umu.ads_proj.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.transaction.annotation.Transactional;

import static org.junit.jupiter.api.Assertions.*;

@SpringBootTest
@Transactional
@ActiveProfiles("test")
class UserServiceTest {

    @Autowired
    private UserService userService;

    @Autowired
    private UserRepository userRepository;

    private User testUser;

    @BeforeEach
    void setUp() {
        testUser = new User(
            "John Doe", 
            "john.doe@example.com", 
            "+1234567890", 
            "123 Main St, City, Country"
        );
    }

    @Test
    void testCreateUser() {
        // When
        User createdUser = userService.createUser(testUser);

        // Then
        assertNotNull(createdUser.getId());
        assertEquals("John Doe", createdUser.getName());
        assertEquals("john.doe@example.com", createdUser.getEmail());
        assertNotNull(createdUser.getCreatedAt());
    }

    @Test
    void testGetUserById() {
        // Given
        User savedUser = userService.createUser(testUser);

        // When
        var foundUser = userService.getUserById(savedUser.getId());

        // Then
        assertTrue(foundUser.isPresent());
        assertEquals("John Doe", foundUser.get().getName());
    }

    @Test
    void testGetUserByEmail() {
        // Given  
        userService.createUser(testUser);

        // When
        var foundUser = userService.getUserByEmail("john.doe@example.com");

        // Then
        assertTrue(foundUser.isPresent());
        assertEquals("John Doe", foundUser.get().getName());
    }

    @Test
    void testCreateUserWithDuplicateEmail() {
        // Given
        userService.createUser(testUser);

        // When & Then
        User duplicateUser = new User(
            "Jane Doe", 
            "john.doe@example.com", // Same email
            "+0987654321", 
            "456 Oak St, City, Country"
        );
        
        assertThrows(IllegalArgumentException.class, () -> {
            userService.createUser(duplicateUser);
        });
    }

    @Test
    void testUpdateUser() {
        // Given
        User savedUser = userService.createUser(testUser);
        
        // When
        savedUser.setName("John Updated");
        savedUser.setAddress("Updated Address");
        User updatedUser = userService.updateUser(savedUser.getId(), savedUser);

        // Then
        assertEquals("John Updated", updatedUser.getName());
        assertEquals("Updated Address", updatedUser.getAddress());
        assertNotNull(updatedUser.getUpdatedAt());
    }

    @Test
    void testDeleteUser() {
        // Given
        User savedUser = userService.createUser(testUser);
        
        // When
        userService.deleteUser(savedUser.getId());

        // Then
        var deletedUser = userService.getUserById(savedUser.getId());
        assertFalse(deletedUser.isPresent());
    }

    @Test
    void testGetTotalUserCount() {
        // Given
        long initialCount = userService.getTotalUserCount();
        userService.createUser(testUser);

        // When
        long newCount = userService.getTotalUserCount();

        // Then
        assertEquals(initialCount + 1, newCount);
    }
}