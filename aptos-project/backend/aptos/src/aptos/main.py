import json
import sys
import os
import warnings
import asyncio
from flask import Flask, request, jsonify

if __name__ == "__main__" and __package__ is None:
    sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
    __package__ = "aptos"

from .crew import Aptos

app = Flask(__name__)

@app.route('/api/research', methods=['POST'])
def research():
    """
    API endpoint to run Aptos research
    Expects JSON body: {"topic": "your question here"}
    """
    try:
        data = request.get_json()
        if not data or 'topic' not in data:
            return jsonify({'error': 'Missing topic in request body'}), 400

        topic = data['topic']
        aptos_instance = Aptos()
        result = aptos_instance.run(topic)
        
        return jsonify({
            'status': 'success',
            'result': result
        })

    except Exception as e:
        return jsonify({
            'status': 'error',
            'error': str(e)
        }), 500

@app.route('/health', methods=['GET'])
def health_check():
    """
    Simple health check endpoint
    """
    return jsonify({'status': 'healthy'}), 200

async def run_parallel_crews(aptos_instance, inputs):
    """
    Run all research crews in parallel using asyncio
    """
    # Create all the research crews
    aptos_core_crew = aptos_instance.aptos_core_crew()
    full_stack_crew = aptos_instance.aptos_full_stack_crew()
    developer_docs_crew = aptos_instance.aptos_developer_docs_crew()
    learn_aptoslabs_crew = aptos_instance.learn_aptoslabs_crew()
    aptos_dev_docs_crew = aptos_instance.aptos_dev_docs_crew()

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

def run():
    """
    Run all research crews in parallel, then feed the aggregated research results into
    the final reporting crew to produce a cohesive answer.
    """
    inputs = {
        'topic': 'How do I deploy to Aptos?'
    }
    aptos_instance = Aptos()
    
    # Run all research crews in parallel
    parallel_results = asyncio.run(run_parallel_crews(aptos_instance, inputs))
    
    # Create a proper dictionary for the reporting crew inputs
    reporting_inputs = {
        'topic': inputs['topic'],  # Pass through the original topic
        'research_results': parallel_results  # Include the research results
    }
    
    # Pass the properly structured inputs to the reporting crew
    reporting_crew = aptos_instance.reporting_crew()
    final_results = reporting_crew.kickoff(inputs=reporting_inputs)
    
    print(final_results)

def train():
    """
    Train the crew for a given number of iterations.
    """
    inputs = {
        "topic": "AI LLMs"
    }
    try:
        aptos_instance = Aptos()
        aptos_instance.research_crew().train(n_iterations=int(sys.argv[1]), filename=sys.argv[2], inputs=inputs)
    except Exception as e:
        raise Exception(f"An error occurred while training the crew: {e}")

def replay():
    """
    Replay the crew execution from a specific task.
    """
    try:
        aptos_instance = Aptos()
        aptos_instance.research_crew().replay(task_id=sys.argv[1])
    except Exception as e:
        raise Exception(f"An error occurred while replaying the crew: {e}")

def test():
    """
    Test the crew execution and return the results.
    """
    inputs = {
        "topic": "AI LLMs"
    }
    try:
        aptos_instance = Aptos()
        aptos_instance.research_crew().test(n_iterations=int(sys.argv[1]), openai_model_name=sys.argv[2], inputs=inputs)
    except Exception as e:
        raise Exception(f"An error occurred while testing the crew: {e}")

if __name__ == "__main__":
    app.run(host='0.0.0.0', port=5000, debug=True)