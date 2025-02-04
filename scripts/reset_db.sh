#!/bin/bash

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <dev|prod>"
    exit 1
fi

ENV=$1

if [ "$ENV" != "dev" ] && [ "$ENV" != "prod" ]; then
    echo "Error: Environment must be 'dev' or 'prod'"
    exit 1
fi

echo "Deleting $ENV data..."

# Select project and delete all collections
firebase use "reel-ai-$ENV"
firebase firestore:delete --all-collections -f

echo "Done!" 