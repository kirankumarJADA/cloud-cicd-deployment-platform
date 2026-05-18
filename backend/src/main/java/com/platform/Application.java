package com.platform;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/**
 * Cloud CI/CD Deployment Platform — sample production microservice.
 *
 * <p>This service intentionally keeps business logic minimal. Its purpose is to act
 * as a realistic, deployable artifact that exercises the full CI/CD and cloud
 * deployment pipeline: build, test, containerize, push, and remote deploy.</p>
 */
@SpringBootApplication
public class Application {

    public static void main(String[] args) {
        SpringApplication.run(Application.class, args);
    }
}
