# System Preparation and Rasa-Kafka Integration

## 1. System Preparation

### 1.1 Install Required Packages

On Ubuntu or WSL:

#### Python 3.7+ (usually pre-installed). If needed:
```bash
sudo apt update
sudo apt install python3 python3-pip
```

#### (Optional) Create a virtual environment:
```bash
python3 -m venv venv
source venv/bin/activate
```

#### Install Rasa:
```bash
pip install --upgrade pip
pip install rasa
```

#### Install Docker

- Docker Engine Install Docs  
- After installation, add your user to the docker group and restart your shell:
```bash
sudo usermod -aG docker $USER
```

#### Install Docker Compose (v2)
It usually comes bundled with Docker Desktop or the Docker engine on Ubuntu. Verify with:
```bash
docker compose version
```
If you see a version output, you’re set.

## 2. Create a Minimal Rasa Project

#### Create a project folder:
```bash
mkdir rasa-kafka-poc
cd rasa-kafka-poc
```

#### Initialize Rasa:
```bash
rasa init --no-prompt
```

This creates a basic structure:

```
rasa-kafka-poc/
  ├── actions/
  ├── data/
  │   ├── nlu.yml
      ├── rules.yml
  │   └── stories.yml
  ├── domain.yml
  ├── config.yml
  ├── endpoints.yml
  └── credentials.yml
```

#### Train the default model:
```bash
rasa train
```

## 3. Docker Compose for Kafka (Plaintext)

#### Create `docker-compose.yml` in the same folder:
```yaml
services:
  zookeeper:
    image: confluentinc/cp-zookeeper:latest
    environment:
      ZOOKEEPER_CLIENT_PORT: 2181
      ZOOKEEPER_TICK_TIME: 2000
    ports:
      - "2181:2181"

  kafka:
    image: confluentinc/cp-kafka:latest
    depends_on:
      - zookeeper
    ports:
      - "9092:9092"
    environment:
      KAFKA_BROKER_ID: 1
      KAFKA_ZOOKEEPER_CONNECT: "zookeeper:2181"
      KAFKA_LISTENERS: PLAINTEXT://0.0.0.0:9092
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://localhost:9092
      KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 1
```

#### Spin up Kafka & Zookeeper:
```bash
docker compose up -d
```

#### Check logs (optional):
```bash
docker compose logs -f kafka
```

Confirm Kafka started successfully without errors.

## 4. Modify Rasa Files for a Custom Math Action & Kafka Events (optional)

### 4.1 `actions.py` (Example Math Solver)

#### Create or modify `actions.py` inside the `actions/` folder with the following code:
```python
from typing import Any, Text, Dict, List
from rasa_sdk import Action, Tracker
from rasa_sdk.executor import CollectingDispatcher
import sympy as sp
import re

class ActionSolveMath(Action):
    def name(self) -> Text:
        return "action_solve_math"

    def run(self, dispatcher: CollectingDispatcher, tracker: Tracker, domain: Dict[Text, Any]) -> List[Dict[Text, Any]]:
        user_message = tracker.latest_message['text'].lower()
        
        if "square root of" in user_message:
            match = re.search(r"square root of (\d+)", user_message)
            if match:
                number = int(match.group(1))
                result = sp.sqrt(number)
                dispatcher.utter_message(text=f"The square root of {number} is {result}")
                return []
        
        expression = re.findall(r"[\d\+\-\*\/\(\)\^\.]+", user_message)
        if expression:
            expr_str = "".join(expression)
            try:
                sym_expr = sp.sympify(expr_str)
                result = sym_expr.evalf()
                dispatcher.utter_message(text=f"The answer is: {result}")
            except Exception:
                dispatcher.utter_message(text="I couldn't calculate that. Try a simpler expression.")
        else:
            dispatcher.utter_message(text="I didn't understand the math expression.")
        
        return []
```

#### Install Sympy if needed:
```bash
pip install sympy
```

### 4.2 `domain.yml`

#### Register your custom action in `domain.yml`:
```yaml
actions:
  - action_solve_math
```

### 4.3 `endpoints.yml`

#### Action Endpoint so Rasa can call the action server:
```yaml
action_endpoint:
  url: "http://localhost:5055/webhook"
```

#### Kafka Event Broker so Rasa publishes conversation events to `rasa_events` topic:
```yaml
event_broker:
  type: kafka
  url: "localhost:9092"
  topic: "rasa_events"
  security_protocol: "PLAINTEXT"
```

### 4.4 `nlu.yml`

#### Add an intent for math:
```yaml
nlu:
- intent: ask_math
  examples: |
    - What is 2+2?
    - Solve 15*3
    - What's 10-7?
    - Calculate 8/2
    - square root of 16
    - 2 ^ 3
    - 2^3
    - 10 / 5
    - 2+2
```

### 4.5 `rules.yml` (or `stories.yml`)

#### Add a rule to trigger the custom action:
```yaml
rules:
- rule: Handle math questions
  steps:
    - intent: ask_math
    - action: action_solve_math
```

## 5. Running & Testing the POC

### 5.1 Run the Bot & Action Server

#### Train your updated model:
```bash
rasa train
```

#### Start Action Server (in one terminal):
```bash
rasa run actions
```

#### Start Rasa (in another terminal):
```bash
rasa shell
```

### 5.2 Verify Kafka Events

#### In a separate window, consume from the `rasa_events` topic:
```bash
docker compose exec kafka bash
kafka-console-consumer --bootstrap-server localhost:9092 --topic rasa_events --from-beginning
```

### 5.3 Interact with the Bot

#### Open a new terminal, run:
```bash
rasa shell
```

Test with:
```
Your input -> Hello
Your input -> 2+2
Your input -> square root of 16
```

## 6. Optional: Custom Ingestion from Kafka

To pull user messages from Kafka instead of Rasa shell or HTTP, you can create a custom input channel (e.g., `kafka_input.py`).

## 7. Summary & Next Steps

- WSL/Ubuntu environment → Docker + Rasa + Kafka are running.
- Rasa publishes conversation events to Kafka topic `rasa_events`.
- Action Server processes custom math with Sympy.
- User can chat via Rasa shell or integrated channels.

Next Steps:
- Logging events from Kafka into a database (Elasticsearch, PostgreSQL).
- Analytics: building dashboards based on conversation data.
- Production deployment with CI/CD, advanced security, load balancing.
