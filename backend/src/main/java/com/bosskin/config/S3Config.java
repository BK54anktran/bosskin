package com.bosskin.config;

import lombok.RequiredArgsConstructor;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import software.amazon.awssdk.auth.credentials.AwsBasicCredentials;
import software.amazon.awssdk.auth.credentials.StaticCredentialsProvider;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.S3ClientBuilder;
import software.amazon.awssdk.services.s3.presigner.S3Presigner;

import java.net.URI;

@Configuration
@RequiredArgsConstructor
public class S3Config {

    private final S3Properties props;

    @Bean
    S3Client s3Client() {
        S3ClientBuilder builder = S3Client.builder()
                .credentialsProvider(credentials())
                .region(Region.of(props.getRegion()));

        if (props.getEndpoint() != null && !props.getEndpoint().isBlank()) {
            builder.endpointOverride(URI.create(props.getEndpoint()))
                   .forcePathStyle(true);
        }

        return builder.build();
    }

    @Bean
    S3Presigner s3Presigner() {
        S3Presigner.Builder builder = S3Presigner.builder()
                .credentialsProvider(credentials())
                .region(Region.of(props.getRegion()));

        if (props.getEndpoint() != null && !props.getEndpoint().isBlank()) {
            builder.endpointOverride(URI.create(props.getEndpoint()));
        }

        return builder.build();
    }

    private StaticCredentialsProvider credentials() {
        return StaticCredentialsProvider.create(
                AwsBasicCredentials.create(props.getAccessKey(), props.getSecretKey()));
    }
}
