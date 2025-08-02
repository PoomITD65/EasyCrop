from fastapi import APIRouter, HTTPException, Depends, Response, status
from typing import List
from model.school import School, SchoolCreate
from model.student import Student 
from model.user import UserPublic
from api.auth import get_current_user, log_user_activity
from firebase_admin import db

router = APIRouter()

@router.get("/schools", response_model=List[School])
def get_schools(current_user: UserPublic = Depends(get_current_user)):
    log_user_activity(current_user, action="view_all_schools")
    try:
        ref = db.reference('schools')
        schools_data = ref.get()
        if not schools_data:
            return []
        return [School(id=key, name=key) for key in schools_data.keys()]
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/schools", response_model=School, status_code=201)
def create_school(school_in: SchoolCreate, current_user: UserPublic = Depends(get_current_user)):
    try:
        school_name = school_in.name
        ref = db.reference(f'schools/{school_name}')
        if ref.get():
            raise HTTPException(status_code=400, detail="School with this name already exists.")

        ref.set({
            "createdAt": {".sv": "timestamp"},
            "createdBy": current_user.username 
        })
        
        log_user_activity(current_user, action="create_school", details={"school_name": school_name})
        
        return School(id=school_name, name=school_name)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# ✅ --- เพิ่ม Endpoint นี้เข้าไป ---
@router.delete("/schools/{school_name}", status_code=status.HTTP_204_NO_CONTENT)
def delete_school(
    school_name: str,
    current_user: UserPublic = Depends(get_current_user)
):
    """ลบโรงเรียนและข้อมูลทั้งหมดที่อยู่ภายใต้โรงเรียนนั้น"""
    school_ref = db.reference(f'schools/{school_name}')
    if not school_ref.get():
        raise HTTPException(status_code=404, detail="School not found")
    
    school_ref.delete()
    log_user_activity(current_user, "delete_school", {"school_name": school_name})
    return Response(status_code=status.HTTP_204_NO_CONTENT)
# --- จบส่วนที่เพิ่ม ---

@router.get("/schools/{school_name}/students", response_model=List[Student])
def get_students_in_school(school_name: str, current_user: UserPublic = Depends(get_current_user)):
    log_user_activity(current_user, action="view_students_list", details={"school_name": school_name})
    try:
        ref = db.reference(f'schools/{school_name}/students')
        students_data = ref.get()
        if not students_data:
            return []
        
        return [Student(**value) for key, value in students_data.items()]
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/schools/{school_name}/students/{student_id}", response_model=Student)
def get_student_details(school_name: str, student_id: str, current_user: UserPublic = Depends(get_current_user)):
    """
    ดึงข้อมูลรายละเอียดของนักเรียนคนเดียว พร้อมบันทึก Log
    """
    log_user_activity(
        current_user, 
        action="view_student_detail", 
        details={
            "school_name": school_name,
            "student_id_viewed": student_id
        }
    )
    
    try:
        ref = db.reference(f'schools/{school_name}/students')
        
        query = ref.order_by_child('id').equal_to(student_id).get()
        
        if not query:
            raise HTTPException(status_code=404, detail="Student not found")
            
        student_key = list(query.keys())[0]
        student_data = query[student_key]
        
        return Student(**student_data)
        
    except HTTPException as e:
        raise e
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))