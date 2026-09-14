package com.pm.apigateway.filter;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.cloud.gateway.filter.GatewayFilter;
import org.springframework.cloud.gateway.filter.factory.AbstractGatewayFilterFactory;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import org.springframework.web.reactive.function.client.WebClient;
import org.springframework.web.reactive.function.client.WebClientResponseException;

@Component
public class JwtValidationGatewayFilterFactory extends
        AbstractGatewayFilterFactory<JwtValidationGatewayFilterFactory.Config> {

    private final WebClient webClient;

    public JwtValidationGatewayFilterFactory(
            @Value("${auth.service.url}") String authServiceUrl) {
        super(Config.class);
        this.webClient = WebClient.builder()
                .baseUrl(authServiceUrl)
                .build();
    }

    @Override
    public GatewayFilter apply(Config config) {
        return (exchange, chain) -> {
            String token = exchange.getRequest().getHeaders().getFirst(HttpHeaders.AUTHORIZATION);

            if (token == null || !token.startsWith("Bearer ")) {
                exchange.getResponse().setStatusCode(HttpStatus.UNAUTHORIZED);
                return exchange.getResponse().setComplete();
            }

            return webClient.get()
                    .uri("/validate")
                    .header(HttpHeaders.AUTHORIZATION, token)
                    .retrieve()
                    .toBodilessEntity()
                    .then(chain.filter(exchange))
                    // Fix: Return 401 instead of crashing with HTTP 500 when auth fails
                    .onErrorResume(WebClientResponseException.class, ex -> {
                        exchange.getResponse().setStatusCode(ex.getStatusCode());
                        return exchange.getResponse().setComplete();
                    });
        };
    }

    public static class Config {
    }
}