package com.umu.ads_proj.event;

import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonProperty;

/**
 * Event published when a user is created, updated, or deleted
 */
public class UserEvent extends BaseEvent {
    
    public enum UserAction {
        CREATED, UPDATED, DELETED
    }
    
    private Long userId;
    private String userName;
    private String userEmail;
    private UserAction action;
    private String details;
    
    // Default constructor for JSON deserialization
    public UserEvent() {
        super();
    }
    
    @JsonCreator
    public UserEvent(
            @JsonProperty("userId") Long userId,
            @JsonProperty("userName") String userName,
            @JsonProperty("userEmail") String userEmail,
            @JsonProperty("action") UserAction action,
            @JsonProperty("details") String details) {
        super("USER_EVENT", "user-service");
        this.userId = userId;
        this.userName = userName;
        this.userEmail = userEmail;
        this.action = action;
        this.details = details;
    }
    
    // Static factory methods for easier creation
    public static UserEvent userCreated(Long userId, String userName, String userEmail) {
        return new UserEvent(userId, userName, userEmail, UserAction.CREATED, 
                           "User created successfully");
    }
    
    public static UserEvent userUpdated(Long userId, String userName, String userEmail) {
        return new UserEvent(userId, userName, userEmail, UserAction.UPDATED, 
                           "User updated successfully");
    }
    
    public static UserEvent userDeleted(Long userId, String userName, String userEmail) {
        return new UserEvent(userId, userName, userEmail, UserAction.DELETED, 
                           "User deleted successfully");
    }
    
    // Getters and Setters
    public Long getUserId() {
        return userId;
    }
    
    public void setUserId(Long userId) {
        this.userId = userId;
    }
    
    public String getUserName() {
        return userName;
    }
    
    public void setUserName(String userName) {
        this.userName = userName;
    }
    
    public String getUserEmail() {
        return userEmail;
    }
    
    public void setUserEmail(String userEmail) {
        this.userEmail = userEmail;
    }
    
    public UserAction getAction() {
        return action;
    }
    
    public void setAction(UserAction action) {
        this.action = action;
    }
    
    public String getDetails() {
        return details;
    }
    
    public void setDetails(String details) {
        this.details = details;
    }
    
    @Override
    public String toString() {
        return "UserEvent{" +
                "userId=" + userId +
                ", userName='" + userName + '\'' +
                ", userEmail='" + userEmail + '\'' +
                ", action=" + action +
                ", details='" + details + '\'' +
                ", " + super.toString() +
                '}';
    }
}