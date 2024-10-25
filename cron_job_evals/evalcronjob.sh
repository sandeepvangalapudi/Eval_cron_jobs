#!/bin/bash

# Default values
DEFAULT_YAML_FILE="Evallyaml"
DEFAULT_LOG_DIR="storinglogsdirectory"
DEFAULT_state="NV"

# Use command-line arguments if provided, otherwise use defaults
YAML_FILE="${1:-$DEFAULT_YAML_FILE}"
LOG_DIR="${2:-$DEFAULT_LOG_DIR}"
STATE="${3:-$DEFAULT_state}"

llm_url=$(grep -E '^[[:space:]]*deployment_url:' "$YAML_FILE" | awk -F ': ' '{print $2}' | xargs)
llm_key=$(grep -E '^[[:space:]]*deployment_key:' "$YAML_FILE" | awk -F ': ' '{print $2}' | xargs)

if [ -z "$llm_url" ] || [ -z "$llm_key" ]; then
    echo "Error: Could not extract llm_url or llm_key."
    exit 1
fi

llm_url=$(echo "$llm_url" | sed 's:/*$::')

prompt="What is the capital of France?"
model="meta-llama/Meta-Llama-3.1-8B-Instruct"

response=$(curl -i -X POST "$llm_url/completions" \
-H "Authorization: Bearer $llm_key" \
-H "Content-Type: application/json" \
-d '{
  "model": "'"$model"'",
  "prompt": "'"$prompt"'",
  "max_tokens": 50
}')

if echo "$response" | grep -q "200 OK"; then
    echo "Request succeeded with a 200 OK response."

    CURRENT_DATE=$(date -d "yesterday" +%Y-%m-%d)
    PREVIOUS_DATE=$(date -d "1 days ago" +%Y-%m-%d)

    sed -i "s/^\([[:space:]]*date_start: \).*/\1\"$PREVIOUS_DATE\"/" $YAML_FILE
    sed -i "s/^\([[:space:]]*date_end: \).*/\1\"$CURRENT_DATE\"/" $YAML_FILE
    echo "Updated date_start to $PREVIOUS_DATE and date_end to $CURRENT_DATE in $YAML_FILE"

    EXPERIMENT_NAME=Eval_"$STATE"_"$CURRENT_DATE"
    sed -i "s/^  experiment: .*/  experiment: $EXPERIMENT_NAME/" $YAML_FILE
    sed -i "s/^\([[:space:]]*experiment: \).*/\1\"$EXPERIMENT_NAME\"/" $YAML_FILE
    echo "Updated mlflow.experiment to $EXPERIMENT_NAME in $YAML_FILE"

    OUTPUT=$(d3x dataset evaluate --config $YAML_FILE)

    JOB_ID=$(echo $OUTPUT | grep -oP "'job': '\K[^']+")
    if [ -n "$JOB_ID" ]; then
        echo "Job ID found: $JOB_ID"
        while true; do
            POD_STATUS=$(kubectl get pods -l job-name="$JOB_ID" -o jsonpath='{.items[0].status.phase}')

            # Check the pod status
            if [ "$POD_STATUS" = "Running" ]; then
                echo "Pod is in Running state."
            elif [ "$POD_STATUS" = "Succeeded" ]; then
                echo "Pod has completed successfully."
                break
            elif [ "$POD_STATUS" = "Failed" ]; then
                echo "Pod has failed. Exiting loop."
                break
            elif [ -z "$POD_STATUS" ]; then
                echo "No pod found. Polling again in 10 seconds..."
            else
                echo "Pod is in $POD_STATUS state. Polling again in 10 seconds..."
            fi

            # Sleep before the next check
            sleep 10
        done

        TIMESTAMP=$(TZ="Asia/Kolkata" date +%Y%m%d%H%M)
        LOG_FILE="$LOG_DIR/Eval_$JOB_ID_$TIMESTAMP.log"
        kubectl logs -l job-name=$JOB_ID --limit-bytes=500000 --tail=-1 --follow >"$LOG_FILE"
        echo "Logs saved to: $LOG_FILE"

    else
        echo "No job ID found in the output: $OUTPUT"
    fi
else
    echo "Request failed. No 200 OK response found."
fi