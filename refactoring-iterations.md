# CDK8S Image Updater Refactoring Iterations

## Overview

Breaking down the refactoring into smaller, reviewable iterations that deliver incremental value.

## Iteration 1: Testing Infrastructure

**Goal**: Add basic testing infrastructure and initial tests for current behavior.

### Changes:
1. Add RSpec setup
   - Update Gemfile
   - Add spec_helper.rb
   - Create basic directory structure
   - Set up test structure guidelines:
     * Enforce Given-When-Then pattern
     * Use explicit section comments
     * Maintain consistent structure

2. Add first set of tests for UpdaterUtilities
   - Focus on current application matching logic
   - Test existing tag handling behavior
   - No functionality changes, just testing current behavior

### Deliverables:
- Basic test infrastructure
- Initial test coverage for current functionality
- Documentation for running tests

## Iteration 2: Improve Test Coverage

**Goal**: Expand test coverage to UpdaterController before making functional changes.

### Changes:
1. Add tests for UpdaterController
   - Configuration parsing
   - Current image tag generation
   - PR creation logic

2. Add fixtures and test data
   - Create scenario-based fixture directories
   - Use only literal values in YAML configurations (no ERB templates)
   - Each YAML must reflect real-world configuration structure
   - Folder names must evoke test scenarios (e.g., "development", "production")
   - Create comprehensive fixtures covering all test cases

### Deliverables:
- Comprehensive test suite for existing functionality
- Well-organized, realistic test fixtures
- Clear fixture organization by test scenario
- Documentation updates for test coverage

## Iteration 3: DOCKER_IMAGE_TAG Implementation

**Goal**: Add new DOCKER_IMAGE_TAG functionality with tests.

### Changes:
1. Add DOCKER_IMAGE_TAG support
   - Update image tag generation logic
   - Add validation if needed
   - Add new tests specifically for this feature

2. Update documentation
   - Add DOCKER_IMAGE_TAG to README
   - Update example configurations

### Deliverables:
- New DOCKER_IMAGE_TAG functionality
- Tests for new functionality
- Updated documentation

## Iteration 4: Integration Testing

**Goal**: Add integration tests and end-to-end test scenarios.

### Changes:
1. Add integration tests
   - Full workflow tests
   - Different deployment scenarios
   - Error cases

2. Add any missing edge cases
   - Error handling improvements if needed
   - Additional validation if discovered

### Deliverables:
- Integration test suite
- Any discovered improvements
- Final documentation updates

## Review Considerations

Each iteration:
- Can be reviewed independently
- Maintains backward compatibility
- Has its own test coverage
- Includes relevant documentation updates
