# Testing with Real API Keys

## Overview
The test suite includes both unit tests (with mocks) and integration tests that can use real Flagsmith API keys for more comprehensive testing.

## Setting up Real API Key Testing

### Method 1: Environment Variable (Recommended)
```bash
export FLAGSMITH_TEST_API_KEY="your-real-api-key-here"
swift test
```

### Method 2: Local Config File (Not committed to git)
Create `FlagsmithClient/Tests/test-config.json`:
```json
{
  "apiKey": "your-real-api-key-here"
}
```

## Test Behavior

### With Mock Keys (Default)
- Unit tests pass as expected
- Integration tests fail with JSON decode errors (expected)
- Cache behavior still validated through unit tests

### With Real API Keys
- Full end-to-end testing
- Real network requests to Flagsmith API
- Cache population and skipAPI behavior fully validated
- Customer use case scenarios tested with actual data

## Test Categories

- **Unit Tests**: Always work with mocks (CacheTests, APIManagerTests core functions)
- **Integration Tests**: Benefit from real API keys (FlagsmithCacheIntegrationTests, CustomerCacheUseCaseTests)
- **Black Box Tests**: Test public API with real or mock keys

## Running Specific Test Suites

```bash
# Run just unit tests (work with mocks)
swift test --filter CacheTests
swift test --filter CachedURLResponseTests

# Run integration tests (better with real keys)
swift test --filter FlagsmithCacheIntegrationTests
swift test --filter CustomerCacheUseCaseTests
```