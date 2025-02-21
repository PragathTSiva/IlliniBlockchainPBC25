from crewai import Agent, Crew, Process, Task
from crewai.project import CrewBase, agent, crew, task
from dotenv import load_dotenv
from crewai_tools import CodeDocsSearchTool, GithubSearchTool
from flask import Flask, request, jsonify
import asyncio
from uuid import uuid4
from datetime import datetime
from typing import List, Optional, Dict
import os
import logging
from flask_pydantic import validate
from pydantic import BaseModel
from flask_cors import CORS

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Load environment variables
load_dotenv()

app = Flask(__name__)
CORS(app)  # Enable CORS for all routes and origins

aptos_core_tool = GithubSearchTool(
    github_repo='https://github.com/aptos-labs/aptos-core',
    gh_token='ghp_2564646464646464646464646464646464646464',
    content_types=['code', 'issue']
)

aptos_full_stack_template_tool = GithubSearchTool(
    github_repo='https://github.com/0xaptosj/aptos-full-stack-template',
    gh_token='ghp_2564646464646464646464646464646464646464',
    content_types=['code', 'issue']
)

aptos_developer_docs_tool = GithubSearchTool(
    github_repo='https://github.com/aptos-labs/developer-docs',
    gh_token='ghp_2564646464646464646464646464646464646464',
    content_types=['code', 'issue']
)

learn_aptoslabs_docs_tool = CodeDocsSearchTool(docs_url='https://learn.aptoslabs.com/')
aptos_dev_docs_tool = CodeDocsSearchTool(docs_url='https://aptos.dev/')

tools = [
    aptos_core_tool,
    aptos_full_stack_template_tool,
    aptos_developer_docs_tool,
    learn_aptoslabs_docs_tool,
    aptos_dev_docs_tool,
]

# Pydantic models
class Query(BaseModel):
    question: str

class Conversation(BaseModel):
    id: str
    history: List[Dict[str, str]]
    created_at: datetime
    updated_at: datetime

# Store conversation history
conversations: Dict[str, Dict] = {}

@CrewBase
class Aptos():
	"""Aptos crew"""

	agents_config = 'config/agents.yaml'
	tasks_config = 'config/tasks.yaml'

################################################################################################################################################################
##Agents
################################################################################################################################################################
	@agent
	def aptos_core_researcher(self) -> Agent:
		return Agent(
			config=self.agents_config['aptos_core_researcher'],
			verbose=True,
			tools=[aptos_core_tool]
		)

	@agent
	def aptos_full_stack_researcher(self) -> Agent:
		return Agent(
			config=self.agents_config['aptos_full_stack_researcher'],
			verbose=True,
			tools=[aptos_full_stack_template_tool]
		)

	@agent
	def aptos_developer_docs_researcher(self) -> Agent:
		return Agent(
			config=self.agents_config['aptos_developer_docs_researcher'],
			verbose=True,
			tools=[aptos_developer_docs_tool]
		)

	@agent
	def learn_aptoslabs_researcher(self) -> Agent:
		return Agent(
			config=self.agents_config['learn_aptoslabs_researcher'],
			verbose=True,
			tools=[learn_aptoslabs_docs_tool]
		)

	@agent
	def aptos_dev_docs_researcher(self) -> Agent:
		return Agent(
			config=self.agents_config['aptos_dev_docs_researcher'],
			verbose=True,
			tools=[aptos_dev_docs_tool]
		)

	@agent
	def reporting_analyst(self) -> Agent:
		return Agent(
			config=self.agents_config['reporting_analyst'],
			verbose=True
		)

################################################################################################################################################################
##Tasks
################################################################################################################################################################

	@task
	def aptos_core_research_task(self) -> Task:
		return Task(
			config=self.tasks_config['aptos_core_research_task'],
			agent=self.aptos_core_researcher(),
			async_execution=True
		)

	@task
	def aptos_full_stack_research_task(self) -> Task:
		return Task(
			config=self.tasks_config['aptos_full_stack_research_task'],
			agent=self.aptos_full_stack_researcher(),
			async_execution=True
		)

	@task
	def aptos_developer_docs_research_task(self) -> Task:
		return Task(
			config=self.tasks_config['aptos_developer_docs_research_task'],
			agent=self.aptos_developer_docs_researcher(),
			async_execution=True
		)

	@task
	def learn_aptoslabs_research_task(self) -> Task:
		return Task(
			config=self.tasks_config['learn_aptoslabs_docs_research_task'],
			agent=self.learn_aptoslabs_researcher(),
			async_execution=True
		)

	@task
	def aptos_dev_docs_research_task(self) -> Task:
		return Task(
			config=self.tasks_config['aptos_dev_docs_research_task'],
			agent=self.aptos_dev_docs_researcher(),
			async_execution=True
		)

	@task
	def reporting_task(self) -> Task:
		return Task(
			config=self.tasks_config['reporting_task'],
			agent=self.reporting_analyst(),
			output_file='report.md'
		)

