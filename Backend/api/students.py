from fastapi import APIRouter, HTTPException, Depends, UploadFile, File, status, Response
from fastapi.responses import StreamingResponse
from pydantic import BaseModel, Field, ValidationError
from typing import List, Optional
import base64
import csv
import io
import traceback
import zipfile # 👈 เพิ่ม import นี้
from PIL import Image
from datetime import datetime

# Import Model ที่ถูกต้องจากไฟล์ student_model.py
from model.student import Student, StudentCreateUpdate, PhotoData
from model.user import UserPublic
from api.auth import get_current_user, log_user_activity
from firebase_admin import db

router = APIRouter(
    prefix="/schools/{school_name}/students",
    tags=["Students"]
)

# --- Model สำหรับรับ Filter ตอน Export ---
class StudentExportFilters(BaseModel):
    search: Optional[str] = None
    gradeLevel: Optional[str] = None
    className: Optional[str] = None
    photoStatus: Optional[str] = None

# --- 1. Endpoint สำหรับดึงข้อมูลนักเรียน (หน้า List) ---
@router.get("/", response_model=List[Student])
def get_students(
    school_name: str,
    search: Optional[str] = None,
    gradeLevel: Optional[str] = None,
    className: Optional[str] = None,
    photoStatus: Optional[str] = None,
    current_user: UserPublic = Depends(get_current_user)
):
    try:
        ref = db.reference(f'schools/{school_name}/students')
        students_data = ref.get()
        if not students_data:
            return []

        student_list = []
        for key, value in students_data.items():
            try:
                if 'studentId' not in value: value['studentId'] = key
                if 'schoolName' not in value: value['schoolName'] = school_name
                if 'photoData' not in value or not isinstance(value['photoData'], dict):
                    value['photoData'] = {"photoStatus": "no_photo"}
                
                value["photoData"].pop("photoBase64", None)
                student_list.append(Student.parse_obj(value))
            except (ValidationError, AttributeError) as e:
                print(f"--- WARNING: Skipping invalid student data for key '{key}': {e} ---")
                continue

        # --- Filter Logic ---
        if search:
            search_lower = search.lower()
            student_list = [s for s in student_list if search_lower in s.firstName.lower() or search_lower in s.lastName.lower() or s.id.lower()]
        if gradeLevel and gradeLevel != 'ทั้งหมด':
            student_list = [s for s in student_list if s.gradeLevel == gradeLevel]
        if className and className != 'ทั้งหมด':
            student_list = [s for s in student_list if s.className == className]
        if photoStatus and photoStatus != 'ทั้งหมด':
            mapping = {'มีรูป (สมบูรณ์)': 'finish', 'กำลังประมวลผล': 'processed', 'ไม่มีรูป': 'no_photo'}
            mapped_status = mapping.get(photoStatus)
            if mapped_status:
                student_list = [s for s in student_list if s.photoData.photoStatus == mapped_status]
        
        return student_list
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# --- 2. Endpoint สำหรับดึงข้อมูลนักเรียนคนเดียว (หน้า Detail) ---
@router.get("/{student_id}", response_model=Student)
def get_student_by_id(
    school_name: str,
    student_id: str,
    current_user: UserPublic = Depends(get_current_user)
):
    try:
        student_ref = db.reference(f'schools/{school_name}/students/{student_id}')
        student_data = student_ref.get()
        if not student_data:
            raise HTTPException(status_code=404, detail="Student not found")
        
        if 'studentId' not in student_data: student_data['studentId'] = student_id
        return Student.parse_obj(student_data)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# --- 3. Endpoint สำหรับ "สร้าง" นักเรียน ---
@router.post("/", response_model=Student, status_code=status.HTTP_201_CREATED)
def create_student(
    school_name: str,
    student_in: StudentCreateUpdate,
    current_user: UserPublic = Depends(get_current_user)
):
    student_id = student_in.id
    student_ref = db.reference(f'schools/{school_name}/students/{student_id}')
    if student_ref.get():
        raise HTTPException(status_code=400, detail=f"Student with ID '{student_id}' already exists.")
    
    student_data = student_in.dict(by_alias=True)
    student_data["photoData"] = {
        "photoStatus": "no_photo",
        "photoBase64": None,
        "photoThumbnailBase64": None
    }
    
    student_ref.set(student_data)
    log_user_activity(current_user, "create_student", {"school": school_name, "student_id": student_id})
    return Student.parse_obj(student_data)

# --- 4. Endpoint สำหรับ "แก้ไข" นักเรียน ---
@router.put("/{student_id}", response_model=Student)
def update_student(
    school_name: str,
    student_id: str,
    student_in: StudentCreateUpdate,
    current_user: UserPublic = Depends(get_current_user)
):
    student_ref = db.reference(f'schools/{school_name}/students/{student_id}')
    if not student_ref.get():
        raise HTTPException(status_code=404, detail="Student not found")
    
    update_data = student_in.dict(exclude_unset=True, by_alias=True)
    student_ref.update(update_data)
    log_user_activity(current_user, "update_student", {"school": school_name, "student_id": student_id})
    
    updated_data = student_ref.get()
    return Student.parse_obj(updated_data)

# --- 5. Endpoint สำหรับ "ลบ" นักเรียน ---
@router.delete("/{student_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_student(
    school_name: str,
    student_id: str,
    current_user: UserPublic = Depends(get_current_user)
):
    student_ref = db.reference(f'schools/{school_name}/students/{student_id}')
    if not student_ref.get():
        raise HTTPException(status_code=404, detail="Student not found")
    
    student_ref.delete()
    log_user_activity(current_user, "delete_student", {"school": school_name, "student_id": student_id})
    return Response(status_code=status.HTTP_204_NO_CONTENT)

