# CDK8S Image Updater Refactoring - Iteration Prompts

## Background Documentation

Before starting any iteration, please review these files for context:
- `refactoring-plan.md`: Contains the full technical analysis and plan
- `refactoring-iterations.md`: Contains the breakdown of work into smaller iterations
- `README.md`: Current project documentation

## Iteration 1 Prompt - Testing Infrastructure

```
Hi Roo, I need your help implementing the first iteration of our refactoring plan for the CDK8S Image Updater.

Background:
Please review these files first:
- refactoring-plan.md: Full technical analysis and testing strategy
- refactoring-iterations.md: Breakdown of iterations
- app/controllers/updater_controller.rb: Main controller logic
- app/utilities/updater_utilities.rb: Utilities implementation

Context:
- The project is a Ruby-based tool that updates Docker image references in a CDK8S IaC repository
- Currently there are no automated tests
- We need to add testing infrastructure before making functional changes

Objectives for this iteration:
1. Add RSpec testing setup
2. Create initial tests for UpdaterUtilities module focusing on current behavior
3. No functionality changes, only adding tests

The code uses these environment variables:
- GIT_SOURCE_TAG: For production deployments
- GIT_SOURCE_BRANCH and GIT_SOURCE_COMMIT_SHA: For development deployments
- GIT_IAC_REPO, GIT_IAC_TOKEN: For IAC repository access

Please help me set up the testing infrastructure and implement the first set of tests for the current functionality.
```

## Iteration 2 Prompt - Improve Test Coverage

```
Hi Roo, I need your help with the second iteration of our CDK8S Image Updater refactoring.

Background:
Please review these files first:
- refactoring-plan.md: Contains complete testing strategy
- refactoring-iterations.md: Overview of all iterations
- app/controllers/updater_controller.rb: Controller to be tested
- spec/*: Tests created in Iteration 1

Context:
- First iteration added basic RSpec setup and initial tests
- We need comprehensive test coverage before making functional changes
- Focus is on UpdaterController class testing

Objectives for this iteration:
1. Add tests for UpdaterController focusing on:
   - Configuration parsing
   - Current image tag generation
   - PR creation logic
2. Create test fixtures for YAML configurations
3. No functionality changes yet

Please help me expand our test coverage to include UpdaterController functionality.
```

## Iteration 3 Prompt - DOCKER_IMAGE_TAG Implementation

```
Hi Roo, I need your help with the third iteration of our CDK8S Image Updater refactoring.

Background:
Please review these files first:
- refactoring-plan.md: Contains the technical design for DOCKER_IMAGE_TAG
- refactoring-iterations.md: Previous iterations context
- app/controllers/updater_controller.rb: Code to be modified
- spec/*: Existing test coverage

Context:
- We now have test coverage for current functionality
- Need to add support for DOCKER_IMAGE_TAG
- Current behavior uses GIT_SOURCE_TAG for production deployments

Requirements:
1. When GIT_SOURCE_TAG is defined and NO DOCKER_IMAGE_TAG:
   - Should behave as current (use GIT_SOURCE_TAG)
2. When GIT_SOURCE_TAG and DOCKER_IMAGE_TAG are defined:
   - Should use DOCKER_IMAGE_TAG for image tag
   - Should continue using GIT_SOURCE_TAG for other purposes (PRs, etc)

Objectives for this iteration:
1. Implement DOCKER_IMAGE_TAG support
2. Add tests for new functionality
3. Update documentation

Please help me implement the DOCKER_IMAGE_TAG feature with tests.
```

## Iteration 4 Prompt - Integration Testing

```
Hi Roo, I need your help with the final iteration of our CDK8S Image Updater refactoring.

Background:
Please review these files first:
- refactoring-plan.md: Contains the integration testing strategy
- refactoring-iterations.md: Context from previous iterations
- app/controllers/updater_controller.rb: Main controller
- app/utilities/updater_utilities.rb: Utilities
- spec/*: Existing unit tests

Context:
- Basic test infrastructure is in place
- Unit tests cover both old and new functionality
- DOCKER_IMAGE_TAG support is implemented
- Need end-to-end testing coverage

Objectives for this iteration:
1. Add integration tests covering:
   - Development deployments (branch + commit)
   - Production deployments (tag only)
   - Production deployments (tag + docker image)
2. Test error cases and edge conditions
3. Final documentation updates

Please help me implement the integration tests and finalize the refactoring.
```

## How to Use These Prompts

1. Each iteration should be done in a separate feature branch
2. Start with Iteration 1 and proceed sequentially
3. Use the appropriate prompt when starting each iteration
4. Review and merge each iteration before starting the next
5. Add any learnings or adjustments to subsequent iteration prompts as needed

## Important Notes

- Always read the existing code and tests before making changes
- Maintain backward compatibility
- Include documentation updates with each iteration
- Add comments explaining test scenarios
- Keep the PR sizes manageable for review
- Update the refactoring-plan.md and refactoring-iterations.md if any insights from one iteration affect future iterations
