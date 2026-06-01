# schemas.py
from pydantic import BaseModel, Field
from typing import List

class HealthFlag(BaseModel):
    issue: str = Field(description="Specific visual anomaly, e.g. 'cloudy eyes', 'dermal lesions'")
    severity: str = Field(description="Low, Medium, or High")

class AgentResponse(BaseModel):
    animal_type: str = Field(description="Identified animal species, e.g. Dog, Cat, Unknown")
    risk_level: str = Field(description="Overall risk: LOW, MODERATE, HIGH, or CRITICAL")
    bite_risk_level: str = Field(description="Bite-specific risk based on posture/behavior: Low, Medium, High")
    health_flags: List[HealthFlag] = Field(description="List of health issues detected from the image")
    answer: str = Field(description="Direct assessment summarizing what was found")
    advice: str = Field(description="Step-by-step veterinary safety guidance the user should follow")