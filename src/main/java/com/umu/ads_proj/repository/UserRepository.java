package com.umu.ads_proj.repository;

import com.umu.ads_proj.entity.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface UserRepository extends JpaRepository<User, Long> {
    
    /**
     * Find user by email address
     */
    Optional<User> findByEmail(String email);
    
    /**
     * Find users by name containing the given string (case-insensitive)
     */
    List<User> findByNameContainingIgnoreCase(String name);
    
    /**
     * Find users by phone number
     */
    Optional<User> findByPhoneNumber(String phoneNumber);
    
    /**
     * Check if email already exists (for validation)
     */
    boolean existsByEmail(String email);
    
    /**
     * Check if phone number already exists (for validation)
     */
    boolean existsByPhoneNumber(String phoneNumber);
    
    /**
     * Custom query to find users by address containing specific text
     */
    @Query("SELECT u FROM User u WHERE u.address LIKE %:address%")
    List<User> findByAddressContaining(@Param("address") String address);
    
    /**
     * Count total number of users (useful for performance testing)
     */
    @Query("SELECT COUNT(u) FROM User u")
    long countTotalUsers();
}