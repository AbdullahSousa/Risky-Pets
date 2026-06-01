# main.py
import os
import tempfile
from fastapi import FastAPI, UploadFile, File, Form, HTTPException
from typing import Optional
from schemas import AgentResponse
from inference import consult_risky_pet_agent

app = FastAPI(title="RiskyPet AI Agent API")

@app.post("/api/consult-agent/", response_model=AgentResponse)
async def consult_agent(
    file: Optional[UploadFile] = File(None),
    interaction_type: Optional[str] = Form(None),
    broke_skin: Optional[str] = Form(None),
    deep_puncture: Optional[str] = Form(None),
    lesion_oozing: Optional[str] = Form(None),
    rabies_signs: Optional[str] = Form(None),
    note: Optional[str] = Form(None),
):
    if not file:
        raise HTTPException(status_code=400, detail="An image is required.")

    if "GOOGLE_API_KEY" not in os.environ:
        raise HTTPException(status_code=500, detail="Gemini API Key is missing.")

    # Build a structured message from the form fields
    parts = []
    if interaction_type:
        parts.append(f"Interaction type: {interaction_type.upper()}")
    if broke_skin == "true":
        parts.append("Wound: broke the skin / drew blood")
    if deep_puncture == "true":
        parts.append("Wound: deep puncture wound")
    if lesion_oozing == "true":
        parts.append("Wound: lesion is oozing / infected")
    if rabies_signs == "true":
        parts.append("Behavioral signs: aggression or drooling (possible rabies signs)")
    if note:
        parts.append(f"User note: {note}")

    user_message = "\n".join(parts) if parts else None

    temp_path = None
    if file:
        with tempfile.NamedTemporaryFile(delete=False, suffix=".jpg") as temp_file:
            content = await file.read()
            temp_file.write(content)
            temp_path = temp_file.name

    try:
        result_json_string = consult_risky_pet_agent(image_path=temp_path, user_message=user_message)
        return AgentResponse.model_validate_json(result_json_string)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if temp_path and os.path.exists(temp_path):
            os.remove(temp_path)