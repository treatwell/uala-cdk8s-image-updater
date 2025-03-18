#!/bin/bash

# Run the test 5 times and collect results
for i in {1..5}; do
    echo "Run #$i"

    # Capture RSpec output in a variable
    OUTPUT=$(bundle exec rspec spec/ --format documentation 2>&1)

    echo "$OUTPUT" | grep 'Randomized with seed'
    echo "$OUTPUT" | grep 'Finished in '

    # Extract examples and failures
    echo "$OUTPUT" | grep -E '([0-9]+ examples?, [0-9]+ failures?)'

    # Extract Line and Branch coverage
    echo "$OUTPUT" | grep -E 'Line Coverage|Branch Coverage'

    echo "--------------------------------"
done