################################################################################################################################################################
##Crew
################################################################################################################################################################

	@crew
	def aptos_core_crew(self) -> Crew:
		"""Creates the research crew for Aptos Core"""
		return Crew(
			agents=[self.aptos_core_researcher()],
			tasks=[self.aptos_core_research_task()],
			process=Process.sequential
		)

	@crew
	def aptos_full_stack_crew(self) -> Crew:
		"""Creates the research crew for Aptos Full Stack"""
		return Crew(
			agents=[self.aptos_full_stack_researcher()],
			tasks=[self.aptos_full_stack_research_task()],
			process=Process.sequential
		)

	@crew
	def aptos_developer_docs_crew(self) -> Crew:
		"""Creates the research crew for Aptos Developer Docs"""
		return Crew(
			agents=[self.aptos_developer_docs_researcher()],
			tasks=[self.aptos_developer_docs_research_task()],
			process=Process.sequential
		)

	@crew
	def learn_aptoslabs_crew(self) -> Crew:
		"""Creates the research crew for Learn Aptos Labs"""
		return Crew(
			agents=[self.learn_aptoslabs_researcher()],
			tasks=[self.learn_aptoslabs_research_task()],
			process=Process.sequential
		)

	@crew
	def aptos_dev_docs_crew(self) -> Crew:
		"""Creates the research crew for Aptos Dev Docs"""
		return Crew(
			agents=[self.aptos_dev_docs_researcher()],
			tasks=[self.aptos_dev_docs_research_task()],
			process=Process.sequential
		)

	@crew
	def research_crew(self) -> Crew:
		"""Creates the research crew for parallel execution"""
		return Crew(
			agents=[
				self.aptos_core_researcher(),
				self.aptos_full_stack_researcher(),
				self.aptos_developer_docs_researcher(),
				self.learn_aptoslabs_researcher(),
				self.aptos_dev_docs_researcher(),
			],
			tasks=[
				self.aptos_core_research_task(),
				self.aptos_full_stack_research_task(),
				self.aptos_developer_docs_research_task(),
				self.learn_aptoslabs_research_task(),
				self.aptos_dev_docs_research_task(),
			],
			process=Process.parallel
		)

	@crew
	def reporting_crew(self) -> Crew:
		"""Creates the reporting crew for final analysis"""
		return Crew(
			agents=[self.reporting_analyst()],
			tasks=[self.reporting_task()],
			process=Process.sequential
		)

	async def run_parallel_crews(self, inputs: dict) -> str:
		"""
		Run all research crews in parallel using asyncio
		"""
		# Create all the research crews
		aptos_core_crew = self.aptos_core_crew()
		full_stack_crew = self.aptos_full_stack_crew()
		developer_docs_crew = self.aptos_developer_docs_crew()
		learn_aptoslabs_crew = self.learn_aptoslabs_crew()
		aptos_dev_docs_crew = self.aptos_dev_docs_crew()

		# Kick off all crews asynchronously
		results = await asyncio.gather(
			aptos_core_crew.kickoff_async(inputs=inputs),
			full_stack_crew.kickoff_async(inputs=inputs),
			developer_docs_crew.kickoff_async(inputs=inputs),
			learn_aptoslabs_crew.kickoff_async(inputs=inputs),
			aptos_dev_docs_crew.kickoff_async(inputs=inputs)
		)

		# Flatten the results into a single string
		combined_results = "\n\n".join([
			f"Aptos Core Research:\n{results[0]}",
			f"Full Stack Research:\n{results[1]}",
			f"Developer Docs Research:\n{results[2]}",
			f"Learn Aptoslabs Research:\n{results[3]}",
			f"Aptos Dev Docs Research:\n{results[4]}"
		])

		return combined_results

	def run(self, topic: str) -> str:
		"""
		Run all research crews in parallel, then feed the aggregated research results into
		the final reporting crew to produce a cohesive answer.
		"""
		inputs = {
			'topic': topic
		}
		
		# Run all research crews in parallel
		parallel_results = asyncio.run(self.run_parallel_crews(inputs))
		
		# Create a proper dictionary for the reporting crew inputs
		reporting_inputs = {
			'topic': inputs['topic'],  # Pass through the original topic
			'research_results': parallel_results  # Include the research results
		}
		
		# Pass the properly structured inputs to the reporting crew
		reporting_crew = self.reporting_crew()
		final_results = reporting_crew.kickoff(inputs=reporting_inputs)
		
		return final_results

