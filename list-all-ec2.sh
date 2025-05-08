#!/bin/bash

# Get all AWS regions
regions=$(aws ec2 describe-regions --query "Regions[].RegionName" --output text)

# Loop through regions
for region in $regions; do
    echo "🔍 Region: $region"
    aws ec2 describe-instances \
        --region "$region" \
        --query "Reservations[].Instances[].{ID:InstanceId,Type:InstanceType,State:State.Name,AZ:Placement.AvailabilityZone,Name:Tags[?Key=='Name']|[0].Value}" \
        --output table
    echo "---------------------------"
done

