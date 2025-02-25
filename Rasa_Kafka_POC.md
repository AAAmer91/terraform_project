<details> <summary>Click to expand the Markdown content</summary>

# Rasa + Kafka POC

## 1. System Preparation

### 1.1 Install Required Packages

On **Ubuntu** or **WSL**:

```bash
sudo apt update
sudo apt install python3 python3-pip

(Optional) Create a virtual environment:

python3 -m venv venv
source venv/bin/activate

Install Rasa:

pip install --upgrade pip
pip install rasa

Install Docker

Follow Docker Engine Install Docs for your system.

After installation, add your user to the docker group and restart your shell:

sudo usermod -aG docker $USER

Install Docker Compose (v2)

It usually comes bundled with Docker Desktop or the Docker engine on Ubuntu. Verify:

docker compose version

If you see a version output, you’re set.
2. Create a Minimal Rasa Project

Create a project folder:

mkdir rasa-kafka-poc
cd rasa-kafka-poc

Initialize Rasa (accepts defaults):

rasa init --no-prompt

This creates a basic structure:

rasa-kafka-poc/
  ├── actions/
  ├── data/
  │   ├── nlu.yml
  │   └── stories.yml
  ├── domain.yml
  ├── config.yml
  ├── endpoints.yml
  └── credentials.yml

Train the default model:

rasa train

3. Docker Compose for Kafka (Plaintext)

Create a docker-compose.yml in the same folder (rasa-kafka-poc):

version: '3.8'
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
      # No SASL (PLAINTEXT)
      KAFKA_LISTENERS: PLAINTEXT://0.0.0.0:9092
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://localhost:9092
      KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 1

Spin up Kafka & Zookeeper:

docker compose up -d

Check logs (optional) to confirm Kafka started successfully:

docker compose logs -f kafka

4. Modify Rasa Files for a Custom Math Action & Kafka Events
4.1 actions.py (Example Math Solver)

In your project folder, open or create actions.py (inside actions/ if you prefer). Below is an example custom action that handles basic arithmetic plus a square root demonstration, using sympy:

from typing import Any, Text, Dict, List
from rasa_sdk import Action, Tracker
from rasa_sdk.executor import CollectingDispatcher
import sympy as sp
import re

class ActionSolveMath(Action):

    def name(self) -> Text:
        return "action_solve_math"

    def run(
        self,
        dispatcher: CollectingDispatcher,
        tracker: Tracker,
        domain: Dict[Text, Any]
    ) -> List[Dict[Text, Any]]:
        
        user_message = tracker.latest_message['text'].lower()
        
        # Quick check if user typed something like "square root of 16"
        if "square root of" in user_message:
            match = re.search(r"square root of (\d+)", user_message)
            if match:
                number = int(match.group(1))
                result = sp.sqrt(number)
                dispatcher.utter_message(text=f"The square root of {number} is {result}")
                return []
        
        # For other expressions (2+2, 3*5, etc.)
        # Extract digits and operators
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

    Important: Install Sympy if needed:

pip install sympy

4.2 domain.yml

Register your custom action in domain.yml:

actions:
  - action_solve_math

4.3 endpoints.yml

Define the Action Endpoint so Rasa can call the action server:

action_endpoint:
  url: "http://localhost:5055/webhook"

Then configure the Kafka Event Broker so Rasa publishes conversation events to rasa_events topic:

event_broker:
  type: kafka
  url: "localhost:9092"
  topic: "rasa_events"
  security_protocol: "PLAINTEXT"

4.4 nlu.yml

Add an intent for math:

nlu:
- intent: greet
  examples: |
    - Hi
    - Hello
- intent: goodbye
  examples: |
    - Bye
    - See you later
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

4.5 rules.yml (or stories.yml)

Add a rule to trigger the custom action:

rules:
- rule: Handle math questions
  steps:
    - intent: ask_math
    - action: action_solve_math

5. Running & Testing the POC
5.1 Run the Bot & Action Server

Train your updated model:

rasa train

Start the Action Server (in one terminal):

rasa run actions

Start Rasa (in another terminal):

rasa run --enable-api --debug

    If port 5005 is busy, choose another port:

    rasa run --port 5006 --debug

5.2 Verify Kafka Events

In a separate window, consume from the rasa_events topic:

docker compose exec kafka bash
kafka-console-consumer --bootstrap-server localhost:9092 --topic rasa_events --from-beginning

    You can omit --from-beginning to see only new messages.

5.3 Interact with the Bot

Open a new terminal and run:

rasa shell

Test:

Your input -> Hello
...

Your input -> 2+2
...

Your input -> square root of 16
...

Watch the console consumer (Kafka) for published events like:

{"event":"user","timestamp":...,"text":"2+2",...}
{"event":"bot","timestamp":...,"text":"The answer is: 4.0",...}

Confirm the logs on the Action Server or Rasa for any errors.
6. Optional: Custom Ingestion from Kafka

If you want to pull user messages from Kafka (instead of using Rasa shell or HTTP), you can create a custom input channel (e.g., kafka_input.py). However, for most POCs, it’s enough to see the event broker in action (Rasa → Kafka).
7. Summary & Next Steps

    Environment: WSL/Ubuntu environment → Docker + Rasa + Kafka are running.
    Event Publishing: Rasa publishes conversation events to Kafka topic rasa_events.
    Action Server: Processes custom math with Sympy.
    User Interaction: Chat via rasa shell or integrated channels (Telegram, Slack, etc.).
    Kafka Verification: Check Kafka logs to confirm real-time events are streaming.

Next Steps might include:

    Logging events from Kafka into a database (Elasticsearch, PostgreSQL).
    Analytics: building dashboards based on conversation data.
    Production deployment with CI/CD, advanced security, load balancing.

</details>