def create_crew(query):
    # Your crew creation logic here
    aptos_instance = Aptos()
    return aptos_instance

def get_suggested_questions(context: Optional[str] = None) -> List[str]:
    """Get suggested questions based on context"""
    base_questions = [
        "How do I deploy a Move module?",
        "What are Move resources?",
        "How do I test Move contracts?",
        "How do I integrate Aptos wallet?",
        "What are the best practices for Move development?",
        "How do I handle errors in Move?",
        "What are the gas fee considerations in Aptos?",
        "How do I upgrade my Move modules?"
    ]
    
    # In a production environment, you would use the context
    # to provide more relevant suggested questions
    return base_questions

@app.route("/conversation", methods=["POST"])
@validate()
async def start_conversation(query: Query):
    """Start a new conversation"""
    conv_id = str(uuid4())
    conversations[conv_id] = {
        "id": conv_id,
        "history": [],
        "created_at": datetime.now().isoformat(),
        "updated_at": datetime.now().isoformat()
    }
    
    # Process the query
    try:
        crew = create_crew(query.question)
        result = await asyncio.to_thread(crew.run, query.question)
        
        # Update conversation history
        conversations[conv_id]["history"].append({
            "question": query.question,
            "answer": result,
            "timestamp": datetime.now().isoformat()
        })
        conversations[conv_id]["updated_at"] = datetime.now().isoformat()
        
        return jsonify({
            "conversation_id": conv_id,
            "answer": result,
            "suggested_questions": get_suggested_questions(query.question)
        })
    except Exception as e:
        logger.error(f"Error processing query: {e}")
        return jsonify({"error": str(e)}), 500

@app.route("/conversation/<conv_id>", methods=["POST"])
@validate()
async def continue_conversation(conv_id: str, query: Query):
    """Continue an existing conversation"""
    if conv_id not in conversations:
        return jsonify({"error": "Conversation not found"}), 404
    
    try:
        # Get conversation history context
        history = conversations[conv_id]["history"]
        
        # Create crew with context
        crew = create_crew(f"{query.question}\nContext: {history}")
        result = await asyncio.to_thread(crew.run, query.question)
        
        # Update conversation history
        conversations[conv_id]["history"].append({
            "question": query.question,
            "answer": result,
            "timestamp": datetime.now().isoformat()
        })
        conversations[conv_id]["updated_at"] = datetime.now().isoformat()
        
        return jsonify({
            "answer": result,
            "suggested_questions": get_suggested_questions(query.question)
        })
    except Exception as e:
        logger.error(f"Error continuing conversation: {e}")
        return jsonify({"error": str(e)}), 500

@app.route("/conversation/<conv_id>/history", methods=["GET"])
async def get_conversation_history(conv_id: str):
    """Get the history of a conversation"""
    if conv_id not in conversations:
        return jsonify({"error": "Conversation not found"}), 404
    return jsonify(conversations[conv_id])

@app.route("/ask", methods=["POST"])
@validate()
def ask_question(body: Query):
    """Handle single questions without conversation context"""
    try:
        crew = create_crew(body.question)
        result = asyncio.run(asyncio.to_thread(crew.run, body.question))
        return jsonify({
            "answer": str(result),  # Convert CrewOutput to string
            "suggested_questions": get_suggested_questions(body.question)
        })
    except Exception as e:
        logger.error(f"Error processing query: {e}")
        return jsonify({"error": str(e)}), 500

@app.route("/suggested-questions", methods=["GET"])
def suggested_questions():
    """Get suggested questions based on context"""
    context = request.args.get("context")
    return jsonify(get_suggested_questions(context))

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8007, debug=True)
