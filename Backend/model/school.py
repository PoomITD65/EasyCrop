# Backend/models/school.py

from pydantic import BaseModel

class School(BaseModel):
    id: str
    name: str

class SchoolCreate(BaseModel):
    name: str