# inference.py
import os
from PIL import Image
from typing import Optional
from google import genai
from google.genai import types
from schemas import AgentResponse

_client: Optional[genai.Client] = None
def _get_client() -> genai.Client:
    global _client
    if _client is None:
        _client = genai.Client()
    return _client

def consult_risky_pet_agent(
    image_path: Optional[str] = None,
    user_message: Optional[str] = None,
) -> str:
    contents = []
    if image_path:
        try:
            img = Image.open(image_path)
            contents.append(img)
        except Exception as e:
            raise ValueError(f"Could not open image file: {e}")
    if user_message:
        contents.append(f"User Inputs:\n{user_message}")
    else:
        contents.append("Perform a full health and safety risk assessment on this animal image.")
    system_instruction = """
You are RiskyPet, an expert AI veterinary assistant and zoonotic disease specialist.

The user will provide:
- A photo of an animal
- Interaction type: BITE, SCRATCH, or TOUCH
- Wound characteristics (broke skin, deep puncture, lesion oozing)
- Behavioral signs (aggression, drooling, itching)
- An optional personal note

Your job:
1. Identify the animal species from the image.
2. Assess the overall risk level (LOW, MODERATE, HIGH, or CRITICAL) based on the image AND the user's inputs combined.
3. Detect any visible health issues or zoonotic disease signs (rabies, ringworm, mange, etc.).
4. Give a clear, direct assessment in the `answer` field (2-3 sentences max).
5. Give step-by-step first-aid and follow-up advice in the `advice` field (numbered list).

Rules:
- Be specific — mention the actual animal, actual wounds, actual behaviors.
- If the animal shows rabies signs (aggression + drooling), always escalate to HIGH or CRITICAL.
- If skin was broken, always recommend medical consultation.
- Keep advice practical and ordered (1. do this, 2. do that...).
- Never refuse to assess. Always give a best-effort answer.
- Keep responses concise — the app displays them on a mobile screen.
"""

    response = _get_client().models.generate_content(
        model='gemini-2.5-flash',
        contents=contents,
        config=types.GenerateContentConfig(
            system_instruction=system_instruction,
            temperature=0.2,
            response_mime_type="application/json",
            response_schema=AgentResponse,
        ),
    )

    if not response.text:
        raise ValueError("Gemini returned an empty response. Please try again.")

    return response.text