import aiohttp
import asyncio
import json

async def test_ask_endpoint():
    try:
        async with aiohttp.ClientSession() as session:
            async with session.post(
                'http://localhost:8007/ask',
                json={'question': 'How do I deploy to Aptos?'}
            ) as response:
                result = await response.json()
                print(json.dumps(result, indent=2))
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    asyncio.run(test_ask_endpoint())