from pydantic import BaseModel, Field, ConfigDict
from typing import Optional

class PhotoData(BaseModel):
    """
    โมเดลสำหรับ Object 'photoData' ที่ซ้อนอยู่ข้างใน
    """
    photoStatus: str = 'no_photo'
    photoBase64: Optional[str] = None
    photoThumbnailBase64: Optional[str] = None
    finishedAt: Optional[int] = None
    uploadedAt: Optional[int] = None

class Student(BaseModel):
    """
    โมเดลหลักสำหรับข้อมูลนักเรียน ที่มีโครงสร้างตรงกับ Firebase
    """
    # ใช้ alias เพื่อบอกว่า Field 'id' ในโค้ดของเรา
    # คือ Field 'studentId' ในข้อมูลที่มาจาก Firebase
    id: str = Field(..., alias='studentId') 
    
    firstName: str
    lastName: str
    className: str
    gradeLevel: str
    schoolName: str
    
    # photoData จะถูกแปลงเป็นโมเดล PhotoData ที่เราสร้างไว้ข้างบน
    # และมีค่าเริ่มต้นเป็น PhotoData ว่างๆ กรณีที่ไม่มีข้อมูลนี้ใน Firebase
    photoData: PhotoData = Field(default_factory=PhotoData)
    
    # ✅ Pydantic v2 update: 'allow_population_by_field_name' is now a model_config setting
    model_config = ConfigDict(
        populate_by_name=True, # รับทั้ง 'id' และ 'studentId' เวลาอ่านข้อมูลเข้า
        json_encoders={
            # You can add custom encoders here if needed
        }
    )

# Model สำหรับรับข้อมูลตอนสร้าง/แก้ไข (ยังคงรับข้อมูลพื้นฐาน)
class StudentCreateUpdate(BaseModel):
    id: str = Field(..., description="รหัสนักเรียน", alias='studentId')
    firstName: str
    lastName: str
    gradeLevel: str
    className: str
    schoolName: str

    model_config = ConfigDict(
        populate_by_name=True
    )
