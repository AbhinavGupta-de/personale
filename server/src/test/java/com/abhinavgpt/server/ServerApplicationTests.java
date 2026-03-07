package com.abhinavgpt.server;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;

@SpringBootTest
@Import(TestcontainersConfig.class)
class ServerApplicationTests {

    @Test
    void contextLoads() {
    }

}
