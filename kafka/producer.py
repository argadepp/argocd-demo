from kafka import KafkaProducer
import json

# Kafka configuration
KAFKA_BROKER = "kafka.localhost"
KAFKA_TOPIC = "demo-topic"

# Create a Kafka producer
producer = KafkaProducer(
    bootstrap_servers=KAFKA_BROKER,
    value_serializer=lambda v: json.dumps(v).encode("utf-8"),
)

def produce_message():
    message = {"key": "value", "message": "Hello Kafka!"}
    producer.send(KAFKA_TOPIC, message)
    producer.flush()
    print(f"Produced message: {message}")

if __name__ == "__main__":
    produce_message()
