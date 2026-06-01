import requests

# Your new live Cloud Run URL + the endpoint path
url = "https://zoonotic-risk-api-380222214445.europe-west3.run.app/api/consult-agent/"

# The data to send (matching your FastAPI Form/File setup)
data = {
    "user_message": "This dog is showing its teeth and its ears are pinned back. What should I do?"
}

# Optional: Add an image if you have one in the same folder
# files = {"file": open("angry_dog.jpg", "rb")} 
# response = requests.post(url, data=data, files=files)

# Testing just text for now:
response = requests.post(url, data=data)

if response.status_code == 200:
    print("Success! Here is the Agent's response:\n")
    print(response.json())
else:
    print(f"Error {response.status_code}: {response.text}")