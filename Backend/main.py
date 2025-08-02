import os
import sys
from fastapi import FastAPI, Request, Response, status
from fastapi.middleware.cors import CORSMiddleware
import firebase_admin
from firebase_admin import credentials
from dotenv import load_dotenv

# โหลดตัวแปรสภาพแวดล้อมจากไฟล์ .env (ถ้ามี)
load_dotenv()

# ✅ --- ส่วนที่เพิ่มเข้ามาเพื่อแก้ปัญหา ImportError ---
# เพิ่ม path ของโปรเจกต์หลักเข้าไปในระบบ เพื่อให้ Python หาโฟลเดอร์ model และ api เจอ
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
# --- จบส่วนที่เพิ่ม ---

# 1. Import Routers
from api import auth
from api.schools import router as schools_router
from api.students import router as students_router

# 2. ส่วนเชื่อมต่อ Firebase
SERVICE_ACCOUNT_KEY_PATH = "key/idphoto-e5a75-firebase-adminsdk-fbsvc-fd771fc15f.json"
FIREBASE_DATABASE_URL = "https://idphoto-e5a75-default-rtdb.asia-southeast1.firebasedatabase.app/"

cred_path = os.path.join(os.path.dirname(__file__), SERVICE_ACCOUNT_KEY_PATH)
cred = credentials.Certificate(cred_path)

# เพิ่ม storageBucket สำหรับการอัปโหลดไฟล์
firebase_admin.initialize_app(cred, {
    'databaseURL': FIREBASE_DATABASE_URL,
    'storageBucket': 'idphoto-e5a75.appspot.com' # ตรวจสอบให้แน่ใจว่าเป็นชื่อ bucket ของคุณ
})

print("Firebase App Initialized successfully!")

# 3. สร้างแอป FastAPI
app = FastAPI(
    title="EasyCrop API",
    description="API for managing student information.",
    version="1.0.0"
)

# 4. เพิ่ม CORS Middleware (ฉบับแก้ไขถาวร)
app.add_middleware(
    CORSMiddleware,
    # ใช้ Regular Expression เพื่ออนุญาตทุก Port จาก localhost
    allow_origin_regex=r"http://(localhost|127\.0\.0\.1)(:\d+)?",
    allow_credentials=True,
    allow_origins=["*"],
    allow_methods=["*"], # อนุญาตทุก HTTP method
    allow_headers=["*"], # อนุญาตทุก Header
)

# Global OPTIONS handler เพื่อให้แน่ใจว่า preflight request ได้รับ 200 OK
@app.options("/{path:path}", include_in_schema=False)
async def options_handler(request: Request, path: str):
    return Response(status_code=status.HTTP_200_OK)


# 5. นำ router ที่ import เข้ามาอย่างถูกต้องมาใช้งาน
app.include_router(schools_router, prefix="/api", tags=["Schools"])
app.include_router(students_router, prefix="/api", tags=["Students"])
app.include_router(auth.router, prefix="/api", tags=["Authentication"])

@app.get("/")
def read_root():
    return {"message": "Welcome to EasyCrop API"}