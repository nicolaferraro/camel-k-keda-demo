# Camel K KEDA Demo

This demo shows how to use Camel K together with KEDA to enable autoscaling (and scaling to 0) of integrations
starting from specific sources. The demo will focus on autoscaling from AWS SQS and Red Hat Streams for Apache Kafka.

## Prerequisites

The following requirements are needed:

- An OpenShift or Kubernetes cluster (also Minikube)
- Camel K 1.8+ (to be released as of Jan 13) installed globally in the cluster (e.g. in the "camel" namespace) and configured
- KEDA 2.5+ installed globally in the cluster (e.g. in the "keda" namespace)
- `kubectl` or `oc` client
- A tool for watching Kubernetes logs, e.g. `stern`
- The `kafkacat` tool to send messages to Kafka

## Setup

Create a namespace named `test` and switch to it.

This demo uses special Kamelets that have been marked with KEDA annotations. To ensure that you're using the right Kamelets, you can apply them from here:

```
kubectl apply -f kamelets/
```

## 1. Autoscaling from AWS SQS

We'll bind an AWS SQS queue to log endpoint, so we can just see that messages are printed to the console. You can replace the sink with whatever you want in real scenarios.

To make the demo work, you need to:

- Create an AWS SQS queue in a region of your choice and an user with a role that can access it on AWS
- Edit the `sqs-to-log.yaml` file to put all the correct references to the queue

When this is done, you can open a terminal and execute the following command:

```
stern -
```

This will print all logs of any pod that is going to be created in the namespace.

On **another terminal** create the binding:

```
kubectl apply -f sqs-to-log.yaml
```

Wait for the binding to be created. You can check the state by running the command:

```
kubectl get klb
```

The binding is established when the phase turns into "Ready".

Assuming no messages are being sent to the SQS queue at the moment, you'll se the number of **replicas going to 0** soon. Also, if you look at the pods:

```
kubectl get pods
```

You won't find any binding pods. Let's put a watch on the last command:

```
watch kubectl get pods
```

Now you can **go to the SQS console and send a test message "Hello KEDA!"**.

Quickly the terminal watching the pods will show a pod being created to process the message, while the one running `stern` will display (among the Camel logs) the message content. The binding will **scale down again to 0** after that.

## 2. Autoscaling from Red Hat managed Kafka

You can go to https://cloud.redhat.com to create a free Kafka instance for this demo.
After you created an instance, create a topic named e.g. `messages` **with 3 partitions (!)**, a service account and grant permissions to the service account to do `all` operations on the topic and any consumer group associated to it.

After doing so you need to:
- Edit the `kafka-to-log.yaml` file to put references and credentials for the instance
- Edit the `send-data.sh` file to add the same data for the message sender

NOTE: ensure you have a terminal that prints all logs from the pods of the current namespace, as expained in the previous example (i.e. run `stern -` on a different terminal)

You can create the binding from Kafka to a log printer using the following command:

```
kubectl apply -f kafka-to-log.yaml
```

The binding contains an **artificial delay** to make sure the processing is longer, in order to see the **scaling out effect**.

Wait for the binding to be created. You can check the state by running the command:

```
kubectl get klb
```

The binding is established when the phase turns into "Ready".

Assuming no messages are being sent to the Kafka instance at the moment, you'll se the number of **replicas going to 0** soon. Also, if you look at the pods:

```
kubectl get pods
```

You won't find any binding pods. Let's put a watch on the last command:

```
watch kubectl get pods
```

You need to open **a third terminal** and go to the current directory where there's a `send-data.sh` file.
This script allows sending data to the Kafka topic to see the autoscaler in action.

Now you can send a few messages:

```
./send-data.sh 5
```

This will send 5 messages to the Kafka topic. You'll find the following behavior:

- 1 pod is created to handle the messages
- The `stern` terminal will show a different message every 3 seconds (IDs are out of order since they are sent in parallel)
- The pod is destroyed after the 5th message is processed

Now if you send much more data:

```
./send-data.sh 500
```

This time the KEDA autoscaler will detect that a single pod can't handle the load and will instantiate **3 pods** to handle it. No more than 3 pods will be created by keda since it **corresponds to the number of partitions** in the Kafka topic.

After some time, the consumers will rebalance the partitions among them and all 3 pods will start consuming messages (you'll notice 3 messages from different pods printed every 3 seconds in the `stern` terminal).
