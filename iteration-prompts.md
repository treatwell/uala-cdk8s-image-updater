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
Please also run all the unit tests until they pass.
```

### augmentation
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

You already done the tests, but I'm not satified 

- the tests on updater_controller_spec must not be nested, all test must be written at root
- we are going to remember the entire ENV in the before each and restore it as it was in the after each, no test will deal with cleanup of ENV at the end
- the test must be written in given when then, not only the code separated in this 3 parts but also the test description or in a comment written the given when then explanation
- the test must be functional we will no assert interaction, we will assert functionality
- we will be always sure that we are asserting chagnes, that what is asserted is not what is comming from the fixtures, so we will check in the test that the when, the action actually did something
- as find_involved_applications sometimes exits, will always run this one this way `expect { controller.find_involved_applications }.not_to raise_error(SystemExit)`  so that in case of bad future refactor we see what failed instead of just running less tests and get a false possitve 
- you will run all the unit test to be sure the changes are successful
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
- You cannot use ERB Templates in the fixtures
- You must create fixtures for the new scenarios
- You must create tests for the new behaviour updater_controller_spec that do NOT mock the utilities
- The focus of the application is to update the docker tag of the image is already there, so we must preserve what we get from the yaml
- You need to understand that the data to be written into the yamls, comes from environment variables as this code is executed as a Drone CI docker step where the arguments are environment variables.
- You will always run all the unit test not only the tiny bit you changed, and you will run at least 3 times to be sure they are consistent.

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
Please also run all the unit tests until they pass.
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
