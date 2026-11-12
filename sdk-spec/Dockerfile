# Builds the SDK from source with its steps file under the Swift harness of the Flagsmith SDK
# behavioural spec. See https://github.com/Flagsmith/sdk-spec/tree/main/harness/swift
FROM docker.io/library/swift:6.4-noble AS build
WORKDIR /sdk
COPY . .
COPY --from=harness . /harness
RUN swift build --package-path /harness --configuration release \
    && cp "$(swift build --package-path /harness --configuration release --show-bin-path)/sdk-spec-harness" /usr/local/bin/

FROM docker.io/library/swift:6.4-noble-slim
COPY --from=build /usr/local/bin/sdk-spec-harness /usr/local/bin/
ENTRYPOINT ["sdk-spec-harness"]
