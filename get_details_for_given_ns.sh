#!/bin/bash

# Set the namespace to the first command-line argument
namespace=$1
NAMESPACE=$1

# Create the debugDetails directory
mkdir debugDetails

# Store YAML output for all resources under debugDetails/yamls
kubectl get all -n $namespace -o yaml > debugDetails/yamls/all.yaml
kubectl get configmap -n $namespace -o yaml > debugDetails/yamls/configmaps.yaml
kubectl get secret -n $namespace -o yaml > debugDetails/yamls/secrets.yaml
kubectl get serviceaccount -n $namespace -o yaml > debugDetails/yamls/serviceaccounts.yaml
kubectl get role -n $namespace -o yaml > debugDetails/yamls/roles.yaml
kubectl get rolebinding -n $namespace -o yaml > debugDetails/yamls/rolebindings.yaml

# Store output of kubectl describe for all pods under given namespace in debugDetails/describe
mkdir debugDetails/describe
kubectl describe pods -n $namespace > debugDetails/describe/pods.txt

# Store output of kubectl event for given namespace in debugDetails/events
mkdir debugDetails/events
kubectl get events -n $namespace > debugDetails/events/events.txt

# Store YAML output for all nodes in debugDetails/nodeyaml
mkdir debugDetails/nodeyaml
kubectl get nodes -o yaml > debugDetails/nodeyaml/nodes.yaml

# Store kubectl describe output for all nodes in debugDetails/nodedescribe
mkdir debugDetails/nodedescribe
for node in $(kubectl get nodes -o name); do
  kubectl describe $node > debugDetails/nodedescribe/$(echo $node | cut -d/ -f 2).txt
done

# For all pods in the namespace, store logs for each container of pods in debugDetails/podlogs
mkdir debugDetails/podlogs
for pod in $(kubectl get pods -n $namespace -o name); do
  mkdir debugDetails/podlogs/$(echo $pod | cut -d/ -f 2)
  for container in $(kubectl get $pod -n $namespace -o jsonpath='{.spec.containers[*].name}'); do
    kubectl logs -n $namespace $pod $container > debugDetails/podlogs/$(echo $pod | cut -d/ -f 2)/$container.txt
  done
done

# For all pods in the namespace, check if pod has previously crashed container,
# if yes, then store logs of previously crashed container in debugDetails/failedcontainer

PODS=$(kubectl get pods -n $NAMESPACE -o=jsonpath='{.items[*].metadata.name}')

# Loop through each pod
for pod in $PODS; do
    # Get the logs for the previous crash container (if any)
    CRASHED_CONTAINER=$(kubectl logs $pod --previous -c $(kubectl get po $pod -n $NAMESPACE -o=jsonpath='{.status.containerStatuses[?(@.state.terminated.reason=="CrashLoopBackOff")].name}' --allow-missing) -n $NAMESPACE --allow-missing)

    # If there is output from the previous command, then the container crashed
    if [ -n "$CRASHED_CONTAINER" ]; then
        # Create a directory for the failed container logs
        mkdir debugDetails/failed_container

        # Save the logs to a file
        echo "$CRASHED_CONTAINER" > debugDetails/failed_container/$pod.log
    fi
done
