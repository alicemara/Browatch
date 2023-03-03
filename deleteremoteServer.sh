#!/bin/bash

# Deletes any instances with browatch tag if they exist

doid=$(aws ec2 describe-instances --filters "Name=instance.group-name,Values='browatch'" --output text --query 'Reservations[*].Instances[*].InstanceId')

if [ -n "$doid" ]; then
aws ec2 terminate-instances --instance-ids $doid
echo "Wait 30 seconds to allow any extra instances to terminate"

else
echo "No previous browatch instances found to terminate."

fi