# --- 6. Endpoint สำหรับอัปโหลดรูปภาพ ---
@router.post("/{student_id}/photo", response_model=Student)
def upload_student_photo(
    school_name: str,
    student_id: str,
    file: UploadFile = File(...),
    current_user: UserPublic = Depends(get_current_user)
):
    student_ref = db.reference(f'schools/{school_name}/students/{student_id}')
    if not student_ref.get():
        raise HTTPException(status_code=404, detail=f"Student with ID '{student_id}' not found.")

    try:
        image_bytes = file.file.read()
        raw_base64 = base64.b64encode(image_bytes).decode('utf-8')

        photo_data_to_update = {
            "photoBase64": raw_base64,
            "photoThumbnailBase64": None,
            "photoStatus": "processed",
            "uploadedAt": int(datetime.now().timestamp() * 1000)
        }
        
        student_ref.child("photoData").update(photo_data_to_update)
        
        updated_student_data = student_ref.get()
        return Student.parse_obj(updated_student_data)
    except Exception as e:
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"An internal server error occurred during image upload: {str(e)}")

# --- 7. Endpoint สำหรับอัปโหลดไฟล์ CSV ---
@router.post("/upload-csv", summary="Upload students from a CSV file")
def upload_students_from_csv(
    school_name: str,
    file: UploadFile = File(...),
    current_user: UserPublic = Depends(get_current_user)
):
    if not file.filename.endswith('.csv'):
        raise HTTPException(status_code=400, detail="Please upload a CSV file.")
    try:
        ref = db.reference(f'schools/{school_name}/students')
        content = file.file.read().decode('utf-8-sig')
        csv_reader = csv.DictReader(io.StringIO(content))

        count = 0
        for row in csv_reader:
            student_id = row.get("id") or row.get("studentId")
            if not student_id:
                continue

            student_data = {
                "studentId": student_id,
                "firstName": row.get("firstName", ""),
                "lastName": row.get("lastName", ""),
                "gradeLevel": row.get("gradeLevel", ""),
                "className": row.get("className", ""),
                "schoolName": school_name,
                "photoData": {
                    "photoStatus": "no_photo",
                    "photoBase64": None,
                    "photoThumbnailBase64": None,
                }
            }
            
            ref.child(student_id).set(student_data)
            count += 1

        log_user_activity(current_user, "upload_csv", {"school": school_name, "count": count})
        return {"message": f"Successfully added/updated {count} students."}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to process CSV file: {str(e)}")

# ✅ --- 8. Endpoint ใหม่สำหรับ Export ---
@router.post("/export-zip")
def export_students_zip(
    school_name: str,
    filters: StudentExportFilters,
    current_user: UserPublic = Depends(get_current_user)
):
    try:
        ref = db.reference(f'schools/{school_name}/students')
        students_data = ref.get()
        if not students_data:
            raise HTTPException(status_code=404, detail="No students found for this school.")

        student_list = []
        for key, value in students_data.items():
            try:
                if 'studentId' not in value: value['studentId'] = key
                if 'schoolName' not in value: value['schoolName'] = school_name
                if 'photoData' not in value: value['photoData'] = {"photoStatus": "no_photo"}
                student_list.append(Student.parse_obj(value))
            except (ValidationError, AttributeError):
                continue
        
        if filters.search:
            search_lower = filters.search.lower()
            student_list = [s for s in student_list if search_lower in s.firstName.lower() or search_lower in s.lastName.lower() or s.id.lower()]
        if filters.gradeLevel and filters.gradeLevel != 'ทั้งหมด':
            student_list = [s for s in student_list if s.gradeLevel == filters.gradeLevel]
        if filters.className and filters.className != 'ทั้งหมด':
            student_list = [s for s in student_list if s.className == filters.className]
        if filters.photoStatus and filters.photoStatus != 'ทั้งหมด':
            mapping = {'มีรูป (สมบูรณ์)': 'finish', 'กำลังประมวลผล': 'processed', 'ไม่มีรูป': 'no_photo', 'ผิดพลาด': 'error'}
            mapped_status = mapping.get(filters.photoStatus)
            if mapped_status:
                student_list = [s for s in student_list if s.photoData.photoStatus == mapped_status]

        students_to_export = [
            s for s in student_list 
            if s.photoData.photoStatus == 'finish' and s.photoData.photoBase64
        ]

        if not students_to_export:
            raise HTTPException(status_code=404, detail="ไม่พบนักเรียนที่มีรูปภาพสมบูรณ์ตามเงื่อนไขที่เลือก")

        zip_buffer = io.BytesIO()
        with zipfile.ZipFile(zip_buffer, 'w', zipfile.ZIP_DEFLATED) as zip_file:
            for student in students_to_export:
                try:
                    image_bytes = base64.b64decode(student.photoData.photoBase64)
                    file_name = f"{student.id}_{student.firstName}_{student.lastName}.jpg"
                    zip_file.writestr(file_name, image_bytes)
                except Exception as e:
                    print(f"Could not process image for student {student.id}: {e}")
                    continue
        
        zip_buffer.seek(0)
        log_user_activity(current_user, "export_zip", {"school": school_name, "count": len(students_to_export)})

        return StreamingResponse(
            zip_buffer,
            media_type="application/zip",
            headers={"Content-Disposition": f"attachment; filename=export_{school_name}.zip"}
        )

    except HTTPException as e:
        raise e
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"An error occurred during export: {str(e)}")
