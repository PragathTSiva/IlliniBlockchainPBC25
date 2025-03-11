# Initial Public Offering System

## Demo Media
- **Video:** [Watch Video](https://youtu.be/mdMGrJD8Dw0)
- **Presentation:** [View Presentation](https://he-s3.s3.amazonaws.com/media/sprint/pbc-hackathon-25/team/2231935/cd5c069launchpresentation.pptx)

To build ABIs for a smart contract: `sforge build`

To bring up the validator: `sanvil`

To deploy contracts and mint USDC for sample purposes, run: `bun packages/cli/src/cli.ts setup`

To create the new IPO Cross, run: `bun packages/cli/src/cli.ts create`

To get the current clearing price, run: `bun packages/cli/src/cli.ts get-price <IPO Cross address>`

To submit orders, run: `bun packages/cli/src/cli.ts submit-orders <IPO Cross address>`

To finalize the auction, run: `bun packages/cli/src/cli.ts finalize <IPO Cross address>`

---

# Aptos Developer Chatbot

## Demo Media
- **Video:** [Watch Video](https://youtu.be/Ga4qzSELHWk)
- **Presentation:** [View Presentation](https://he-s3.s3.amazonaws.com/media/sprint/pbc-hackathon-25/team/2231935/fc2cafbpitch_deck.pdf)

The Aptos Developer Chatbot is a multi-agent system designed to deliver precise, context-aware answers to Aptos developer queries. Leveraging retrieval-augmented generation (RAG) techniques, it extracts verified information directly from official Aptos resources—ensuring that answers are both accurate and relevant.

---

## Overview

This solution consists of two key components:

- **Backend:** A Python/Flask server powered by the crewAI framework. It orchestrates a multi-agent workflow where specialized research agents query various Aptos-related data sources in parallel. Their results are combined into a single, cohesive markdown-formatted response. The backend also manages API endpoints and conversation state, allowing for both single-turn and multi-turn interactions.

- **Frontend:** A modern, TypeScript-based chatbot UI built with Next.js. The interface provides features such as suggested questions, conversation history, and an easily embeddable design for integration into existing Aptos documentation platforms like aptos.dev.

---

## Multi-Agent Workflow & Architecture

The heart of the system is its multi-agent architecture, which operates as follows:

1. **API Interaction & Context Management:**  
   - RESTful endpoints (e.g., `/ask`, `/conversation`) handle incoming queries and maintain conversation history.
   - Session context is preserved across interactions to provide coherent multi-turn dialogues.

2. **Parallel Research with Specialized Agents:**  
   - The backend instantiates several research agents (each configured via YAML) to search distinct Aptos resources, such as core repositories, developer docs, and tutorials.
   - Using asyncio, these agents run concurrently, each performing its assigned research task to gather targeted information.
   - The concurrent operation ensures minimal latency and broad coverage of different information sources.
  
       **Sources:**
      - *'https://github.com/aptos-labs/aptos-core'*
      - *'https://github.com/0xaptosj/aptos-full-stack-template'*
      - *'https://github.com/aptos-labs/developer-docs'*
      - *'https://learn.aptoslabs.com/'*
      - *'https://aptos.dev/'*
        
3. **Results Aggregation & Synthesis:**  
   - A dedicated synthesis process (reporting workflow) aggregates outputs from all agents.
   - This process uses retrieval-augmented generation (RAG) techniques to combine and clean the data into a final, concise answer formatted in markdown.
   - The final response integrates essential insights from each agent, ensuring the answer is comprehensive and developer-friendly.

---

## Frontend Integration

- **Chatbot UI Features:**  
  Built with Next.js and TypeScript, the UI offers an intuitive chat interface, featuring:
  - **Suggested Questions:** Predefined queries (e.g., “How to deploy a Move module?”) to prompt user interaction.
  - **Conversation History:** Display of previous interactions to maintain context.
  - **Embed-Ready Design:** Easily integrated into existing Aptos documentation platforms for a seamless developer experience.

- **Seamless Communication:**  
  The frontend communicates with the backend via REST API endpoints, ensuring prompt and interactive query responses.

---

## Setup and Installation

### Backend Setup

1. **Prerequisites:**
   - Python (>=3.10, <3.13)
   - Required Python packages installed via pip
   - Environment variables configured in a `.env` file (e.g., `OPENAI_API_KEY`, GitHub tokens)

2. **Installation:**
   ```bash
   pip install -r requirements.txt

3. **Run the Backend:**
   ```bash
   python backend/aptos/src/aptos/main.py
   ```
   The API will be available at [http://localhost:8007](http://localhost:8007).

### Frontend Setup

1. **Prerequisites:**
   - Node.js and npm (or yarn)

2. **Installation:**
   ```bash
   cd aptos-ui
   npm install
   ```

3. **Run the Frontend:**
   ```bash
   npm run dev
   ```
   Access the chatbot UI at [http://localhost:3000](http://localhost:3000).

---

## Conclusion

The Aptos Developer Chatbot represents a robust, multi-agent architecture that efficiently answers technical questions by aggregating data from trusted Aptos resources. Its parallel research workflow minimizes response time while ensuring accuracy, and its TypeScript-based UI offers a seamless, feature-rich user experience. This makes the chatbot an ideal tool for integrating into existing Aptos developer portals, enhancing support and productivity.

Happy coding, and enjoy your enhanced Aptos experience!
